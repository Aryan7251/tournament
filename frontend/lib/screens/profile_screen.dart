import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../models/user_profile.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/edit_profile_dialog.dart';
import '../widgets/kyc_dialog.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _txFilter = 'all'; // all, deposit, withdrawal, entry_fee, prize_won, refund, bonus

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final user = provider.user;
    final txns = provider.transactions;

    // Stats
    final gamesWon =
        txns.where((t) => t.type == TransactionType.prizeWon).length;
    final totalWon = txns
        .where((t) => t.type == TransactionType.prizeWon)
        .fold<int>(0, (sum, item) => sum + item.amount);
    final totalPlays = max(gamesWon, txns.where((t) => t.type == TransactionType.prizeWon || t.title.contains('Aviator')).length);
    final winRate = totalPlays > 0
        ? ((gamesWon / totalPlays) * 100).round()
        : 0;

    // Filter transactions
    final filteredTxns = txns.where((t) {
      if (_txFilter == 'all') return true;
      return t.type.toStorageString() == _txFilter;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Card
          _buildProfileHeader(context, user),
          const SizedBox(height: 16),

          // Stats Grid
          _buildStatsRow(totalPlays, gamesWon, totalWon, winRate),
          const SizedBox(height: 16),

          // KYC Card
          _buildKycCard(context, user),
          const SizedBox(height: 16),

          // Saved Payout Accounts Card
          _buildPayoutMethodsCard(context, user),
          const SizedBox(height: 24),

          // Transaction Ledger Section
          _buildTransactionLedger(context, filteredTxns),
          const SizedBox(height: 24),

          // Logout Button
          Center(
            child: OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Log Out?'),
                    content: const Text('Are you sure you want to log out of your account?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await provider.logoutUser();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const AuthScreen()),
                              (route) => false,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentRed,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Log Out'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.logout, size: 16, color: AppColors.accentRed),
              label: const Text(
                'Log Out Account',
                style: TextStyle(
                  color: AppColors.accentRed,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.accentRed),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, UserProfile user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Initials Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              user.username.isNotEmpty
                  ? user.username.substring(0, 2).toUpperCase()
                  : 'LG',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user.fullName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreenBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PRO PLAYER',
                        style: TextStyle(
                          color: AppColors.accentGreen,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '@${user.username}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${user.email} • ${user.phone}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // Edit Button
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => const EditProfileDialog(),
              );
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(
      int totalPlays, int gamesWon, int totalWon, int winRate) {
    return Row(
      children: [
        _buildStatCard('GAMES', '$totalPlays', Icons.gamepad),
        const SizedBox(width: 8),
        _buildStatCard('VICTORIES', '$gamesWon', Icons.emoji_events,
            valColor: AppColors.accentAmber),
        const SizedBox(width: 8),
        _buildStatCard('TOTAL WON', '₹$totalWon', Icons.currency_rupee,
            valColor: AppColors.accentGreen),
        const SizedBox(width: 8),
        _buildStatCard('WIN RATE', '$winRate%', Icons.trending_up),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon,
      {Color? valColor}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: valColor ?? AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKycCard(BuildContext context, UserProfile user) {
    final isVerified = user.kycStatus == KycStatus.verified;
    final isRejected = user.kycStatus == KycStatus.rejected;
    final isPending = user.kycStatus == KycStatus.pending;

    final borderColor = isVerified
        ? AppColors.accentGreenBorder
        : isRejected
            ? AppColors.accentRedBorder
            : AppColors.accentAmberBorder;

    final bgColor = isVerified
        ? AppColors.accentGreenBg
        : isRejected
            ? AppColors.accentRedBg
            : AppColors.accentAmberBg;

    final iconColor = isVerified
        ? AppColors.accentGreen
        : isRejected
            ? AppColors.accentRed
            : AppColors.accentAmber;

    final statusText = isVerified
        ? 'VERIFIED'
        : isRejected
            ? 'REJECTED'
            : isPending
                ? 'PENDING APPROVAL'
                : 'NOT SUBMITTED';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isVerified
                  ? Icons.verified_user
                  : isRejected
                      ? Icons.cancel_outlined
                      : Icons.shield_outlined,
              color: iconColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'KYC Status: ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isVerified
                      ? '${user.kycDocumentType}: ${user.kycDocumentNumber}'
                      : isRejected
                          ? 'Document rejected by admin. Please re-submit valid ID proof.'
                          : isPending
                              ? 'Your submitted ID is under admin review.'
                              : 'Submit ID proof to unlock instant withdrawals.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!isVerified)
            ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => const KycDialog(),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isRejected ? AppColors.accentRed : AppColors.accentAmber,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
              ),
              child: Text(
                isRejected ? 'RE-SUBMIT' : isPending ? 'EDIT' : 'SUBMIT KYC',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }



  void _showEditPayoutModal(BuildContext context, AppProvider provider) {
    final user = provider.user;
    final upiCtrl = TextEditingController(text: user.upiId ?? '');
    final accCtrl = TextEditingController(text: user.bankAccount?.accountNumber ?? '');
    final ifscCtrl = TextEditingController(text: user.bankAccount?.ifscCode ?? '');
    final holderCtrl = TextEditingController(text: user.bankAccount?.accountHolder ?? user.fullName);
    final bankCtrl = TextEditingController(text: user.bankAccount?.bankName ?? 'HDFC Bank');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Manage Payout Destinations',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'UPI VPA DESTINATION',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentGreen,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: upiCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. username@okhdfcbank',
                  prefixIcon: Icon(Icons.alternate_email, size: 18),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'BANK ACCOUNT (IMPS)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: accCtrl,
                decoration: const InputDecoration(
                  hintText: 'Bank Account Number',
                  prefixIcon: Icon(Icons.pin, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ifscCtrl,
                      decoration: const InputDecoration(hintText: 'IFSC Code'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: bankCtrl,
                      decoration: const InputDecoration(hintText: 'Bank Name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: holderCtrl,
                decoration: const InputDecoration(
                  hintText: 'Account Holder Name',
                  prefixIcon: Icon(Icons.person_outline, size: 18),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (upiCtrl.text.trim().isNotEmpty) {
                      provider.savePayoutMethod('upi', upiCtrl.text.trim());
                    }
                    if (accCtrl.text.trim().isNotEmpty && ifscCtrl.text.trim().isNotEmpty) {
                      provider.savePayoutMethod(
                        'bank',
                        BankAccount(
                          accountNumber: accCtrl.text.trim(),
                          ifscCode: ifscCtrl.text.trim(),
                          accountHolder: holderCtrl.text.trim().isEmpty ? user.fullName : holderCtrl.text.trim(),
                          bankName: bankCtrl.text.trim().isEmpty ? 'Bank' : bankCtrl.text.trim(),
                        ),
                      );
                    }
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.accentGreen,
                        content: Text('✓ Payout destinations saved successfully!'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'SAVE PAYOUT DESTINATIONS',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPayoutMethodsCard(BuildContext context, UserProfile user) {
    final provider = context.read<AppProvider>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_outlined,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Saved Payout Destinations',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _showEditPayoutModal(context, provider),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.edit_outlined, size: 13, color: AppColors.accentGreen),
                label: const Text(
                  'EDIT / ADD',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.accentGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.alternate_email,
                    size: 16, color: AppColors.accentGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DEFAULT UPI VPA',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        user.upiId ?? 'Not set (Tap EDIT to add)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: user.upiId != null ? AppColors.textPrimary : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.bankAccount != null
                            ? '${user.bankAccount!.bankName.toUpperCase()} ACCOUNT'
                            : 'DEFAULT BANK ACCOUNT (IMPS)',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        user.bankAccount != null
                            ? 'A/C: ****${user.bankAccount!.accountNumber.length > 4 ? user.bankAccount!.accountNumber.substring(user.bankAccount!.accountNumber.length - 4) : user.bankAccount!.accountNumber} (${user.bankAccount!.ifscCode})'
                            : 'Not set (Tap EDIT to add)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: user.bankAccount != null ? AppColors.textPrimary : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionLedger(
      BuildContext context, List<Transaction> txns) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transaction Ledger & History',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTxFilterChip('all', 'All'),
              _buildTxFilterChip('deposit', 'Deposits'),
              _buildTxFilterChip('withdrawal', 'Withdrawals'),
              _buildTxFilterChip('prize_won', 'Winnings'),
              _buildTxFilterChip('entry_fee', 'Entry Fees'),
              _buildTxFilterChip('refund', 'Refunds'),
              _buildTxFilterChip('bonus', 'Bonuses'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (txns.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'No transactions recorded in this category.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: txns.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final txn = txns[idx];
              final isCredit = txn.isCredit;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isCredit
                            ? AppColors.accentGreenBg
                            : AppColors.surfaceElevated,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCredit
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        size: 16,
                        color: isCredit
                            ? AppColors.accentGreen
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            txn.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            txn.description,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isCredit ? '+' : '-'}₹${txn.amount}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isCredit
                            ? AppColors.accentGreen
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTxFilterChip(String val, String label) {
    final isSel = _txFilter == val;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSel,
        onSelected: (_) => setState(() => _txFilter = val),
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surface,
        labelStyle: TextStyle(
          color: isSel ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        side: BorderSide(
          color: isSel ? AppColors.primary : AppColors.border,
        ),
      ),
    );
  }
}
