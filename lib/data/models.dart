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
    this.category,
    this.description,
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
  final String? category;
  final String? description;
  final String source;
  bool get isCredit => direction == 'credit';
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
