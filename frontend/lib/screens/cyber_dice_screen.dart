import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/aviator_audio_service.dart';
import '../theme/app_theme.dart';

class CyberDiceScreen extends StatefulWidget {
  const CyberDiceScreen({super.key});

  @override
  State<CyberDiceScreen> createState() => _CyberDiceScreenState();
}

class _CyberDiceScreenState extends State<CyberDiceScreen> with TickerProviderStateMixin {
  // Mode: 'slider' (0-100 target) or 'dual' (2-12 dual dice)
  String _selectedMode = 'slider';

  // Slider Mode State
  double _sliderTarget = 50.0;
  String _condition = 'under'; // 'under' | 'over'
  double _lastRollResult = 50.00;

  // Dual Dice Mode State
  String _dualChoice = 'seven'; // 'low' | 'seven' | 'high' | 'even' | 'odd'
  int _dice1 = 3;
  int _dice2 = 4;
  int _diceSum = 7;

  // Common Game State
  int _betAmount = 50;
  bool _isRolling = false;
  bool _isWinCelebration = false;
  String? _roundMessage;
  List<dynamic> _history = [];

  // Controllers
  final TextEditingController _betController = TextEditingController(text: '50');
  late AnimationController _rollAnimController;
  late AnimationController _diceShakeController;

  final List<int> _quickBets = [10, 50, 100, 200, 500, 1000];

  @override
  void initState() {
    super.initState();
    _rollAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _diceShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _betController.addListener(() {
      final val = int.tryParse(_betController.text);
      if (val != null && val != _betAmount) {
        setState(() => _betAmount = val);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshHistory();
    });
  }

  @override
  void dispose() {
    _rollAnimController.dispose();
    _diceShakeController.dispose();
    _betController.dispose();
    super.dispose();
  }

  Future<void> _refreshHistory() async {
    final hist = await ApiService.getDiceHistory();
    if (mounted) setState(() => _history = hist);
  }

  // Calculate live multiplier for slider
  double get _currentSliderMultiplier {
    final winChance = _condition == 'under' ? _sliderTarget : (100.0 - _sliderTarget);
    return max(1.01, ((99.0 / winChance) * 100).round() / 100);
  }

  double get _currentWinChance {
    return _condition == 'under' ? _sliderTarget : (100.0 - _sliderTarget);
  }

  Future<void> _handleRoll() async {
    if (_isRolling) return;
    if (_betAmount <= 0) {
      _showSnackBar('Please enter a valid bet amount', isError: true);
      return;
    }

    final provider = context.read<AppProvider>();
    final totalBalance = provider.wallet.totalBalance;
    if (_betAmount > totalBalance) {
      _showSnackBar('Insufficient balance (Available: ₹$totalBalance)', isError: true);
      return;
    }

    setState(() {
      _isRolling = true;
      _roundMessage = null;
      _isWinCelebration = false;
    });

    AviatorAudioService.playBet();
    AviatorAudioService.playDiceRoll();

    if (_selectedMode == 'slider') {
      _rollAnimController.forward(from: 0.0);
    } else {
      _diceShakeController.forward(from: 0.0);
    }

    final res = await ApiService.rollDice(
      userId: provider.user.id,
      amount: _betAmount,
      mode: _selectedMode,
      target: _sliderTarget,
      condition: _condition,
      choice: _dualChoice,
    );

    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 400));

    if (res.success) {
      if (res.wallet != null) {
        provider.updateWallet(res.wallet!);
      }

      if (res.isWin) {
        AviatorAudioService.playWinFanfare();
      }

      setState(() {
        _isRolling = false;
        _isWinCelebration = res.isWin;
        _lastRollResult = res.rollResult;
        _dice1 = res.dice1;
        _dice2 = res.dice2;
        _diceSum = res.sum;
        _roundMessage = res.isWin
            ? '🚀 WON ₹${res.wonAmount} (${res.multiplier}x)!'
            : (_selectedMode == 'slider'
                ? '⚡ Rolled ${res.rollResult.toStringAsFixed(2)} - Try Again!'
                : '⚡ Rolled ${res.sum} - Try Again!');
      });

      _refreshHistory();
    } else {
      setState(() => _isRolling = false);
      _showSnackBar(res.message, isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isError ? AppColors.accentRed : AppColors.accentGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final balance = provider.wallet.totalBalance;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: _buildAppBar(balance),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Mode Tabs (Slider vs Dual Dice)
              _buildModeSelectorTabs(),
              const SizedBox(height: 16),

              // 2. Interactive Roll Display Arena
              if (_selectedMode == 'slider')
                _buildSliderArena()
              else
                _buildDualDiceArena(),
              const SizedBox(height: 16),

              // 3. Result Message Banner
              if (_roundMessage != null) ...[
                _buildResultBanner(),
                const SizedBox(height: 14),
              ],

              // 4. Main Roll Action Button
              _buildRollActionButton(),
              const SizedBox(height: 16),

              // 5. Betting Controls Card
              _buildBetControlsCard(),
              const SizedBox(height: 16),

              // 6. Recent Roll History Section
              _buildRecentHistorySection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(int balance) {
    return AppBar(
      backgroundColor: const Color(0xFF0F172A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9C88FF), Color(0xFF8C7AE6)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.casino, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Text(
            'CYBER DICE',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 1.2,
              color: Colors.white,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(
            AviatorAudioService.isMuted ? Icons.volume_off : Icons.volume_up,
            color: const Color(0xFFFFD32A),
            size: 20,
          ),
          onPressed: () {
            setState(() {
              AviatorAudioService.toggleMute();
            });
          },
        ),
        Container(
          margin: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accentGreen.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet, size: 14, color: AppColors.accentGreen),
              const SizedBox(width: 4),
              Text(
                '₹$balance',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Mode Selector Tabs ---
  Widget _buildModeSelectorTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF131C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _isRolling ? null : () => setState(() => _selectedMode = 'slider'),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _selectedMode == 'slider' ? const Color(0xFF9C88FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.tune, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'CYBER SLIDER',
                      style: TextStyle(
                        color: _selectedMode == 'slider' ? Colors.white : Colors.white60,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: _isRolling ? null : () => setState(() => _selectedMode = 'dual'),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _selectedMode == 'dual' ? const Color(0xFF9C88FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.casino, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'DUAL CYBER DICE',
                      style: TextStyle(
                        color: _selectedMode == 'dual' ? Colors.white : Colors.white60,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. Cyber Slider Arena ---
  Widget _buildSliderArena() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101929),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF9C88FF).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C88FF).withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Roll Number HUD Display
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF090D16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isWinCelebration
                    ? const Color(0xFF10B981)
                    : const Color(0xFF9C88FF).withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'ROLL RESULT',
                  style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                ),
                const SizedBox(height: 4),
                Text(
                  _lastRollResult.toStringAsFixed(2),
                  style: TextStyle(
                    color: _isWinCelebration ? const Color(0xFF34D399) : const Color(0xFFFFD32A),
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: (_isWinCelebration ? const Color(0xFF34D399) : const Color(0xFFFFD32A)).withValues(alpha: 0.6),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Roll Over / Roll Under Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildConditionPill('under', 'ROLL UNDER'),
              const SizedBox(width: 12),
              _buildConditionPill('over', 'ROLL OVER'),
            ],
          ),
          const SizedBox(height: 16),

          // Cyber Neon Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF10B981),
              inactiveTrackColor: const Color(0xFFEF4444),
              thumbColor: const Color(0xFFFFD32A),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              overlayColor: const Color(0xFFFFD32A).withValues(alpha: 0.2),
              trackHeight: 8,
            ),
            child: Slider(
              value: _sliderTarget,
              min: 2.0,
              max: 98.0,
              divisions: 96,
              label: _sliderTarget.toStringAsFixed(0),
              onChanged: _isRolling
                  ? null
                  : (val) {
                      setState(() => _sliderTarget = (val * 10).round() / 10);
                    },
            ),
          ),

          // Slider Labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('0', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                Text(
                  'TARGET: ${_sliderTarget.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                ),
                const Text('100', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Live Metrics: Multiplier & Win Chance
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  'MULTIPLIER',
                  '${_currentSliderMultiplier.toStringAsFixed(2)}x',
                  const Color(0xFFFFD32A),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricBox(
                  'WIN CHANCE',
                  '${_currentWinChance.toStringAsFixed(1)}%',
                  const Color(0xFF00D2D3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricBox(
                  'PROFIT',
                  '₹${((_betAmount * _currentSliderMultiplier) - _betAmount).round()}',
                  const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConditionPill(String cond, String label) {
    final isSelected = _condition == cond;
    return InkWell(
      onTap: _isRolling ? null : () => setState(() => _condition = cond),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF9C88FF) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF9C88FF) : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF090D16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  // --- 2. Dual Cyber Dice Arena ---
  Widget _buildDualDiceArena() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101929),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF9C88FF).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // 3D Neon Dice Display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildNeonDiceTile(_dice1),
              const SizedBox(width: 20),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                child: const Text('+', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              const SizedBox(width: 20),
              _buildNeonDiceTile(_dice2),
            ],
          ),
          const SizedBox(height: 12),

          // Sum Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF090D16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              'SUM: $_diceSum',
              style: const TextStyle(color: Color(0xFFFFD32A), fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
          const SizedBox(height: 18),

          // Dual Dice Bet Option Buttons
          const Text(
            'SELECT BET OUTCOME',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildDualOptionChip('low', 'LOW (2-6)', '2.30x'),
              _buildDualOptionChip('seven', 'LUCKY 7', '5.80x'),
              _buildDualOptionChip('high', 'HIGH (8-12)', '2.30x'),
              _buildDualOptionChip('even', 'EVEN SUM', '1.95x'),
              _buildDualOptionChip('odd', 'ODD SUM', '1.95x'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNeonDiceTile(int val) {
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2C3A47), Color(0xFF130F40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF9C88FF), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C88FF).withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$val',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: Color(0xFF9C88FF), blurRadius: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDualOptionChip(String choice, String label, String mult) {
    final isSelected = _dualChoice == choice;
    return InkWell(
      onTap: _isRolling ? null : () => setState(() => _dualChoice = choice),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF9C88FF) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF9C88FF) : Colors.white12,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              mult,
              style: TextStyle(
                color: isSelected ? const Color(0xFFFFD32A) : const Color(0xFF00D2D3),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Result Banner ---
  Widget _buildResultBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: _isWinCelebration
            ? const Color(0xFF10B981).withValues(alpha: 0.2)
            : const Color(0xFFEF4444).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isWinCelebration ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isWinCelebration ? Icons.emoji_events : Icons.refresh,
            color: _isWinCelebration ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            _roundMessage!,
            style: TextStyle(
              color: _isWinCelebration ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // --- Main Roll Action Button ---
  Widget _buildRollActionButton() {
    return ElevatedButton(
      onPressed: _isRolling ? null : _handleRoll,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF9C88FF),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 6,
        shadowColor: const Color(0xFF9C88FF).withValues(alpha: 0.4),
      ),
      child: _isRolling
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 10),
                Text('ROLLING DICE...', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              ],
            )
          : Text(
              'ROLL DICE FOR ₹$_betAmount',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.8),
            ),
    );
  }

  // --- Bet Controls Card ---
  Widget _buildBetControlsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131C2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BET AMOUNT (₹)',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Text('₹', style: TextStyle(color: Color(0xFFFFD32A), fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _betController,
                          enabled: !_isRolling,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildSmallBetModifier('1/2', () {
                if (_isRolling) return;
                final newAmount = max(10, (_betAmount / 2).round());
                _betController.text = '$newAmount';
              }),
              const SizedBox(width: 6),
              _buildSmallBetModifier('2X', () {
                if (_isRolling) return;
                final newAmount = _betAmount * 2;
                _betController.text = '$newAmount';
              }),
            ],
          ),
          const SizedBox(height: 8),
          // Presets
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickBets.map((q) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: _isRolling ? null : () => _betController.text = '$q',
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text(
                        '+₹$q',
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallBetModifier(String label, VoidCallback onTap) {
    return InkWell(
      onTap: _isRolling ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ),
    );
  }

  // --- Recent History ---
  Widget _buildRecentHistorySection() {
    if (_history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RECENT ROLLS',
          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _history.take(10).map((item) {
              final isWin = item['isWin'] == true;
              final mult = (item['multiplier'] as num?)?.toDouble() ?? 0.0;
              final roll = (item['rollResult'] as num?)?.toDouble() ?? (item['sum'] as num?)?.toDouble() ?? 0.0;

              return Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isWin
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isWin ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  isWin ? '${mult.toStringAsFixed(1)}x (${roll.toStringAsFixed(1)})' : '0x (${roll.toStringAsFixed(1)})',
                  style: TextStyle(
                    color: isWin ? const Color(0xFF34D399) : const Color(0xFFF87171),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
