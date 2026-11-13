import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';
import '../core/database/app_database.dart';
import '../features/parsing/parsing_engine.dart';
import '../features/sms/domain/sms_gateway.dart';
import 'models.dart';

/// All data access. Every query is scoped by workspace id.
class Repo {
  Repo(this._db, this._onChange);
  final AppDatabase _db;
  final void Function() _onChange;
  Database get _d => _db.db;

  int _now() => DateTime.now().millisecondsSinceEpoch;
  void notify() => _onChange();

  // ---------- settings ----------
  String? setting(String key) {
    final r = _d.select('SELECT value FROM settings WHERE key=?', [key]);
    return r.isEmpty ? null : r.first['value'] as String;
  }

  void setSetting(String key, String value) {
    _d.execute(
        'INSERT INTO settings(key,value) VALUES(?,?) '
        'ON CONFLICT(key) DO UPDATE SET value=excluded.value',
        [key, value]);
    notify();
  }

  // ---------- workspaces ----------
  List<Workspace> workspaces() => _d
      .select('SELECT id,name,type FROM workspaces ORDER BY id')
      .map((r) =>
          Workspace(r['id'] as int, r['name'] as String, r['type'] as String))
      .toList();

  int createWorkspace(String name, String type) {
    _d.execute('INSERT INTO workspaces(name,type,created_at) VALUES(?,?,?)',
        [name, type, _now()]);
    final id = _d.lastInsertRowId;
    _d.execute(
        'INSERT INTO templates(workspace_id,name,credit_keywords,debit_keywords,'
        'amount_regex,balance_regex,reference_regex,counterparty_regex) '
        'VALUES(?,?,?,?,?,?,?,?)',
        [
          id,
          'Generic bank (sample - edit for your bank)',
          'credited,received,deposited,credit',
          'debited,withdrawn,paid,purchase,transferred,debit',
          r'(?:ETB|Birr|USD)\s*([\d,]+(?:\.\d+)?)',
          r'balance[^\d]{0,25}([\d,]+(?:\.\d+)?)',
          r'\b(?:ref(?:erence)?|txn|trx|id)\b[^A-Za-z0-9]{0,5}([A-Za-z0-9]{6,})',
          null,
        ]);
    notify();
    return id;
  }

  // ---------- accounts ----------
  static const _accSql = '''
    SELECT a.*, a.opening_minor + COALESCE((SELECT SUM(CASE t.direction
      WHEN 'credit' THEN t.amount_minor ELSE -t.amount_minor END)
      FROM transactions t WHERE t.account_id=a.id AND t.deleted=0),0) AS balance
    FROM accounts a''';

  Account _account(Row r) => Account(
        id: r['id'] as int,
        workspaceId: r['workspace_id'] as int,
        bank: r['bank'] as String,
        name: r['name'] as String,
        numberMask: r['number_mask'] as String?,
        currency: r['currency'] as String,
        type: r['type'] as String,
        openingMinor: r['opening_minor'] as int,
        active: (r['active'] as int) == 1,
        balanceMinor: r['balance'] as int,
      );

  List<Account> accounts(int ws) => _d
      .select('$_accSql WHERE a.workspace_id=? ORDER BY a.id', [ws])
      .map(_account)
      .toList();

  Account? account(int id) {
    final r = _d.select('$_accSql WHERE a.id=?', [id]);
    return r.isEmpty ? null : _account(r.first);
  }

  int addAccount(int ws,
      {required String bank,
      required String name,
      String? mask,
      required String currency,
      required String type,
      required int openingMinor}) {
    _d.execute(
        'INSERT INTO accounts(workspace_id,bank,name,number_mask,currency,type,opening_minor) '
        'VALUES(?,?,?,?,?,?,?)',
        [ws, bank, name, mask, currency, type, openingMinor]);
    final id = _d.lastInsertRowId;
    notify();
    return id;
  }

  void setAccountActive(int id, bool active) {
    _d.execute('UPDATE accounts SET active=? WHERE id=?', [active ? 1 : 0, id]);
    notify();
  }

  // ---------- templates ----------
  SmsTemplate _tpl(Row r) => SmsTemplate(
        id: r['id'] as int,
        name: r['name'] as String,
        creditKeywords: r['credit_keywords'] as String,
        debitKeywords: r['debit_keywords'] as String,
        amountRegex: r['amount_regex'] as String,
        balanceRegex: r['balance_regex'] as String?,
        referenceRegex: r['reference_regex'] as String?,
        counterpartyRegex: r['counterparty_regex'] as String?,
      );

  List<SmsTemplate> templates(int ws) => _d
      .select('SELECT * FROM templates WHERE workspace_id=? ORDER BY id', [ws])
      .map(_tpl)
      .toList();

  SmsTemplate? template(int id) {
    final r = _d.select('SELECT * FROM templates WHERE id=?', [id]);
    return r.isEmpty ? null : _tpl(r.first);
  }

  int saveTemplate(int ws, SmsTemplate t) {
    final args = [
      t.name,
      t.creditKeywords,
      t.debitKeywords,
      t.amountRegex,
      t.balanceRegex,
      t.referenceRegex,
      t.counterpartyRegex,
    ];
    int id;
    if (t.id == null) {
      _d.execute(
          'INSERT INTO templates(name,credit_keywords,debit_keywords,amount_regex,'
          'balance_regex,reference_regex,counterparty_regex,workspace_id) '
          'VALUES(?,?,?,?,?,?,?,?)',
          [...args, ws]);
      id = _d.lastInsertRowId;
    } else {
      _d.execute(
          'UPDATE templates SET name=?,credit_keywords=?,debit_keywords=?,amount_regex=?,'
          'balance_regex=?,reference_regex=?,counterparty_regex=? WHERE id=? AND workspace_id=?',
          [...args, t.id, ws]);
      id = t.id!;
    }
    notify();
    return id;
  }

  void deleteTemplate(int id) {
    _d.execute(
        'UPDATE sms_sources SET template_id=NULL WHERE template_id=?', [id]);
    _d.execute('DELETE FROM templates WHERE id=?', [id]);
    notify();
  }

  // ---------- sender sources ----------
  Source _src(Row r) => Source(
        id: r['id'] as int,
        sender: r['sender'] as String,
        accountId: r['account_id'] as int,
        templateId: r['template_id'] as int?,
        active: (r['active'] as int) == 1,
      );

  List<Source> sources(int ws) => _d
      .select(
          'SELECT * FROM sms_sources WHERE workspace_id=? ORDER BY id', [ws])
      .map(_src)
      .toList();

  Source? sourceForSender(int ws, String sender) {
    final r = _d.select(
        'SELECT * FROM sms_sources WHERE workspace_id=? AND lower(sender)=lower(?)',
        [ws, sender]);
    return r.isEmpty ? null : _src(r.first);
  }

  void addSource(int ws, String sender, int accountId, int? templateId) {
    final acc = account(accountId);
    if (acc == null || acc.workspaceId != ws) {
      throw StateError('Account does not belong to this workspace');
    }
    _d.execute(
        'INSERT INTO sms_sources(workspace_id,sender,account_id,template_id) VALUES(?,?,?,?)',
        [ws, sender.trim(), accountId, templateId]);
    notify();
  }

  void setSourceActive(int id, bool active) {
    _d.execute(
        'UPDATE sms_sources SET active=? WHERE id=?', [active ? 1 : 0, id]);
    notify();
  }

  void deleteSource(int id) {
    _d.execute('DELETE FROM sms_sources WHERE id=?', [id]);
    notify();
  }

  // ---------- SMS ----------
  SmsMsg _sms(Row r) => SmsMsg(
        id: r['id'] as int,
        sender: r['sender'] as String,
        body: r['body'] as String,
        receivedAt:
            DateTime.fromMillisecondsSinceEpoch(r['received_at'] as int),
        status: r['status'] as String,
        note: r['note'] as String?,
      );

  List<SmsMsg> smsMessages(int ws) => _d
      .select(
          'SELECT * FROM sms_messages WHERE workspace_id=? ORDER BY received_at DESC LIMIT 500',
          [ws])
      .map(_sms)
      .toList();

  SmsMsg smsById(int id) =>
      _sms(_d.select('SELECT * FROM sms_messages WHERE id=?', [id]).first);

  bool _insertSms(
      int ws, String sender, String body, DateTime at, String? providerId) {
    final hash = sha256
        .convert(utf8.encode('$sender|${at.millisecondsSinceEpoch}|$body'))
        .toString();
    _d.execute(
        'INSERT OR IGNORE INTO sms_messages(workspace_id,sender,body,received_at,provider_id,'
        'body_hash,status,fetched_at) VALUES(?,?,?,?,?,?,?,?)',
        [
          ws,
          sender,
          body,
          at.millisecondsSinceEpoch,
          providerId,
          hash,
          'pending',
          _now()
        ]);
    return _d.updatedRows > 0;
  }

  /// Stores original SMS text. Returns the number of NEW messages.
  int insertSmsBatch(int ws, List<RawSms> msgs) {
    var added = 0;
    _d.execute('BEGIN');
    try {
      for (final m in msgs) {
        if (_insertSms(ws, m.sender, m.body, m.receivedAt, m.providerId))
          added++;
      }
      _d.execute('COMMIT');
    } catch (_) {
      _d.execute('ROLLBACK');
      rethrow;
    }
    notify();
    return added;
  }

  bool insertPastedSms(int ws, String sender, String body) {
    final ok = _insertSms(ws, sender, body, DateTime.now(), null);
    notify();
    return ok;
  }

  void _setSms(int id, String status, String? note) => _d.execute(
      'UPDATE sms_messages SET status=?, note=? WHERE id=?',
      [status, note, id]);

  void ignoreSms(int id) {
    _setSms(id, 'ignored', null);
    notify();
  }

  void deleteSms(int id) {
    _d.execute('DELETE FROM sms_messages WHERE id=?', [id]);
    notify();
  }

  void deleteAllSms(int ws) {
    _d.execute('DELETE FROM sms_messages WHERE workspace_id=?', [ws]);
    notify();
  }

  ParseResult parseMessage(int ws, SmsMsg m) {
    final src = sourceForSender(ws, m.sender);
    if (src == null || !src.active) {
      return ParseResult(
          errors: ['No active sender configured for ${m.sender}']);
    }
    if (src.templateId == null) {
      return const ParseResult(errors: ['No template assigned to this sender']);
    }
    final t = template(src.templateId!);
    if (t == null) return const ParseResult(errors: ['Template not found']);
    return ParsingEngine.parse(m.body, t);
  }

  /// Puts failed messages back in the queue (e.g. after fixing a template).
  void requeueFailed(int ws) {
    _d.execute(
        "UPDATE sms_messages SET status='pending', note=NULL "
        "WHERE workspace_id=? AND status='failed'",
        [ws]);
    notify();
  }

  ProcessSummary processPending(int ws) {
    final mode = setting('mode') ?? 'hybrid';
    final s = ProcessSummary();
    final rows = _d.select(
        "SELECT * FROM sms_messages WHERE workspace_id=? AND status='pending' ORDER BY received_at",
        [ws]);
    for (final r in rows) {
      final m = _sms(r);
      final res = parseMessage(ws, m);
      _d.execute('UPDATE sms_messages SET parsed_json=? WHERE id=?',
          [jsonEncode(res.toJson()), m.id]);
      if (!res.isValid) {
        _setSms(m.id, 'failed', res.errors.join('; '));
        s.failed++;
        continue;
      }
      final auto =
          mode == 'automatic' || (mode == 'hybrid' && res.isHighConfidence);
      if (auto) {
        final st = _approve(ws, m.id,
            direction: res.direction!,
            amountMinor: res.amountMinor!,
            reference: res.reference,
            counterparty: res.counterparty,
            balanceMinor: res.balanceMinor);
        if (st == 'duplicate') {
          s.duplicate++;
        } else if (st == 'processed') {
          s.saved++;
        } else {
          s.failed++;
        }
      } else {
        _setSms(m.id, 'awaiting_review', null);
        s.review++;
      }
    }
    notify();
    return s;
  }

  String _approve(int ws, int smsId,
      {required String direction,
      required int amountMinor,
      String? reference,
      String? counterparty,
      int? balanceMinor}) {
    final m = smsById(smsId);
    final src = sourceForSender(ws, m.sender);
    if (src == null) {
      _setSms(smsId, 'failed', 'No sender configuration');
      return 'failed';
    }
    try {
      _insertTx(
        ws: ws,
        accountId: src.accountId,
        direction: direction,
        amountMinor: amountMinor,
        occurredAt: m.receivedAt,
        reference: reference,
        counterparty: counterparty,
        description: 'SMS from ${m.sender}',
        source: 'sms',
        smsId: smsId,
        balanceMinor: balanceMinor,
      );
      _setSms(smsId, 'processed', null);
      return 'processed';
    } on DuplicateException catch (e) {
      _setSms(smsId, 'duplicate', e.message);
      return 'duplicate';
    }
  }

  /// Used by the review screen. Returns the resulting SMS status.
  String approveSms(int ws, int smsId,
      {required String direction,
      required int amountMinor,
      String? reference,
      String? counterparty}) {
    final st = _approve(ws, smsId,
        direction: direction,
        amountMinor: amountMinor,
        reference: reference,
        counterparty: counterparty);
    notify();
    return st;
  }

  // ---------- transactions ----------
  Tx _tx(Row r) => Tx(
        id: r['id'] as int,
        accountId: r['account_id'] as int,
        direction: r['direction'] as String,
        amountMinor: r['amount_minor'] as int,
        currency: r['currency'] as String,
        occurredAt:
            DateTime.fromMillisecondsSinceEpoch(r['occurred_at'] as int),
        reference: r['reference'] as String?,
        counterparty: r['counterparty'] as String?,
        category: r['category'] as String?,
        description: r['description'] as String?,
        source: r['source'] as String,
      );

  List<Tx> transactions(int ws, {int limit = 500}) => _d
      .select(
          'SELECT * FROM transactions WHERE workspace_id=? AND deleted=0 '
          'ORDER BY occurred_at DESC, id DESC LIMIT ?',
          [ws, limit])
      .map(_tx)
      .toList();

  String? _clean(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();

  String _txJson(int id) {
    final r = _d.select('SELECT * FROM transactions WHERE id=?', [id]);
    return jsonEncode(Map<String, Object?>.from(r.first));
  }

  void _audit(int txId, int ws, String action, String? before, String? after) {
    _d.execute(
        'INSERT INTO transaction_audits(transaction_id,workspace_id,action,before_json,after_json,at) '
        'VALUES(?,?,?,?,?,?)',
        [txId, ws, action, before, after, _now()]);
  }

  void _checkDuplicate(int accountId, String? reference, {int? exceptId}) {
    if (reference == null) return;
    final dup = _d.select(
        'SELECT id FROM transactions WHERE account_id=? AND reference=? AND deleted=0 AND id<>?',
        [accountId, reference, exceptId ?? -1]);
    if (dup.isNotEmpty) {
      throw DuplicateException(
          'A transaction with reference "$reference" already exists on this account');
    }
  }

  int _insertTx({
    required int ws,
    required int accountId,
    required String direction,
    required int amountMinor,
    required DateTime occurredAt,
    String? reference,
    String? counterparty,
    String? category,
    String? description,
    required String source,
    int? smsId,
    int? balanceMinor,
  }) {
    final acc = account(accountId);
    if (acc == null || acc.workspaceId != ws) {
      throw StateError('Account does not belong to this workspace');
    }
    final ref = _clean(reference);
    _checkDuplicate(accountId, ref);
    _d.execute(
        'INSERT INTO transactions(workspace_id,account_id,direction,amount_minor,currency,'
        'occurred_at,recorded_at,reference,counterparty,category,description,source,sms_id,balance_minor) '
        'VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [
          ws,
          accountId,
          direction,
          amountMinor,
          acc.currency,
          occurredAt.millisecondsSinceEpoch,
          _now(),
          ref,
          _clean(counterparty),
          _clean(category),
          _clean(description),
          source,
          smsId,
          balanceMinor,
        ]);
    final id = _d.lastInsertRowId;
    _audit(id, ws, 'create', null, _txJson(id));
    return id;
  }

  int addTransaction(int ws,
      {required int accountId,
      required String direction,
      required int amountMinor,
      required DateTime occurredAt,
      String? reference,
      String? counterparty,
      String? category,
      String? description}) {
    final id = _insertTx(
      ws: ws,
      accountId: accountId,
      direction: direction,
      amountMinor: amountMinor,
      occurredAt: occurredAt,
      reference: reference,
      counterparty: counterparty,
      category: category,
      description: description,
      source: 'manual',
    );
    notify();
    return id;
  }

  void updateTransaction(int ws, int id,
      {required int accountId,
      required String direction,
      required int amountMinor,
      required DateTime occurredAt,
      String? reference,
      String? counterparty,
      String? category,
      String? description}) {
    final acc = account(accountId);
    if (acc == null || acc.workspaceId != ws) {
      throw StateError('Account does not belong to this workspace');
    }
    final ref = _clean(reference);
    _checkDuplicate(accountId, ref, exceptId: id);
    final before = _txJson(id);
    _d.execute(
        'UPDATE transactions SET account_id=?,direction=?,amount_minor=?,currency=?,occurred_at=?,'
        'reference=?,counterparty=?,category=?,description=? WHERE id=? AND workspace_id=?',
        [
          accountId,
          direction,
          amountMinor,
          acc.currency,
          occurredAt.millisecondsSinceEpoch,
          ref,
          _clean(counterparty),
          _clean(category),
          _clean(description),
          id,
          ws,
        ]);
    _audit(id, ws, 'update', before, _txJson(id));
    notify();
  }

  void deleteTransaction(int ws, int id) {
    final before = _txJson(id);
    _d.execute(
        'UPDATE transactions SET deleted=1 WHERE id=? AND workspace_id=?',
        [id, ws]);
    _audit(id, ws, 'delete', before, null);
    notify();
  }

  ({int credit, int debit}) totals(int ws, DateTime from) {
    final r = _d.select(
        "SELECT COALESCE(SUM(CASE WHEN direction='credit' THEN amount_minor END),0) AS c, "
        "COALESCE(SUM(CASE WHEN direction='debit' THEN amount_minor END),0) AS d "
        'FROM transactions WHERE workspace_id=? AND deleted=0 AND occurred_at>=?',
        [ws, from.millisecondsSinceEpoch]).first;
    return (credit: r['c'] as int, debit: r['d'] as int);
  }
}
