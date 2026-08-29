enum PayoutMethod { upi, bank, paytm }

extension PayoutMethodExtension on PayoutMethod {
  String get label {
    switch (this) {
      case PayoutMethod.upi:
        return 'UPI Transfer';
      case PayoutMethod.bank:
        return 'Bank Transfer (IMPS)';
      case PayoutMethod.paytm:
        return 'Paytm Wallet';
    }
  }

  static PayoutMethod fromString(String val) {
    switch (val.toLowerCase()) {
      case 'bank':
        return PayoutMethod.bank;
      case 'paytm':
        return PayoutMethod.paytm;
      case 'upi':
      default:
        return PayoutMethod.upi;
    }
  }
}

class WithdrawalRequest {
  final String id;
  final int amount;
  final PayoutMethod method;
  final String accountDetails;
  final String status;
  final String createdAt;
  final String? processedAt;
  final String? txnReference;

  WithdrawalRequest({
    required this.id,
    required this.amount,
    required this.method,
    required this.accountDetails,
    required this.status,
    required this.createdAt,
    this.processedAt,
    this.txnReference,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'method': method.name,
        'accountDetails': accountDetails,
        'status': status,
        'createdAt': createdAt,
        'processedAt': processedAt,
        'txnReference': txnReference,
      };

  factory WithdrawalRequest.fromJson(Map<String, dynamic> json) =>
      WithdrawalRequest(
        id: json['id'] as String,
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        method: PayoutMethodExtension.fromString(
            json['method'] as String? ?? 'upi'),
        accountDetails: json['accountDetails'] as String? ?? '',
        status: json['status'] as String? ?? 'completed',
        createdAt: json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
        processedAt: json['processedAt'] as String?,
        txnReference: json['txnReference'] as String?,
      );
}
