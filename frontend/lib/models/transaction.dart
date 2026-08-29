enum TransactionType {
  deposit,
  withdrawal,
  entryFee,
  prizeWon,
  refund,
  bonus,
}

extension TransactionTypeExtension on TransactionType {
  String get label {
    switch (this) {
      case TransactionType.deposit:
        return 'Deposit';
      case TransactionType.withdrawal:
        return 'Withdrawal';
      case TransactionType.entryFee:
        return 'Entry Fee';
      case TransactionType.prizeWon:
        return 'Prize Won';
      case TransactionType.refund:
        return 'Refund';
      case TransactionType.bonus:
        return 'Bonus Cash';
    }
  }

  static TransactionType fromString(String val) {
    switch (val.toLowerCase()) {
      case 'withdrawal':
        return TransactionType.withdrawal;
      case 'entry_fee':
      case 'entryfee':
        return TransactionType.entryFee;
      case 'prize_won':
      case 'prizewon':
        return TransactionType.prizeWon;
      case 'refund':
        return TransactionType.refund;
      case 'bonus':
        return TransactionType.bonus;
      case 'deposit':
      default:
        return TransactionType.deposit;
    }
  }

  String toStorageString() {
    switch (this) {
      case TransactionType.deposit:
        return 'deposit';
      case TransactionType.withdrawal:
        return 'withdrawal';
      case TransactionType.entryFee:
        return 'entry_fee';
      case TransactionType.prizeWon:
        return 'prize_won';
      case TransactionType.refund:
        return 'refund';
      case TransactionType.bonus:
        return 'bonus';
    }
  }
}

enum TransactionStatus { completed, pending, failed }

class Transaction {
  final String id;
  final TransactionType type;
  final int amount;
  final TransactionStatus status;
  final String title;
  final String description;
  final String timestamp;
  final String? referenceId;
  final String? paymentMethod;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.status,
    required this.title,
    required this.description,
    required this.timestamp,
    this.referenceId,
    this.paymentMethod,
  });

  bool get isCredit =>
      type == TransactionType.deposit ||
      type == TransactionType.prizeWon ||
      type == TransactionType.refund ||
      type == TransactionType.bonus;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toStorageString(),
        'amount': amount,
        'status': status.name,
        'title': title,
        'description': description,
        'timestamp': timestamp,
        'referenceId': referenceId,
        'paymentMethod': paymentMethod,
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String,
        type: TransactionTypeExtension.fromString(
            json['type'] as String? ?? 'deposit'),
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        status: (json['status'] as String?) == 'pending'
            ? TransactionStatus.pending
            : (json['status'] as String?) == 'failed'
                ? TransactionStatus.failed
                : TransactionStatus.completed,
        title: json['title'] as String? ?? 'Transaction',
        description: json['description'] as String? ?? '',
        timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
        referenceId: json['referenceId'] as String?,
        paymentMethod: json['paymentMethod'] as String?,
      );
}
