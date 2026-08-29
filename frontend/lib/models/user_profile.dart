class BankAccount {
  final String accountNumber;
  final String ifscCode;
  final String accountHolder;
  final String bankName;

  BankAccount({
    required this.accountNumber,
    required this.ifscCode,
    required this.accountHolder,
    required this.bankName,
  });

  Map<String, dynamic> toJson() => {
        'accountNumber': accountNumber,
        'ifscCode': ifscCode,
        'accountHolder': accountHolder,
        'bankName': bankName,
      };

  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(
        accountNumber: json['accountNumber'] as String? ?? '',
        ifscCode: json['ifscCode'] as String? ?? '',
        accountHolder: json['accountHolder'] as String? ?? '',
        bankName: json['bankName'] as String? ?? '',
      );
}

enum KycStatus { notSubmitted, pending, verified, rejected }

extension KycStatusExtension on KycStatus {
  String get label {
    switch (this) {
      case KycStatus.notSubmitted:
        return 'Not Submitted';
      case KycStatus.pending:
        return 'Pending Verification';
      case KycStatus.verified:
        return 'Verified';
      case KycStatus.rejected:
        return 'Rejected';
    }
  }

  static KycStatus fromString(String val) {
    switch (val.toLowerCase()) {
      case 'verified':
        return KycStatus.verified;
      case 'rejected':
        return KycStatus.rejected;
      case 'pending':
        return KycStatus.pending;
      case 'not_submitted':
      default:
        return KycStatus.notSubmitted;
    }
  }

  String toStorageString() {
    switch (this) {
      case KycStatus.verified:
        return 'verified';
      case KycStatus.rejected:
        return 'rejected';
      case KycStatus.pending:
        return 'pending';
      case KycStatus.notSubmitted:
        return 'not_submitted';
    }
  }
}

class UserProfile {
  final String id;
  final String username;
  final String fullName;
  final String email;
  final String phone;
  final String avatarSeed;
  final KycStatus kycStatus;
  final String? kycDocumentType;
  final String? kycDocumentNumber;
  final Map<String, String> gameIds;
  final String joinedAt;
  final String? upiId;
  final BankAccount? bankAccount;

  UserProfile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.avatarSeed,
    this.kycStatus = KycStatus.verified,
    this.kycDocumentType,
    this.kycDocumentNumber,
    required this.gameIds,
    required this.joinedAt,
    this.upiId,
    this.bankAccount,
  });

  UserProfile copyWith({
    String? id,
    String? username,
    String? fullName,
    String? email,
    String? phone,
    String? avatarSeed,
    KycStatus? kycStatus,
    String? kycDocumentType,
    String? kycDocumentNumber,
    Map<String, String>? gameIds,
    String? joinedAt,
    String? upiId,
    BankAccount? bankAccount,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      kycStatus: kycStatus ?? this.kycStatus,
      kycDocumentType: kycDocumentType ?? this.kycDocumentType,
      kycDocumentNumber: kycDocumentNumber ?? this.kycDocumentNumber,
      gameIds: gameIds ?? this.gameIds,
      joinedAt: joinedAt ?? this.joinedAt,
      upiId: upiId ?? this.upiId,
      bankAccount: bankAccount ?? this.bankAccount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'avatarSeed': avatarSeed,
        'kycStatus': kycStatus.toStorageString(),
        'kycDocumentType': kycDocumentType,
        'kycDocumentNumber': kycDocumentNumber,
        'gameIds': gameIds,
        'joinedAt': joinedAt,
        'upiId': upiId,
        'bankAccount': bankAccount?.toJson(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String? ?? 'usr_1',
        username: json['username'] as String? ?? 'LuckyGamer',
        fullName: json['fullName'] as String? ?? 'User Account',
        email: json['email'] as String? ?? 'player@luckywin.app',
        phone: json['phone'] as String? ?? '+91 98765 43210',
        avatarSeed: json['avatarSeed'] as String? ?? 'LuckyGamer',
        kycStatus: KycStatusExtension.fromString(
            json['kycStatus'] as String? ?? 'verified'),
        kycDocumentType: json['kycDocumentType'] as String?,
        kycDocumentNumber: json['kycDocumentNumber'] as String?,
        gameIds: (json['gameIds'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v.toString()),
            ) ??
            {},
        joinedAt: json['joinedAt'] as String? ?? DateTime.now().toIso8601String(),
        upiId: json['upiId'] as String?,
        bankAccount: json['bankAccount'] != null
            ? BankAccount.fromJson(json['bankAccount'] as Map<String, dynamic>)
            : null,
      );
}
