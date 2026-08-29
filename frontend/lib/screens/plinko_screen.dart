import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/aviator_audio_service.dart';
import '../theme/app_theme.dart';

// Represents an active falling ball on the pegboard
class _ActivePlinkoBall {
  final String id;
  final int betAmount;
  final int rows;
  final String risk;
  final List<int> path; // 0 = Left, 1 = Right
  final int landingIndex;
  final double multiplier;
  final int wonAmount;
  final Color color;
  final DateTime startTime;
  final Wallet? serverWallet;
  int lastHitRow = -1;
  bool isFinished = false;

  _ActivePlinkoBall({
    required this.id,
    required this.betAmount,
    required this.rows,
    required this.risk,
    required this.path,
    required this.landingIndex,
    required this.multiplier,
    required this.wonAmount,
    required this.color,
    required this.startTime,
    this.serverWallet,
  });
}

// Floating Win Text Animation
class _FloatingWinText {
  final String id;
  final String text;
  final Color color;
  final Offset position;
  final DateTime createdAt;

  _FloatingWinText({
    required this.id,
    required this.text,
    required this.color,
    required this.position,
    required this.createdAt,
  });
}

class PlinkoScreen extends StatefulWidget {
  const PlinkoScreen({super.key});

  @override
  State<PlinkoScreen> createState() => _PlinkoScreenState();
}

class _PlinkoScreenState extends State<PlinkoScreen> with TickerProviderStateMixin {
  // Game Configurations
  int _selectedRows = 8;
  String _selectedRisk = 'medium'; // 'low' | 'medium' | 'high'
  int _betAmount = 50;
  List<double> _multipliers = [13.0, 3.0, 1.3, 0.7, 0.4, 0.7, 1.3, 3.0, 13.0];

  // Active Balls & Animation Loop
  final List<_ActivePlinkoBall> _activeBalls = [];
  final List<_FloatingWinText> _floatingTexts = [];
  final Map<int, double> _slotHitHighlights = {}; // slotIndex -> highlight intensity (0.0 to 1.0)

  // Auto Drop State
  bool _isAutoDropping = false;
  Timer? _autoDropTimer;

  // History
  List<dynamic> _history = [];
  final List<({double multiplier, int wonAmount, Color color})> _recentMultipliers = [];

  // Controllers
  late AnimationController _gameLoopController;
  final TextEditingController _betController = TextEditingController(text: '50');
  final List<int> _quickBets = [10, 50, 100, 200, 500, 1000];
  final List<int> _availableRows = [8, 10, 12, 14, 16];

  final Map<String, ({String label, Color color, String desc})> _riskConfigs = {
    'low': (
      label: 'Low',
      color: const Color(0xFF0FB9B1),
      desc: 'High hit rate, lower max multipliers',
    ),
    'medium': (
      label: 'Medium',
      color: const Color(0xFF3867D6),
      desc: 'Balanced risk & steady multipliers',
    ),
    'high': (
      label: 'High',
      color: const Color(0xFFFF4757),
      desc: 'Jackpot thrill up to 1000x multiplier!',
    ),
  };

  // Ball Colors for exciting variety
  final List<Color> _ballColors = [
    const Color(0xFFFFD32A),
    const Color(0xFFFF4757),
    const Color(0xFF00D2D3),
    const Color(0xFF2ED573),
    const Color(0xFF9C88FF),
    const Color(0xFFFFA502),
  ];
  int _colorIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadMultipliers();

    // Continuous 60fps Game Loop for Board Physics
    _gameLoopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onGameTick);
    _gameLoopController.repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshHistory();
    });
  }

  @override
  void dispose() {
    _autoDropTimer?.cancel();
    _gameLoopController.removeListener(_onGameTick);
    _gameLoopController.dispose();
    _betController.dispose();
    super.dispose();
  }

  Future<void> _loadMultipliers() async {
    final mults = await ApiService.getPlinkoMultipliers(
      rows: _selectedRows,
      risk: _selectedRisk,
    );
    if (mounted && mults.isNotEmpty) {
      setState(() {
        _multipliers = mults;
      });
    }
  }

  Future<void> _refreshHistory() async {
    final hist = await ApiService.getPlinkoHistory();
    if (mounted) {
      setState(() {
        _history = hist;
        if (_recentMultipliers.isEmpty && hist.isNotEmpty) {
          for (var item in hist.take(15)) {
            final m = (item['multiplier'] as num?)?.toDouble() ?? 1.0;
            final w = (item['wonAmount'] as num?)?.toInt() ?? 0;
            _recentMultipliers.add((
              multiplier: m,
              wonAmount: w,
              color: _getMultiplierColor(m),
            ));
          }
        }
      });
    }
  }

  Color _getMultiplierColor(double mult) {
    if (mult >= 100.0) return const Color(0xFFFFD32A);
    if (mult >= 20.0) return const Color(0xFFFF4757);
    if (mult >= 5.0) return const Color(0xFFFA8231);
    if (mult >= 1.5) return const Color(0xFF00D2D3);
    if (mult >= 1.0) return const Color(0xFF2ED573);
    if (mult >= 0.5) return const Color(0xFF5352ED);
    return const Color(0xFF8854D0);
  }

  void _onGameTick() {
    if (!mounted) return;
    final now = DateTime.now();

    // 1. Update Falling Balls
    const double totalFallDurationMs = 2600.0;
    final finishedBalls = <_ActivePlinkoBall>[];

    for (var ball in _activeBalls) {
      final elapsedMs = now.difference(ball.startTime).inMilliseconds.toDouble();
      final progress = (elapsedMs / totalFallDurationMs).clamp(0.0, 1.0);

      // Determine current row of ball
      final currentRow = (progress * (ball.rows + 1)).floor();

      if (currentRow > ball.lastHitRow && currentRow <= ball.rows) {
        ball.lastHitRow = currentRow;
        // Play bounce sound with pitch scaling
        AviatorAudioService.playPlinkoBounce(currentRow.toDouble());
      }

      if (progress >= 1.0 && !ball.isFinished) {
        ball.isFinished = true;
        finishedBalls.add(ball);
        _handleBallLanded(ball);
      }
    }

    // Remove finished balls
    for (var b in finishedBalls) {
      _activeBalls.remove(b);
    }

    // 2. Decay Slot Highlights
    final keysToRemove = <int>[];
    _slotHitHighlights.forEach((slot, val) {
      final newVal = val - 0.05;
      if (newVal <= 0) {
        keysToRemove.add(slot);
      } else {
        _slotHitHighlights[slot] = newVal;
      }
    });
    for (var k in keysToRemove) {
      _slotHitHighlights.remove(k);
    }

    // 3. Remove Old Floating Texts (lifespan: 1400ms)
    _floatingTexts.removeWhere((item) => now.difference(item.createdAt).inMilliseconds > 1400);

    if (finishedBalls.isNotEmpty) {
      setState(() {});
    }
  }

  void _handleBallLanded(_ActivePlinkoBall ball) {
    // Flash the slot
    _slotHitHighlights[ball.landingIndex] = 1.0;

    // Play landing audio
    AviatorAudioService.playPlinkoSlot(ball.multiplier);
    if (ball.multiplier >= 5.0) {
      AviatorAudioService.playWinFanfare();
    }

    // Add recent multiplier to history strip
    setState(() {
      _recentMultipliers.insert(
        0,
        (
          multiplier: ball.multiplier,
          wonAmount: ball.wonAmount,
          color: _getMultiplierColor(ball.multiplier),
        ),
      );
      if (_recentMultipliers.length > 25) _recentMultipliers.removeLast();
    });

    // Credit winnings to wallet upon ball landing
    final provider = context.read<AppProvider>();
    if (ball.wonAmount > 0) {
      provider.addWinnings(ball.wonAmount);
    }
    final hasActiveBalls = _activeBalls.any((b) => !b.isFinished && b.id != ball.id);
    if (!hasActiveBalls && ball.serverWallet != null) {
      provider.updateWallet(ball.serverWallet!);
    }

    // Add floating win text
    _floatingTexts.add(_FloatingWinText(
      id: ball.id,
      text: ball.wonAmount > 0 ? '+₹${ball.wonAmount}' : '${ball.multiplier}x',
      color: ball.wonAmount > 0 ? const Color(0xFF2ED573) : Colors.white70,
      position: Offset(0, 0), // painter handles bottom position
      createdAt: DateTime.now(),
    ));

    _refreshHistory();
  }

  Future<void> _dropBall() async {
    if (_betAmount <= 0) {
      _showSnackBar('Please enter a valid bet amount', isError: true);
      return;
    }

    final provider = context.read<AppProvider>();
    final totalBalance = provider.wallet.totalBalance;
    if (_betAmount > totalBalance) {
      _showSnackBar('Insufficient balance (Available: ₹$totalBalance)', isError: true);
      _stopAutoDrop();
      return;
    }

    // Deduct bet amount immediately so user sees balance deducted on drop!
    provider.deductBet(_betAmount);

    // Play initial bet sound
    AviatorAudioService.playBet();

    final ballColor = _ballColors[_colorIndex % _ballColors.length];
    _colorIndex++;

    final currentRows = _selectedRows;
    final currentRisk = _selectedRisk;
    final currentBet = _betAmount;

    final res = await ApiService.dropPlinkoBall(
      userId: provider.user.id,
      amount: currentBet,
      rows: currentRows,
      risk: currentRisk,
    );

    if (!mounted) return;

    if (res.success) {
      final ball = _ActivePlinkoBall(
        id: res.roundId ?? 'pk_${DateTime.now().millisecondsSinceEpoch}',
        betAmount: currentBet,
        rows: currentRows,
        risk: currentRisk,
        path: res.path.isNotEmpty ? res.path : List.generate(currentRows, (_) => Random().nextInt(2)),
        landingIndex: res.landingIndex,
        multiplier: res.multiplier,
        wonAmount: res.wonAmount,
        color: ballColor,
        startTime: DateTime.now(),
        serverWallet: res.wallet,
      );

      setState(() {
        _activeBalls.add(ball);
      });
    } else {
      // Refund optimistic deduction if drop request failed
      provider.addWinnings(currentBet);
      _stopAutoDrop();
      _showSnackBar(res.message, isError: true);
    }
  }

  void _toggleAutoDrop() {
    if (_isAutoDropping) {
      _stopAutoDrop();
    } else {
      _startAutoDrop();
    }
  }

  void _startAutoDrop() {
    setState(() => _isAutoDropping = true);
    _dropBall();
    _autoDropTimer?.cancel();
    _autoDropTimer = Timer.periodic(const Duration(milliseconds: 380), (_) {
      if (!mounted) return;
      _dropBall();
    });
  }

  void _stopAutoDrop() {
    _autoDropTimer?.cancel();
    if (mounted) {
      setState(() => _isAutoDropping = false);
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

  static final ThemeData _plinkoDarkTheme = ThemeData.dark().copyWith(
    scaffoldBackgroundColor: const Color(0xFF070B14),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Color(0xFF2ED573),
      selectionColor: Color(0x662ED573),
      selectionHandleColor: Color(0xFF2ED573),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.transparent,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(vertical: 8),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final balance = provider.wallet.totalBalance;

    return Theme(
      data: _plinkoDarkTheme,
      child: Scaffold(
        backgroundColor: const Color(0xFF070B14),
        appBar: _buildAppBar(balance),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Top Recent Multipliers Bar
              _buildRecentMultipliersStrip(),

              // 2. Main Plinko Board Area (60fps Canvas Loop decoupled from UI state)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E1626),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF1E293B),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _gameLoopController,
                        builder: (context, _) {
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              return CustomPaint(
                                size: Size(constraints.maxWidth, constraints.maxHeight),
                                painter: _PlinkoBoardPainter(
                                  rows: _selectedRows,
                                  multipliers: _multipliers,
                                  activeBalls: _activeBalls,
                                  slotHighlights: _slotHitHighlights,
                                  floatingTexts: _floatingTexts,
                                  riskColor: _riskConfigs[_selectedRisk]?.color ?? const Color(0xFF3867D6),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Game Control Console (Rows, Risk, Bet Amount, Drop CTA)
              _buildControlsPanel(balance),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(int balance) {
    return AppBar(
      backgroundColor: const Color(0xFF090E1A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
        onPressed: () {
          _stopAutoDrop();
          Navigator.pop(context);
        },
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2ED573), Color(0xFF10AC84)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.blur_on, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'PLINKO DROP',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                'Provably Fair Pyramid',
                style: TextStyle(
                  color: Color(0xFF2ED573),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Balance Badge
        Container(
          margin: const EdgeInsets.only(right: 8, top: 10, bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2ED573).withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet, size: 14, color: Color(0xFF2ED573)),
              const SizedBox(width: 5),
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

        // Mute / Sound Toggle
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

        // History Modal
        IconButton(
          icon: const Icon(Icons.history, color: Colors.white70, size: 20),
          onPressed: _showHistorySheet,
        ),
      ],
    );
  }

  Widget _buildRecentMultipliersStrip() {
    if (_recentMultipliers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 38,
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _recentMultipliers.length,
        itemBuilder: (context, index) {
          final item = _recentMultipliers[index];
          return Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: item.color.withValues(alpha: 0.6), width: 1.2),
            ),
            alignment: Alignment.center,
            child: Text(
              '${item.multiplier}x',
              style: TextStyle(
                color: item.color,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlsPanel(int balance) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B1120),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0xFF1E293B), width: 1.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Rows Selector & Risk Selector
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rows Selector (8, 10, 12, 14, 16)
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 2, bottom: 4),
                      child: Text(
                        'ROWS',
                        style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: Row(
                        children: _availableRows.map((r) {
                          final isSelected = _selectedRows == r;
                          return Expanded(
                            child: InkWell(
                              onTap: _isAutoDropping
                                  ? null
                                  : () {
                                      setState(() => _selectedRows = r);
                                      _loadMultipliers();
                                    },
                              borderRadius: BorderRadius.circular(7),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? const LinearGradient(
                                          colors: [Color(0xFF2ED573), Color(0xFF10AC84)],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        )
                                      : null,
                                  borderRadius: BorderRadius.circular(7),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF2ED573).withValues(alpha: 0.35),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$r',
                                  style: TextStyle(
                                    color: isSelected ? const Color(0xFF070B14) : Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Risk Selector (Low, Medium, High)
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 2, bottom: 4),
                      child: Text(
                        'RISK LEVEL',
                        style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: Row(
                        children: _riskConfigs.entries.map((entry) {
                          final key = entry.key;
                          final conf = entry.value;
                          final isSelected = _selectedRisk == key;
                          return Expanded(
                            child: InkWell(
                              onTap: _isAutoDropping
                                  ? null
                                  : () {
                                      setState(() => _selectedRisk = key);
                                      _loadMultipliers();
                                    },
                              borderRadius: BorderRadius.circular(7),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? conf.color : Colors.transparent,
                                  borderRadius: BorderRadius.circular(7),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: conf.color.withValues(alpha: 0.4),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  conf.label,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Bet Amount Stepper Input & Multipliers
          Row(
            children: [
              // Amount Input with - / + Stepper (Ultra Reliable Text Rendering)
              Expanded(
                flex: 5,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF131D2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF2ED573).withValues(alpha: 0.4),
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2ED573).withValues(alpha: 0.08),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_rounded, size: 18, color: Colors.white70),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 44),
                        onPressed: () {
                          final v = max(10, _betAmount - 10);
                          setState(() {
                            _betAmount = v;
                            _betController.text = '$v';
                          });
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: _betController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: null,
                          cursorColor: const Color(0xFF2ED573),
                          cursorWidth: 2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            filled: false,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            prefixText: '₹',
                            prefixStyle: TextStyle(
                              color: Color(0xFF2ED573),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (v) {
                            final parsed = int.tryParse(v);
                            if (parsed != null) {
                              _betAmount = parsed;
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white70),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 44),
                        onPressed: () {
                          final v = _betAmount + 50;
                          setState(() {
                            _betAmount = v;
                            _betController.text = '$v';
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Quick Halve (1/2) Button
              InkWell(
                onTap: () {
                  final newBet = max(10, (_betAmount / 2).floor());
                  setState(() {
                    _betAmount = newBet;
                    _betController.text = newBet.toString();
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162032),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF23354E)),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '1/2',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Quick Double (2X) Button
              InkWell(
                onTap: () {
                  final newBet = min(balance, _betAmount * 2);
                  setState(() {
                    _betAmount = newBet;
                    _betController.text = newBet.toString();
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162032),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '2X',
                    style: TextStyle(
                      color: Color(0xFF38BDF8),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Quick MAX Button
              InkWell(
                onTap: () {
                  final newBet = balance > 0 ? balance : 100;
                  setState(() {
                    _betAmount = newBet;
                    _betController.text = newBet.toString();
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD32A), Color(0xFFFFA502)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD32A).withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'MAX',
                    style: TextStyle(
                      color: Color(0xFF070B14),
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quick Bet Preset Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickBets.map((amt) {
                final isSelected = _betAmount == amt;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _betAmount = amt;
                        _betController.text = amt.toString();
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [Color(0xFF2ED573), Color(0xFF10AC84)],
                              )
                            : null,
                        color: isSelected ? null : const Color(0xFF131D2E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF2ED573) : const Color(0xFF23354E),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF2ED573).withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        '₹$amt',
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF070B14) : const Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Row 3: Action Buttons (Drop Ball & Auto-Drop Toggle)
          Row(
            children: [
              // Auto Drop Toggle Button
              InkWell(
                onTap: _toggleAutoDrop,
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: _isAutoDropping
                        ? const LinearGradient(
                            colors: [Color(0xFFFF4757), Color(0xFFEB3B5A)],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF1E293B), Color(0xFF131D2E)],
                          ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isAutoDropping ? const Color(0xFFFF4757) : const Color(0xFF38BDF8).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isAutoDropping
                            ? const Color(0xFFFF4757).withValues(alpha: 0.4)
                            : Colors.black.withValues(alpha: 0.2),
                        blurRadius: _isAutoDropping ? 12 : 4,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isAutoDropping ? Icons.stop_circle_rounded : Icons.autorenew_rounded,
                        color: _isAutoDropping ? Colors.white : const Color(0xFF38BDF8),
                        size: 22,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isAutoDropping ? 'STOP' : 'AUTO',
                        style: TextStyle(
                          color: _isAutoDropping ? Colors.white : const Color(0xFF38BDF8),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Main DROP BALL Action Button
              Expanded(
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2ED573), Color(0xFF10AC84)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2ED573).withValues(alpha: 0.45),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _dropBall,
                      borderRadius: BorderRadius.circular(14),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.sports_baseball,
                              color: Color(0xFF070B14),
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _activeBalls.isEmpty ? 'DROP BALL' : 'DROP AGAIN (${_activeBalls.length})',
                              style: const TextStyle(
                                color: Color(0xFF070B14),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF090E1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Plinko Drop History',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text('No drop history yet', style: TextStyle(color: Colors.white54)),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _history.length,
                    itemBuilder: (ctx, idx) {
                      final item = _history[idx];
                      final mult = (item['multiplier'] as num?)?.toDouble() ?? 0.0;
                      final won = (item['wonAmount'] as num?)?.toInt() ?? 0;
                      final rows = item['rows'] ?? 8;
                      final risk = item['risk'] ?? 'medium';
                      final color = _getMultiplierColor(mult);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161F30),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${mult}x',
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$rows Rows • ${(risk as String).toUpperCase()}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Round ${item['id'] ?? ''}',
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Text(
                              won > 0 ? '+₹$won' : '₹0',
                              style: TextStyle(
                                color: won > 0 ? const Color(0xFF2ED573) : Colors.white38,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// Custom Painter for the Plinko Pegboard, Falling Balls, Ripples, and Landing Buckets
class _PlinkoBoardPainter extends CustomPainter {
  final int rows;
  final List<double> multipliers;
  final List<_ActivePlinkoBall> activeBalls;
  final Map<int, double> slotHighlights;
  final List<_FloatingWinText> floatingTexts;
  final Color riskColor;

  _PlinkoBoardPainter({
    required this.rows,
    required this.multipliers,
    required this.activeBalls,
    required this.slotHighlights,
    required this.floatingTexts,
    required this.riskColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Background Grid & Glow
    _drawBoardBackground(canvas, size);

    // 2. Compute Peg Geometry
    // Top starts with 3 pegs (Row 0)
    // Row r has (r + 3) pegs
    // Bottom row (Row rows - 1) has (rows + 2) pegs, forming (rows + 1) slots!
    const double topMargin = 26.0;
    const double bottomMargin = 48.0; // Space for multiplier buckets
    final double boardHeight = h - topMargin - bottomMargin;
    final double rowSpacing = boardHeight / (rows + 0.5);

    // Max pins at bottom is (rows + 2)
    final int maxPins = rows + 2;
    final double pinGapX = (w - 32) / (maxPins + 1);

    // 3. Draw Pegs (Pyramid)
    final pegPaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    final pegGlowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (int r = 0; r < rows; r++) {
      final pinCount = r + 3;
      final y = topMargin + (r + 0.5) * rowSpacing;
      final startX = (w / 2) - ((pinCount - 1) * pinGapX) / 2;

      for (int c = 0; c < pinCount; c++) {
        final x = startX + c * pinGapX;
        final pegPos = Offset(x, y);

        // Peg glow & core
        canvas.drawCircle(pegPos, 3.2, pegGlowPaint);
        canvas.drawCircle(pegPos, 2.2, pegPaint);
      }
    }

    // 4. Draw Bottom Multiplier Buckets
    final bucketCount = rows + 1;
    final bucketWidth = (w - 20) / bucketCount;
    final bucketY = h - 38.0;
    final bucketHeight = 30.0;

    for (int i = 0; i < bucketCount; i++) {
      final mult = (i < multipliers.length) ? multipliers[i] : 1.0;
      final color = _getBucketColor(mult);
      final highlight = slotHighlights[i] ?? 0.0;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(10 + i * bucketWidth + 1.5, bucketY, bucketWidth - 3, bucketHeight),
        const Radius.circular(6),
      );

      // Slot Background
      final fillPaint = Paint()
        ..color = Color.lerp(color.withValues(alpha: 0.85), Colors.white, highlight * 0.7)!;
      canvas.drawRRect(rect, fillPaint);

      // Highlight Glow when hit
      if (highlight > 0.0) {
        final glow = Paint()
          ..color = color.withValues(alpha: highlight * 0.9)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * highlight);
        canvas.drawRRect(rect, glow);
      }

      // Multiplier Text
      final label = mult >= 100 ? '${mult.toInt()}x' : mult >= 10 ? '${mult.toStringAsFixed(0)}x' : '${mult}x';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: mult >= 100 ? Colors.black : Colors.white,
            fontSize: bucketCount > 13 ? 8 : (bucketCount > 9 ? 9 : 10),
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
          10 + i * bucketWidth + (bucketWidth - textPainter.width) / 2,
          bucketY + (bucketHeight - textPainter.height) / 2,
        ),
      );
    }

    // 5. Draw Active Falling Balls
    final now = DateTime.now();
    const double totalDurationMs = 2600.0;

    for (var ball in activeBalls) {
      final elapsedMs = now.difference(ball.startTime).inMilliseconds.toDouble();
      final totalProgress = (elapsedMs / totalDurationMs).clamp(0.0, 1.0);

      final ballPos = _calculateBallPosition(
        progress: totalProgress,
        rows: ball.rows,
        path: ball.path,
        topMargin: topMargin,
        rowSpacing: rowSpacing,
        pinGapX: pinGapX,
        boardWidth: w,
        bucketY: bucketY,
      );

      // Ball Outer Glow
      final glowPaint = Paint()
        ..color = ball.color.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(ballPos, 7.5, glowPaint);

      // Ball Core
      final ballPaint = Paint()..color = ball.color;
      canvas.drawCircle(ballPos, 5.5, ballPaint);

      // Ball Specular Highlight
      final specPaint = Paint()..color = Colors.white.withValues(alpha: 0.8);
      canvas.drawCircle(Offset(ballPos.dx - 1.8, ballPos.dy - 1.8), 1.8, specPaint);
    }

    // 6. Draw Floating Win Texts at Bottom
    for (var textItem in floatingTexts) {
      final ageMs = now.difference(textItem.createdAt).inMilliseconds;
      final opacity = (1.0 - (ageMs / 1400.0)).clamp(0.0, 1.0);
      final dyOffset = (ageMs / 1400.0) * 24.0;

      final tp = TextPainter(
        text: TextSpan(
          text: textItem.text,
          style: TextStyle(
            color: textItem.color.withValues(alpha: opacity),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: opacity),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset((w - tp.width) / 2, bucketY - 20 - dyOffset));
    }
  }

  Offset _calculateBallPosition({
    required double progress,
    required int rows,
    required List<int> path,
    required double topMargin,
    required double rowSpacing,
    required double pinGapX,
    required double boardWidth,
    required double bucketY,
  }) {
    // Total steps = rows + 1 (from apex drop to bottom bucket)
    final double stepProgress = progress * (rows + 1);
    final int currentStep = stepProgress.floor().clamp(0, rows);
    final double subProgress = stepProgress - currentStep;

    // Calculate position at currentStep and nextStep
    final pCurrent = _getStepPoint(currentStep, rows, path, topMargin, rowSpacing, pinGapX, boardWidth, bucketY);
    final pNext = _getStepPoint(min(rows + 1, currentStep + 1), rows, path, topMargin, rowSpacing, pinGapX, boardWidth, bucketY);

    // Parabolic bounce arc interpolation between pins
    final x = pCurrent.dx + (pNext.dx - pCurrent.dx) * subProgress;
    // Add small bounce bump at pin contact
    final bounceArc = sin(subProgress * pi) * -5.0;
    final y = pCurrent.dy + (pNext.dy - pCurrent.dy) * subProgress + bounceArc;

    return Offset(x, y);
  }

  Offset _getStepPoint(
    int step,
    int rows,
    List<int> path,
    double topMargin,
    double rowSpacing,
    double pinGapX,
    double boardWidth,
    double bucketY,
  ) {
    if (step == 0) {
      // Starting drop point at apex above row 0
      return Offset(boardWidth / 2, topMargin - 8);
    }

    if (step <= rows) {
      final r = step - 1; // row index (0 to rows - 1)
      final y = topMargin + (r + 0.5) * rowSpacing;

      // Count of right steps up to this row
      int rightSteps = 0;
      for (int i = 0; i < step; i++) {
        if (i < path.length && path[i] == 1) {
          rightSteps++;
        }
      }

      // Row r has (r + 3) pins. The ball bounces near peg (rightSteps + 1)
      final pinCount = r + 3;
      final startX = (boardWidth / 2) - ((pinCount - 1) * pinGapX) / 2;
      final x = startX + (rightSteps + 0.5) * pinGapX;

      return Offset(x, y);
    }

    // Final landing in bottom slot
    int totalRight = 0;
    for (int p in path) {
      if (p == 1) totalRight++;
    }
    final bucketCount = rows + 1;
    final bucketWidth = (boardWidth - 20) / bucketCount;
    final x = 10 + totalRight * bucketWidth + bucketWidth / 2;
    return Offset(x, bucketY + 12);
  }

  Color _getBucketColor(double mult) {
    if (mult >= 100.0) return const Color(0xFFFFD32A);
    if (mult >= 20.0) return const Color(0xFFFF4757);
    if (mult >= 5.0) return const Color(0xFFFA8231);
    if (mult >= 1.5) return const Color(0xFF00D2D3);
    if (mult >= 1.0) return const Color(0xFF2ED573);
    if (mult >= 0.5) return const Color(0xFF5352ED);
    return const Color(0xFF8854D0);
  }

  void _drawBoardBackground(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background Gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0C1424), Color(0xFF080D18)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Subtle Triangle Guide / Funnel lines
    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(w / 2, 10), Offset(10, h - 45), guidePaint);
    canvas.drawLine(Offset(w / 2, 10), Offset(w - 10, h - 45), guidePaint);
  }

  @override
  bool shouldRepaint(covariant _PlinkoBoardPainter oldDelegate) => true;
}
