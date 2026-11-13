class Workspace {
  const Workspace(this.id, this.name, this.type);
  final int id;
  final String name;
  final String type;
}

class Account {
  const Account({
    required this.id,
    required this.workspaceId,
    required this.bank,
    required this.name,
    required this.numberMask,
    required this.currency,
    required this.type,
    required this.openingMinor,
    required this.active,
    required this.balanceMinor,
  });
  final int id;
  final int workspaceId;
  final String bank;
  final String name;
  final String? numberMask;
  final String currency;
  final String type;
  final int openingMinor;
  final bool active;
  final int balanceMinor;
  String get label => bank.isEmpty ? name : '$bank · $name';
}

class Source {
  const Source({
    required this.id,
    required this.sender,
    required this.accountId,
    required this.templateId,
    required this.active,
  });
  final int id;
  final String sender;
  final int accountId;
  final int? templateId;
  final bool active;
}

class Tx {
  const Tx({
    required this.id,
    required this.accountId,
    required this.direction,
    required this.amountMinor,
    required this.currency,
    required this.occurredAt,
    this.reference,
    this.counterparty,
    this.counterpartyAccount,
    this.fromParty,
    this.toParty,
    this.kind,
    this.serviceChargeMinor = 0,
    this.receiptUrl,
    this.remark,
    this.category,
    this.description,
    this.balanceMinor,
    this.smsId,
    required this.source,
  });
  final int id;
  final int accountId;
  final String direction;
  final int amountMinor;
  final String currency;
  final DateTime occurredAt;
  final String? reference;
  final String? counterparty;
  final String? counterpartyAccount;
  final String? fromParty;
  final String? toParty;
  final String? kind; // keyword from the SMS, e.g. "transferred"
  final int serviceChargeMinor;
  final String? receiptUrl;
  final String? remark;
  final String? category;
  final String? description;
  final int? balanceMinor;
  final int? smsId;
  final String source;
  bool get isCredit => direction == 'credit';

  /// Money that left (or entered) the account including any service charge.
  int get totalMinor => isCredit ? amountMinor : amountMinor + serviceChargeMinor;
}

/// Data for creating/updating a transaction. accountId and occurredAt may be
/// null for SMS drafts; they are filled in from the sender configuration.
class TxInput {
  const TxInput({
    this.accountId,
    required this.direction,
    required this.amountMinor,
    this.occurredAt,
    this.reference,
    this.counterparty,
    this.counterpartyAccount,
    this.fromParty,
    this.toParty,
    this.kind,
    this.serviceChargeMinor = 0,
    this.receiptUrl,
    this.remark,
    this.category,
    this.description,
    this.balanceMinor,
  });
  final int? accountId;
  final String direction;
  final int amountMinor;
  final DateTime? occurredAt;
  final String? reference;
  final String? counterparty;
  final String? counterpartyAccount;
  final String? fromParty;
  final String? toParty;
  final String? kind;
  final int serviceChargeMinor;
  final String? receiptUrl;
  final String? remark;
  final String? category;
  final String? description;
  final int? balanceMinor;

  TxInput withAccount(int account, DateTime at, {String? defaultDescription}) => TxInput(
        accountId: account,
        direction: direction,
        amountMinor: amountMinor,
        occurredAt: at,
        reference: reference,
        counterparty: counterparty,
        counterpartyAccount: counterpartyAccount,
        fromParty: fromParty,
        toParty: toParty,
        kind: kind,
        serviceChargeMinor: serviceChargeMinor,
        receiptUrl: receiptUrl,
        remark: remark,
        category: category,
        description: description ?? defaultDescription,
        balanceMinor: balanceMinor,
      );
}

class SmsMsg {
  const SmsMsg({
    required this.id,
    required this.sender,
    required this.body,
    required this.receivedAt,
    required this.status,
    this.note,
  });
  final int id;
  final String sender;
  final String body;
  final DateTime receivedAt;
  final String status;
  final String? note;
}

class ProcessSummary {
  int saved = 0;
  int review = 0;
  int failed = 0;
  int duplicate = 0;
  @override
  String toString() =>
      'Saved $saved · review $review · failed $failed · duplicates $duplicate';
}

class DuplicateException implements Exception {
  DuplicateException(this.message);
  final String message;
  @override
  String toString() => message;
}
