import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../models/withdrawal_request.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/kyc_dialog.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  PayoutMethod _method = PayoutMethod.upi;
  int _amount = 100;
  final TextEditingController _amountController =
      TextEditingController(text: '100');

  // UPI
  late TextEditingController _upiController;

  // Bank
  late TextEditingController _accNumController;
  late TextEditingController _ifscController;
  late TextEditingController _holderController;
  late TextEditingController _bankNameController;

  // Paytm
  late TextEditingController _paytmController;

  bool _isProcessing = false;
  String? _errorMessage;
  bool _withdrawSuccess = false;
  int _lastWithdrawnAmount = 0;
  String _lastWithdrawnDest = '';
  bool _savePayoutDestination = true;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppProvider>().user;
    _upiController = TextEditingController(text: user.upiId ?? '');
    _accNumController =
        TextEditingController(text: user.bankAccount?.accountNumber ?? '');
    _ifscController =
        TextEditingController(text: user.bankAccount?.ifscCode ?? '');
    _holderController = TextEditingController(
        text: user.bankAccount?.accountHolder ?? user.fullName);
    _bankNameController =
        TextEditingController(text: user.bankAccount?.bankName ?? 'HDFC Bank');
    _paytmController = TextEditingController(text: user.phone);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _upiController.dispose();
    _accNumController.dispose();
    _ifscController.dispose();
    _holderController.dispose();
    _bankNameController.dispose();
    _paytmController.dispose();
    super.dispose();
  }

  void _handlePercentSelect(int pct, int winningBalance) {
    final calculated = ((winningBalance * pct) / 100).floor();
    setState(() {
      _amount = calculated;
      _amountController.text = calculated.toString();
    });
  }

  void _saveCurrentPayoutDestination(AppProvider provider) {
    if (_method == PayoutMethod.upi) {
      final upi = _upiController.text.trim();
      if (upi.isEmpty || !upi.contains('@')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid UPI ID (e.g. name@bank)')),
        );
        return;
      }
      provider.savePayoutMethod('upi', upi);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.accentGreen,
          content: Text('✓ Saved UPI ID ($upi) as default payout destination!'),
        ),
      );
    } else if (_method == PayoutMethod.bank) {
      final acc = _accNumController.text.trim();
      final ifsc = _ifscController.text.trim();
      final holder = _holderController.text.trim();
      final bank = _bankNameController.text.trim();
      if (acc.isEmpty || ifsc.isEmpty || holder.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all bank details before saving')),
        );
        return;
      }
      provider.savePayoutMethod(
        'bank',
        BankAccount(
          accountNumber: acc,
          ifscCode: ifsc,
          accountHolder: holder,
          bankName: bank.isEmpty ? 'Bank' : bank,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.accentGreen,
          content: Text('✓ Saved Bank Account ($bank - $acc) as default payout destination!'),
        ),
      );
    }
  }

  void _handleWithdraw(AppProvider provider) async {
    setState(() => _errorMessage = null);

    if (provider.user.kycStatus != KycStatus.verified) {
      setState(() {
        _errorMessage =
            'KYC verification is mandatory before processing withdrawals.';
      });
      return;
    }

    if (_amount < provider.minWithdrawal) {
      setState(() {
        _errorMessage = 'Minimum withdrawal amount is ₹${provider.minWithdrawal}.';
      });
      return;
    }

    if (_amount > provider.maxWithdrawal) {
      setState(() {
        _errorMessage = 'Maximum single withdrawal limit is ₹${provider.maxWithdrawal}.';
      });
      return;
    }

    if (_amount > provider.wallet.winningBalance) {
      setState(() {
        _errorMessage =
            'Maximum withdrawable balance is ₹${provider.wallet.winningBalance}.';
      });
      return;
    }

    String destinationDetails = '';
    if (_method == PayoutMethod.upi) {
      final upi = _upiController.text.trim();
      if (upi.isEmpty || !upi.contains('@')) {
        setState(() => _errorMessage = 'Please enter a valid UPI ID (e.g. name@bank)');
        return;
      }
      destinationDetails = upi;
      if (_savePayoutDestination) {
        provider.savePayoutMethod('upi', upi);
      }
    } else if (_method == PayoutMethod.bank) {
      final acc = _accNumController.text.trim();
      final ifsc = _ifscController.text.trim();
      final holder = _holderController.text.trim();
      final bank = _bankNameController.text.trim();
      if (acc.isEmpty || ifsc.isEmpty || holder.isEmpty) {
        setState(() => _errorMessage = 'Please complete all bank transfer fields');
        return;
      }
      final masked = acc.length > 4 ? '****${acc.substring(acc.length - 4)}' : acc;
      destinationDetails = '$holder - $masked ($ifsc)';
      if (_savePayoutDestination) {
        provider.savePayoutMethod(
          'bank',
          BankAccount(
            accountNumber: acc,
            ifscCode: ifsc,
            accountHolder: holder,
            bankName: bank.isEmpty ? 'Bank' : bank,
          ),
        );
      }
    } else if (_method == PayoutMethod.paytm) {
      final phone = _paytmController.text.trim();
      if (phone.length < 10) {
        setState(() => _errorMessage = 'Please enter a valid 10-digit mobile number');
        return;
      }
      destinationDetails = 'Paytm Wallet ($phone)';
    }

    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 900));

    final result = provider.withdrawFunds(_amount, _method, destinationDetails);

    if (mounted) {
      setState(() {
        _isProcessing = false;
        if (result.success) {
          _withdrawSuccess = true;
          _lastWithdrawnAmount = _amount;
          _lastWithdrawnDest = destinationDetails;
        } else {
          _errorMessage = result.message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final user = provider.user;
    final wallet = provider.wallet;
    final withdrawals = provider.withdrawals;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Withdrawable Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'WITHDRAWABLE WINNINGS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreenBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt,
                              size: 12, color: AppColors.accentGreen),
                          SizedBox(width: 2),
                          Text(
                            'Instant IMPS',
                            style: TextStyle(
                              color: AppColors.accentGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '₹${wallet.winningBalance}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.accentAmber,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Winnings can be withdrawn 24x7 with 0% platform fee. Deposit balance: ₹${wallet.depositBalance}.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // KYC verification banner if not verified
          if (user.kycStatus != KycStatus.verified)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentAmberBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accentAmberBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.accentAmber, size: 22),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KYC Verification Required',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accentAmber,
                          ),
                        ),
                        Text(
                          'Verify PAN / Aadhaar card to unlock instant payouts.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => const KycDialog(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentAmber,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('VERIFY', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          if (_withdrawSuccess)
            _buildWithdrawSuccessCard(context)
          else ...[
            // Amount Input Card
            Container(
              padding: const EdgeInsets.all(20),
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
                      const Text(
                        'ENTER WITHDRAWAL AMOUNT (₹)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accentAmber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'MIN: ₹${provider.minWithdrawal} | MAX: ₹${provider.maxWithdrawal}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: AppColors.accentAmber,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      final p = int.tryParse(val);
                      setState(() => _amount = p ?? 0);
                    },
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 16, right: 8),
                        child: Text(
                          '₹',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.accentAmber,
                          ),
                        ),
                      ),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 0, minHeight: 0),
                      hintText: '0',
                      fillColor: AppColors.surfaceElevated,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Quick Percentage Chips
                  Row(
                    children: [25, 50, 75, 100].map((pct) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: OutlinedButton(
                            onPressed: () => _handlePercentSelect(
                                pct, wallet.winningBalance),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: Text(
                              '$pct%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Payout Destination
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SELECT PAYOUT DESTINATION',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),

                  // Method Tabs
                  Row(
                    children: [
                      _buildMethodTab(PayoutMethod.upi, 'UPI ID',
                          Icons.smartphone_outlined),
                      const SizedBox(width: 8),
                      _buildMethodTab(PayoutMethod.bank, 'Bank Account',
                          Icons.account_balance_outlined),
                      const SizedBox(width: 8),
                      _buildMethodTab(PayoutMethod.paytm, 'Paytm Wallet',
                          Icons.account_balance_wallet_outlined),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Form Fields depending on method
                  if (_method == PayoutMethod.upi) ...[
                    const Text(
                      'UPI ID (VPA)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _upiController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. yourname@okhdfcbank',
                        prefixIcon: Icon(Icons.alternate_email, size: 18),
                      ),
                    ),
                  ] else if (_method == PayoutMethod.bank) ...[
                    const Text(
                      'ACCOUNT NUMBER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _accNumController,
                      decoration: const InputDecoration(
                        hintText: 'Enter bank account number',
                        prefixIcon: Icon(Icons.pin, size: 18),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'IFSC CODE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _ifscController,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. HDFC0001234',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ACCOUNT HOLDER',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _holderController,
                                decoration: const InputDecoration(
                                  hintText: 'Full name on bank',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ] else if (_method == PayoutMethod.paytm) ...[
                    const Text(
                      'PAYTM REGISTERED MOBILE NUMBER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _paytmController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: '10-digit mobile number',
                        prefixIcon: Icon(Icons.phone_android, size: 18),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 12),

                  // Save destination option row
                  Row(
                    children: [
                      InkWell(
                        onTap: () => setState(() => _savePayoutDestination = !_savePayoutDestination),
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: Checkbox(
                                value: _savePayoutDestination,
                                activeColor: AppColors.accentGreen,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (val) => setState(() => _savePayoutDestination = val ?? true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Save destination for future withdrawals',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _saveCurrentPayoutDestination(provider),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.bookmark_added_outlined, size: 14, color: AppColors.accentGreen),
                        label: const Text(
                          'Save Now',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accentGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentRedBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accentRedBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: AppColors.accentRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.accentRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Withdraw Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _isProcessing ? null : () => _handleWithdraw(provider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'WITHDRAW ₹$_amount TO ${_method.label.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Payout History
          Text(
            'Recent Withdrawal Settlements',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          if (withdrawals.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'No withdrawal requests processed yet.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: withdrawals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final wth = withdrawals[idx];
                final isRequested = wth.status == 'requested';
                final isProcessing = wth.status == 'processing';
                final isCompleted = wth.status == 'completed';
                final isRejected = wth.status == 'rejected';

                final statusColor = isCompleted
                    ? AppColors.accentGreen
                    : isRejected
                        ? AppColors.accentRed
                        : isProcessing
                            ? const Color(0xFF38BDF8)
                            : AppColors.accentAmber;

                final statusBg = isCompleted
                    ? AppColors.accentGreenBg
                    : isRejected
                        ? AppColors.accentRedBg
                        : isProcessing
                            ? const Color(0xFF0C4A6E).withValues(alpha: 0.3)
                            : AppColors.accentAmberBg;

                final statusLabel = isCompleted
                    ? 'SETTLED'
                    : isRejected
                        ? 'REFUNDED'
                        : isProcessing
                            ? 'PROCESSING'
                            : 'REQUESTED (4H HOLD)';

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isRequested
                          ? AppColors.accentAmberBorder
                          : isProcessing
                              ? const Color(0xFF0284C7)
                              : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isCompleted
                              ? Icons.check_circle_outline
                              : isRejected
                                  ? Icons.cancel_outlined
                                  : isProcessing
                                      ? Icons.hourglass_top
                                      : Icons.access_time,
                          size: 16,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payout via ${wth.method.label}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              wth.accountDetails,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (isRequested)
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Text(
                                  'Security verification hold active (moves to processing in 4h)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.accentAmber,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else if (isProcessing)
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Text(
                                  'Admin reviewing & preparing bank dispatch',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF38BDF8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${wth.amount}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildMethodTab(PayoutMethod m, String label, IconData icon) {
    final isSel = _method == m;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _method = m),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? AppColors.primary : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSel ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 18,
                  color: isSel ? Colors.white : AppColors.textSecondary),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSel ? Colors.white : AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWithdrawSuccessCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentAmberBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: AppColors.accentAmberBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.access_time_filled,
              color: AppColors.accentAmber,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Withdrawal Requested 🕒',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your withdrawal request of ₹$_lastWithdrawnAmount to $_lastWithdrawnDest has been placed.\n\nSecurity cooling hold is active. Your request will automatically transition to PROCESSING in 4 hours, and then be cleared by admin.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() => _withdrawSuccess = false),
              child: const Text('VIEW STATUS IN WALLET'),
            ),
          ),
        ],
      ),
    );
  }
}
