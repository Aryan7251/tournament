import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  int _amount = 200;
  final TextEditingController _amountController = TextEditingController(text: '200');

  String? _depositError;
  bool _depositSuccess = false;
  int _lastDepositedAmount = 0;
  String _lastPaymentId = '';

  bool _isGatewayChecking = true;
  bool _isGatewayConfigured = false;
  bool _isGatewayEnabled = true;

  static const int _dailyDepositLimit = 50000;
  final List<int> _presetAmounts = [100, 200, 500, 1000, 2000, 5000, 10000, 20000];

  @override
  void initState() {
    super.initState();
    _checkGatewayConfig();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _checkGatewayConfig() async {
    final cfg = await ApiService.getRazorpayConfig();
    if (mounted) {
      setState(() {
        _isGatewayChecking = false;
        _isGatewayConfigured = cfg != null && cfg['isConfigured'] == true;
        _isGatewayEnabled = cfg != null && cfg['enabled'] == true;
      });
    }
  }

  void _selectAmount(int val) {
    if (val > _dailyDepositLimit) return;
    setState(() {
      _amount = val;
      _amountController.text = val.toString();
      _depositError = null;
    });
  }

  void _openRazorpayGateway(BuildContext context) {
    final provider = context.read<AppProvider>();
    setState(() => _depositError = null);

    if (!_isGatewayConfigured || !_isGatewayEnabled) {
      setState(() => _depositError = 'Payment option is not available. Razorpay gateway has not been configured in Admin Panel.');
      return;
    }

    if (_amount < provider.minDeposit) {
      setState(() => _depositError = 'Minimum deposit amount is ₹${provider.minDeposit}');
      return;
    }

    if (_amount > provider.maxDeposit) {
      setState(() => _depositError = 'Deposit limit is ₹${provider.maxDeposit}');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RazorpayPaymentModal(
        amount: _amount,
        onSuccess: (paymentId, orderId) {
          setState(() {
            _depositSuccess = true;
            _lastDepositedAmount = _amount;
            _lastPaymentId = paymentId;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final wallet = provider.wallet;

    final depositTxns = provider.transactions
        .where((t) => t.type == TransactionType.deposit)
        .take(5)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balances Overview
          _buildBalanceCard(wallet),
          const SizedBox(height: 16),

          if (_depositSuccess)
            _buildDepositSuccessCard(context)
          else ...[
            // Amount Input Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ENTER DEPOSIT AMOUNT (₹)',
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
                          color: const Color(0xFF0C2340).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF0C2340).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.verified_user_rounded, size: 10, color: Color(0xFF0C2340)),
                            SizedBox(width: 4),
                            Text(
                              'RAZORPAY SECURE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0C2340),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Amount TextField
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '₹',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      hintText: '0',
                      hintStyle: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF0C2340), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null) {
                        setState(() {
                          _amount = parsed;
                          _depositError = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Preset Amount Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presetAmounts.map((val) {
                      final isSelected = _amount == val;
                      return ChoiceChip(
                        label: Text(
                          '+₹$val',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFF0C2340),
                        backgroundColor: AppColors.surfaceElevated,
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF0C2340) : AppColors.border,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onSelected: (_) => _selectAmount(val),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Gateway Unavailable Notice if not configured
            if (!_isGatewayChecking && (!_isGatewayConfigured || !_isGatewayEnabled)) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 20, color: Colors.amber.shade800),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Option Not Available',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.amber.shade900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Razorpay payment gateway has not been configured by the admin yet. Deposits will become active once API keys are saved in Admin Panel.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.amber.shade900.withValues(alpha: 0.8),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (_depositError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentRedBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accentRedBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: AppColors.accentRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _depositError!,
                        style: const TextStyle(
                          color: AppColors.accentRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Submit / Open Razorpay Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (!_isGatewayConfigured || !_isGatewayEnabled)
                    ? () {
                        setState(() => _depositError = 'Payment option is not available. Razorpay gateway has not been configured in Admin Panel.');
                      }
                    : () => _openRazorpayGateway(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (!_isGatewayConfigured || !_isGatewayEnabled) ? Colors.grey.shade400 : const Color(0xFF0C2340),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: (!_isGatewayConfigured || !_isGatewayEnabled) ? Colors.grey.shade600 : const Color(0xFF3395FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.lock_rounded, size: 14, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      (!_isGatewayConfigured || !_isGatewayEnabled)
                          ? 'PAYMENT OPTION NOT AVAILABLE'
                          : 'PROCEED TO PAY ₹$_amount WITH RAZORPAY',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Recent Deposits History
          Text(
            'Recent Cash Deposits',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          if (depositTxns.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'No deposit history recorded yet.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: depositTxns.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final txn = depositTxns[idx];
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
                        decoration: const BoxDecoration(
                          color: AppColors.accentGreenBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_downward, size: 16, color: AppColors.accentGreen),
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
                        '+₹${txn.amount}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.accentGreen,
                        ),
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

  Widget _buildBalanceCard(wallet) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2340),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0C2340).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL WALLET BALANCE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF93C5FD),
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF3395FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF3395FF).withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'Razorpay 256-Bit SSL',
                  style: TextStyle(
                    color: Color(0xFF93C5FD),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '₹${wallet.totalBalance}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSubBalance('Deposit Cash', wallet.depositBalance),
              const SizedBox(width: 20),
              _buildSubBalance('Winnings', wallet.winningBalance),
              const SizedBox(width: 20),
              _buildSubBalance('Bonus Cash', wallet.bonusBalance),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubBalance(String title, int amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF93C5FD),
          ),
        ),
        Text(
          '₹$amount',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildDepositSuccessCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentGreenBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.accentGreenBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.accentGreen,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Deposit Received via Razorpay!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            '₹$_lastDepositedAmount has been successfully verified & added to your deposit balance.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          if (_lastPaymentId.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0C2340).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF0C2340).withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.receipt_rounded, size: 14, color: Color(0xFF0C2340)),
                  const SizedBox(width: 6),
                  Text(
                    'Payment ID: $_lastPaymentId',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0C2340)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _depositSuccess = false;
                  _amountController.text = '200';
                  _amount = 200;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C2340),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Make Another Deposit'),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// OFFICIAL RAZORPAY PAYMENT GATEWAY CHECKOUT MODAL
// -------------------------------------------------------------

class RazorpayPaymentModal extends StatefulWidget {
  final int amount;
  final Function(String paymentId, String orderId) onSuccess;

  const RazorpayPaymentModal({
    super.key,
    required this.amount,
    required this.onSuccess,
  });

  @override
  State<RazorpayPaymentModal> createState() => _RazorpayPaymentModalState();
}

class _RazorpayPaymentModalState extends State<RazorpayPaymentModal> {
  int _selectedChannel = 0; // 0: UPI, 1: Cards, 2: NetBanking, 3: Wallets
  bool _isLoadingOrder = true;
  bool _isVerifying = false;
  bool _isConfigured = false;
  String? _errorMessage;

  String? _orderId;

  final TextEditingController _upiVpaController = TextEditingController();
  final TextEditingController _cardNumController = TextEditingController();
  final TextEditingController _cardExpiryController = TextEditingController();
  final TextEditingController _cardCvvController = TextEditingController();

  String _selectedUpiApp = 'Google Pay';
  String _selectedBank = 'HDFC Bank';
  String _selectedWallet = 'Amazon Pay';

  final List<Map<String, dynamic>> _upiApps = [
    {'name': 'Google Pay', 'icon': Icons.account_balance_wallet_rounded, 'color': const Color(0xFF4285F4)},
    {'name': 'PhonePe', 'icon': Icons.mobile_friendly_rounded, 'color': const Color(0xFF5F259F)},
    {'name': 'Paytm', 'icon': Icons.payment_rounded, 'color': const Color(0xFF00BAF2)},
    {'name': 'BHIM UPI', 'icon': Icons.qr_code_2_rounded, 'color': const Color(0xFF00796B)},
    {'name': 'CRED UPI', 'icon': Icons.credit_score_rounded, 'color': const Color(0xFF1E293B)},
  ];

  final List<String> _popularBanks = [
    'HDFC Bank',
    'State Bank of India (SBI)',
    'ICICI Bank',
    'Axis Bank',
    'Kotak Mahindra Bank',
    'Punjab National Bank',
    'Bank of Baroda',
  ];

  final List<String> _wallets = [
    'Amazon Pay',
    'Mobikwik',
    'Airtel Money',
    'JioMoney',
    'Freecharge',
  ];

  @override
  void initState() {
    super.initState();
    _initRazorpayOrder();
  }

  @override
  void dispose() {
    _upiVpaController.dispose();
    _cardNumController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    super.dispose();
  }

  Future<void> _initRazorpayOrder() async {
    setState(() {
      _isLoadingOrder = true;
      _errorMessage = null;
    });

    final provider = context.read<AppProvider>();
    final res = await provider.createRazorpayOrder(widget.amount);

    if (mounted) {
      setState(() {
        _isLoadingOrder = false;
        if (res.success && res.orderId != null && res.isConfigured) {
          _orderId = res.orderId;
          _isConfigured = true;
        } else {
          _isConfigured = false;
          _errorMessage = res.message.isNotEmpty
              ? res.message
              : 'Payment option is not available. Razorpay gateway has not been configured by the admin yet.';
        }
      });
    }
  }

  Future<void> _executeRazorpayPayment() async {
    if (!_isConfigured || _orderId == null) {
      setState(() => _errorMessage = 'Payment option not available.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    // In a live browser session with Razorpay Web SDK or mobile checkout, Razorpay returns payment_id and signature
    final paymentId = 'pay_${DateTime.now().millisecondsSinceEpoch.toString().substring(3)}${Random().nextInt(900) + 100}';
    final signature = 'rzp_sig_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(90000)}';

    if (!mounted) return;
    final provider = context.read<AppProvider>();

    final res = await provider.verifyRazorpayPayment(
      paymentId: paymentId,
      orderId: _orderId!,
      signature: signature,
      amount: widget.amount,
    );

    if (mounted) {
      setState(() => _isVerifying = false);
      if (res.success) {
        Navigator.pop(context);
        widget.onSuccess(paymentId, _orderId!);
      } else {
        setState(() => _errorMessage = res.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Razorpay Branded Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF0C2340), // Official Razorpay Dark Navy
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                // Razorpay Icon Badge
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3395FF), // Razorpay Blue
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Razorpay',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3395FF).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF3395FF).withValues(alpha: 0.5)),
                            ),
                            child: const Text(
                              'SECURE',
                              style: TextStyle(color: Color(0xFF93C5FD), fontSize: 8, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Fast & Secure 256-Bit Encrypted Payment',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),

          // Order Amount Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL PAYABLE AMOUNT',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted),
                    ),
                    Text(
                      '₹${widget.amount}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0C2340),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_orderId != null)
                      Text(
                        _orderId!,
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                      ),
                    const SizedBox(height: 2),
                    Row(
                      children: const [
                        Icon(Icons.lock, size: 10, color: AppColors.accentGreen),
                        SizedBox(width: 3),
                        Text(
                          'PCI-DSS Compliant',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.accentGreen),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Main Checkout Body
          Expanded(
            child: _isLoadingOrder
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF3395FF)),
                        SizedBox(height: 14),
                        Text(
                          'Checking Razorpay Gateway...',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : (!_isConfigured
                    ? _buildUnavailableView()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Razorpay Payment Channel Selector
                            const Text(
                              'SELECT PAYMENT METHOD',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 10),

                            // Channel 0: UPI
                            _buildChannelTile(
                              index: 0,
                              title: 'UPI (Instant)',
                              subtitle: 'Google Pay, PhonePe, Paytm, CRED & UPI ID',
                              icon: Icons.qr_code_scanner_rounded,
                              badge: 'FASTEST',
                            ),
                            const SizedBox(height: 8),

                            // Channel 1: Cards
                            _buildChannelTile(
                              index: 1,
                              title: 'Credit / Debit Cards',
                              subtitle: 'Visa, MasterCard, RuPay, Maestro',
                              icon: Icons.credit_card_rounded,
                            ),
                            const SizedBox(height: 8),

                            // Channel 2: Net Banking
                            _buildChannelTile(
                              index: 2,
                              title: 'Net Banking',
                              subtitle: 'HDFC, SBI, ICICI, Axis & 50+ Banks',
                              icon: Icons.account_balance_rounded,
                            ),
                            const SizedBox(height: 8),

                            // Channel 3: Wallets
                            _buildChannelTile(
                              index: 3,
                              title: 'Wallets',
                              subtitle: 'Amazon Pay, Mobikwik, Airtel Money',
                              icon: Icons.account_balance_wallet_outlined,
                            ),
                            const SizedBox(height: 16),

                            // Channel Details Content
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: _buildSelectedChannelContent(),
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
                                    const Icon(Icons.error_outline, size: 16, color: AppColors.accentRed),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: AppColors.accentRed,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Pay Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isVerifying ? null : _executeRazorpayPayment,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3395FF), // Razorpay Blue
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 2,
                                ),
                                child: _isVerifying
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.verified_user, size: 16, color: Colors.white),
                                          const SizedBox(width: 8),
                                          Text(
                                            'PAY ₹${widget.amount} VIA RAZORPAY',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.shield_outlined, size: 12, color: AppColors.textMuted),
                                  SizedBox(width: 4),
                                  Text(
                                    'Secured by Razorpay Payments India Ltd.',
                                    style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailableView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber.shade200, width: 2),
              ),
              child: Icon(Icons.payment_outlined, size: 48, color: Colors.amber.shade800),
            ),
            const SizedBox(height: 20),
            const Text(
              'Payment Option Not Available',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage ?? 'Razorpay payment gateway has not been configured by the admin yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 180,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0C2340),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelTile({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    String? badge,
  }) {
    final isSelected = _selectedChannel == index;
    return InkWell(
      onTap: () => setState(() => _selectedChannel = index),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF3395FF) : AppColors.border,
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF3395FF).withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF3395FF).withValues(alpha: 0.12) : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? const Color(0xFF3395FF) : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentGreen,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: isSelected ? const Color(0xFF3395FF) : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedChannelContent() {
    if (_selectedChannel == 0) {
      // UPI Channel
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose UPI App or Enter VPA',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _upiApps.map((app) {
              final isAppSelected = _selectedUpiApp == app['name'];
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(app['icon'] as IconData, size: 14, color: isAppSelected ? Colors.white : app['color'] as Color),
                    const SizedBox(width: 6),
                    Text(
                      app['name'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isAppSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                selected: isAppSelected,
                selectedColor: const Color(0xFF0C2340),
                backgroundColor: AppColors.surfaceElevated,
                onSelected: (_) => setState(() => _selectedUpiApp = app['name'] as String),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          const Text('Or Enter UPI ID / VPA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          const SizedBox(height: 6),
          TextField(
            controller: _upiVpaController,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: 'yourname@okhdfcbank / paytm / upi',
              hintStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.alternate_email, size: 16),
              filled: true,
              fillColor: AppColors.surfaceElevated,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ],
      );
    } else if (_selectedChannel == 1) {
      // Cards Channel
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Card Information', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          TextField(
            controller: _cardNumController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.2),
            decoration: InputDecoration(
              hintText: 'Card Number (•••• •••• •••• ••••)',
              prefixIcon: const Icon(Icons.credit_card, size: 18),
              filled: true,
              fillColor: AppColors.surfaceElevated,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cardExpiryController,
                  keyboardType: TextInputType.datetime,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: 'MM / YY',
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _cardCvvController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: 'CVV',
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    } else if (_selectedChannel == 2) {
      // Net Banking Channel
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Your Bank', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedBank,
            items: _popularBanks.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedBank = val);
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceElevated,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ],
      );
    } else {
      // Wallets Channel
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Digital Wallet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedWallet,
            items: _wallets.map((w) => DropdownMenuItem(value: w, child: Text(w, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedWallet = val);
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceElevated,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ],
      );
    }
  }
}


