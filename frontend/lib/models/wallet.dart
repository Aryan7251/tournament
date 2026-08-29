class Wallet {
  final int depositBalance;
  final int winningBalance;
  final int bonusBalance;

  Wallet({
    required this.depositBalance,
    required this.winningBalance,
    required this.bonusBalance,
  });

  int get totalBalance => depositBalance + winningBalance + bonusBalance;

  Wallet copyWith({
    int? depositBalance,
    int? winningBalance,
    int? bonusBalance,
  }) {
    return Wallet(
      depositBalance: depositBalance ?? this.depositBalance,
      winningBalance: winningBalance ?? this.winningBalance,
      bonusBalance: bonusBalance ?? this.bonusBalance,
    );
  }

  Map<String, dynamic> toJson() => {
        'depositBalance': depositBalance,
        'winningBalance': winningBalance,
        'bonusBalance': bonusBalance,
      };

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        depositBalance: (json['depositBalance'] as num?)?.toInt() ?? 0,
        winningBalance: (json['winningBalance'] as num?)?.toInt() ?? 0,
        bonusBalance: (json['bonusBalance'] as num?)?.toInt() ?? 0,
      );
}
