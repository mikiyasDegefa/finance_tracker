import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'sample_template.dart';

/// Encrypted (SQLCipher) database. Refuses to open if SQLCipher is missing,
/// so financial data is never written unencrypted.
class AppDatabase {
  AppDatabase._(this.db);
  final Database db;

  static Future<AppDatabase> openEncrypted(String hexKey) async {
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
      open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
    }
    final dir = await getApplicationDocumentsDirectory();
    final db = sqlite3.open(p.join(dir.path, 'finance.db'));
    final cipher = db.select('PRAGMA cipher_version;');
    if (cipher.isEmpty) {
      db.dispose();
      throw StateError(
          'SQLCipher is not available; refusing to open an unencrypted database.');
    }
    db.execute("PRAGMA key = \"x'$hexKey'\";");
    db.select('SELECT count(*) FROM sqlite_master;'); // fails if key is wrong
    db.execute('PRAGMA foreign_keys = ON;');
    final out = AppDatabase._(db);
    out._migrate();
    return out;
  }

  void _migrate() {
    final v = db.select('PRAGMA user_version;').first['user_version'] as int;
    if (v < 1) {
      db.execute('BEGIN');
      try {
        for (final s in _schemaV1) {
          db.execute(s);
        }
        db.execute('PRAGMA user_version = 1;');
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    }
    if (v < 2) {
      db.execute('BEGIN');
      try {
        for (final s in _schemaV2) {
          db.execute(s);
        }
        db.execute(
            'UPDATE templates SET from_regex=?, to_regex=?, counterparty_account_regex=?, '
            'service_charge_regex=?, debit_keywords=? WHERE name LIKE ?',
            [
              SampleTemplate.from,
              SampleTemplate.to,
              SampleTemplate.counterpartyAccount,
              SampleTemplate.serviceCharge,
              SampleTemplate.debit,
              'Generic bank%',
            ]);
        db.execute('PRAGMA user_version = 2;');
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    }
    if (v < 3) {
      db.execute('BEGIN');
      try {
        for (final s in _schemaV3) {
          db.execute(s);
        }
        db.execute('PRAGMA user_version = 3;');
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    }
  }

  static const _schemaV3 = <String>[
    'ALTER TABLE sms_sources ADD COLUMN category TEXT',
  ];

  static const _schemaV2 = <String>[
    'ALTER TABLE transactions ADD COLUMN kind TEXT',
    'ALTER TABLE transactions ADD COLUMN from_party TEXT',
    'ALTER TABLE transactions ADD COLUMN to_party TEXT',
    'ALTER TABLE transactions ADD COLUMN counterparty_account TEXT',
    'ALTER TABLE transactions ADD COLUMN service_charge_minor INTEGER NOT NULL DEFAULT 0',
    'ALTER TABLE transactions ADD COLUMN receipt_url TEXT',
    'ALTER TABLE transactions ADD COLUMN remark TEXT',
    'ALTER TABLE templates ADD COLUMN from_regex TEXT',
    'ALTER TABLE templates ADD COLUMN to_regex TEXT',
    'ALTER TABLE templates ADD COLUMN counterparty_account_regex TEXT',
    'ALTER TABLE templates ADD COLUMN service_charge_regex TEXT',
    'ALTER TABLE templates ADD COLUMN receipt_regex TEXT',
  ];

  static const _schemaV1 = <String>[
    '''CREATE TABLE workspaces(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL, type TEXT NOT NULL, created_at INTEGER NOT NULL)''',
    '''CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)''',
    '''CREATE TABLE accounts(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      workspace_id INTEGER NOT NULL REFERENCES workspaces(id),
      bank TEXT NOT NULL, name TEXT NOT NULL, number_mask TEXT,
      currency TEXT NOT NULL, type TEXT NOT NULL,
      opening_minor INTEGER NOT NULL DEFAULT 0,
      active INTEGER NOT NULL DEFAULT 1)''',
    '''CREATE TABLE templates(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      workspace_id INTEGER NOT NULL REFERENCES workspaces(id),
      name TEXT NOT NULL,
      credit_keywords TEXT NOT NULL, debit_keywords TEXT NOT NULL,
      amount_regex TEXT NOT NULL, balance_regex TEXT,
      reference_regex TEXT, counterparty_regex TEXT)''',
    '''CREATE TABLE sms_sources(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      workspace_id INTEGER NOT NULL REFERENCES workspaces(id),
      sender TEXT NOT NULL,
      account_id INTEGER NOT NULL REFERENCES accounts(id),
      template_id INTEGER, active INTEGER NOT NULL DEFAULT 1,
      UNIQUE(workspace_id, sender))''',
    '''CREATE TABLE sms_messages(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      workspace_id INTEGER NOT NULL REFERENCES workspaces(id),
      sender TEXT NOT NULL, body TEXT NOT NULL,
      received_at INTEGER NOT NULL, provider_id TEXT,
      body_hash TEXT NOT NULL, status TEXT NOT NULL,
      parsed_json TEXT, note TEXT, fetched_at INTEGER NOT NULL,
      UNIQUE(workspace_id, body_hash))''',
    '''CREATE TABLE transactions(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      workspace_id INTEGER NOT NULL REFERENCES workspaces(id),
      account_id INTEGER NOT NULL REFERENCES accounts(id),
      direction TEXT NOT NULL, amount_minor INTEGER NOT NULL,
      currency TEXT NOT NULL, occurred_at INTEGER NOT NULL,
      recorded_at INTEGER NOT NULL, reference TEXT, counterparty TEXT,
      category TEXT, description TEXT, source TEXT NOT NULL,
      sms_id INTEGER, balance_minor INTEGER,
      deleted INTEGER NOT NULL DEFAULT 0)''',
    '''CREATE UNIQUE INDEX ux_tx_ref ON transactions(account_id, reference)
      WHERE reference IS NOT NULL AND deleted = 0''',
    '''CREATE INDEX ix_tx_ws_date ON transactions(workspace_id, occurred_at)''',
    '''CREATE INDEX ix_sms_ws_status ON sms_messages(workspace_id, status)''',
    '''CREATE TABLE transaction_audits(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transaction_id INTEGER NOT NULL, workspace_id INTEGER NOT NULL,
      action TEXT NOT NULL, before_json TEXT, after_json TEXT,
      at INTEGER NOT NULL)''',
  ];
}
