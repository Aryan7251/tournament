import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/aviator_audio_service.dart';
import '../theme/app_theme.dart';
import '../widgets/aviator_flight_painter.dart';

enum AviatorState { waiting, flying, crashed }

class BetSlotState {
  String? betId;
  int amount = 50;
  bool isPlaced = false;
  bool isCashedOut = false;
  double cashoutMultiplier = 1.0;
  int wonAmount = 0;
  bool autoCashoutEnabled = false;
  double autoCashoutValue = 2.0;

  void reset() {
    betId = null;
    isPlaced = false;
    isCashedOut = false;
    cashoutMultiplier = 1.0;
    wonAmount = 0;
  }
}

class SimulatedPlayer {
  final String name;
  final int bet;
  double? cashout;
  final String avatar;

  SimulatedPlayer({
    required this.name,
    required this.bet,
    this.cashout,
    required this.avatar,
  });
}

class AviatorScreen extends StatefulWidget {
  const AviatorScreen({super.key});

  @override
  State<AviatorScreen> createState() => _AviatorScreenState();
}

class _AviatorScreenState extends State<AviatorScreen>
    with SingleTickerProviderStateMixin {
  AviatorState _state = AviatorState.waiting;
  double _currentMultiplier = 1.00;
  double _flightProgress = 0.0;
  double _flightTimeSec = 0.0;
  String _roundId = '';
  String _provablyFairHash = '';

  // High-performance isolated Notifiers for 60/120 FPS buttery smooth animation
  final ValueNotifier<double> _multiplierNotifier = ValueNotifier<double>(1.00);
  final ValueNotifier<double> _flightProgressNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> _flightTimeNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> _countdownNotifier = ValueNotifier<double>(5.0);

  // Countdown
  double _countdownSec = 5.0;
  static const double _maxCountdown = 5.0;

  Timer? _serverPollTimer;
  Timer? _animTimer;
  bool _isSoundMuted = false;
  int _activeBetTab = 0; // 0 for single bet, 1 for dual bet on mobile

  // Multiplier history (last 20 rounds from server)
  List<double> _history = [
    1.45, 3.82, 1.12, 8.40, 2.15, 1.04, 14.60, 1.95, 4.10, 1.28
  ];

  // Betting Slots (Panel 1 and Panel 2)
  final BetSlotState _slot1 = BetSlotState()..amount = 50;
  final BetSlotState _slot2 = BetSlotState()..amount = 100;

  // Controllers
  final TextEditingController _bet1Controller = TextEditingController(text: '50');
  final TextEditingController _bet2Controller = TextEditingController(text: '100');
  final TextEditingController _auto1Controller = TextEditingController(text: '2.00');
  final TextEditingController _auto2Controller = TextEditingController(text: '3.00');

  // Live active players in current round
  List<SimulatedPlayer> _livePlayers = [];

  @override
  void initState() {
    super.initState();
    _isSoundMuted = AviatorAudioService.isMuted;
    _startServerSync();
  }

  @override
  void dispose() {
    _serverPollTimer?.cancel();
    _animTimer?.cancel();
    _multiplierNotifier.dispose();
    _flightProgressNotifier.dispose();
    _flightTimeNotifier.dispose();
    _countdownNotifier.dispose();
    AviatorAudioService.stopEngine();
    _bet1Controller.dispose();
    _bet2Controller.dispose();
    _auto1Controller.dispose();
    _auto2Controller.dispose();
    super.dispose();
  }

  void _startServerSync() {
    _pollServerState();
    // 500ms server synchronization
    _serverPollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _pollServerState();
    });

    // 33ms (30-60 FPS) smooth client-side interpolation timer WITHOUT full-widget rebuilds
    _animTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted) return;
      if (_state == AviatorState.flying) {
        _flightTimeSec += 0.033;
        final t = _flightTimeSec;
        _currentMultiplier = max(_currentMultiplier, double.parse((1.00 + 0.055 * t + 0.045 * pow(t, 1.6)).toStringAsFixed(2)));
        _flightProgress = min(1.0, (_flightTimeSec / 12.0));

        _flightTimeNotifier.value = _flightTimeSec;
        _multiplierNotifier.value = _currentMultiplier;
        _flightProgressNotifier.value = _flightProgress;
      } else if (_state == AviatorState.waiting && _countdownSec > 0) {
        _countdownSec = max(0.0, _countdownSec - 0.033);
        _countdownNotifier.value = _countdownSec;
      }
    });
  }

  Future<void> _pollServerState() async {
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    final data = await ApiService.getAviatorState(provider.user.id);
    if (data == null || !mounted) return;

    final String serverStateStr = data['state'] ?? 'waiting';
    final AviatorState newState = serverStateStr == 'flying'
        ? AviatorState.flying
        : serverStateStr == 'crashed'
            ? AviatorState.crashed
            : AviatorState.waiting;

    final double serverMultiplier = (data['currentMultiplier'] as num?)?.toDouble() ?? 1.0;
    final double serverCountdown = (data['countdownSec'] as num?)?.toDouble() ?? 0.0;
    final double serverFlightTime = (data['flightTimeSec'] as num?)?.toDouble() ?? 0.0;
    final String serverRoundId = data['roundId'] ?? '';
    final String serverHash = data['hash'] ?? '';

    // State transitions audio & handling
    if (_state != AviatorState.flying && newState == AviatorState.flying) {
      AviatorAudioService.startEngine();
    } else if (_state != AviatorState.crashed && newState == AviatorState.crashed) {
      AviatorAudioService.playCrash();
    } else if (newState == AviatorState.flying) {
      AviatorAudioService.updateEnginePitch(serverMultiplier);
    } else if (newState == AviatorState.waiting && _state == AviatorState.crashed) {
      // New round started -> reset bet slots
      _slot1.reset();
      _slot2.reset();
    }

    // Sync history
    if (data['history'] is List) {
      _history = (data['history'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
    }

    // Sync simulated players
    if (data['livePlayers'] is List) {
      _livePlayers = (data['livePlayers'] as List).map((p) {
        return SimulatedPlayer(
          name: p['name'] ?? 'Player',
          bet: (p['bet'] as num?)?.toInt() ?? 50,
          cashout: (p['cashout'] as num?)?.toDouble(),
          avatar: p['avatar'] ?? 'Player',
        );
      }).toList();
    }

    // Sync server-side auto-cashout / bet status for current user
    if (data['userBets'] is List) {
      for (var b in (data['userBets'] as List)) {
        final slotNum = (b['slotNum'] as num?)?.toInt() ?? 1;
        final slot = slotNum == 1 ? _slot1 : _slot2;
        slot.betId = b['id'];
        slot.isPlaced = b['status'] == 'placed' || b['status'] == 'cashed_out';
        if (b['status'] == 'cashed_out' && !slot.isCashedOut) {
          slot.isCashedOut = true;
          slot.cashoutMultiplier = (b['cashoutMultiplier'] as num?)?.toDouble() ?? serverMultiplier;
          slot.wonAmount = (b['wonAmount'] as num?)?.toInt() ?? 0;
          AviatorAudioService.playCashout();
          if (data['wallet'] != null) {
            context.read<AppProvider>().updateWallet(Wallet.fromJson(data['wallet']));
          } else if (slot.wonAmount > 0) {
            context.read<AppProvider>().addWinnings(slot.wonAmount);
          }
        }
      }
    }

    _multiplierNotifier.value = serverMultiplier;
    _countdownNotifier.value = serverCountdown;
    _flightTimeNotifier.value = serverFlightTime;
    _flightProgressNotifier.value = min(1.0, (serverFlightTime / 12.0));

    setState(() {
      _state = newState;
      _currentMultiplier = serverMultiplier;
      _countdownSec = serverCountdown;
      _flightTimeSec = serverFlightTime;
      _roundId = serverRoundId;
      _provablyFairHash = serverHash;
    });
  }

  // --- Betting & Cashout Handlers (Fully Server Side) ---

  Future<void> _placeBet(int slotNum) async {
    final provider = context.read<AppProvider>();
    final slot = slotNum == 1 ? _slot1 : _slot2;
    final totalWallet = provider.wallet.totalBalance;

    if (slot.amount <= 0) return;
    if (slot.amount > totalWallet) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient balance! (Available: ₹$totalWallet)'),
          backgroundColor: AppColors.accentRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Deduct bet amount immediately so user sees balance updated in real-time
    provider.deductBet(slot.amount);

    final res = await ApiService.placeAviatorBet(
      userId: provider.user.id,
      slotNum: slotNum,
      amount: slot.amount,
      autoCashoutEnabled: slot.autoCashoutEnabled,
      autoCashoutValue: slot.autoCashoutValue,
    );

    if (res.success) {
      if (res.wallet != null) {
        provider.updateWallet(res.wallet!);
      }
      slot.betId = res.bet?['id'];
      slot.isPlaced = true;
      slot.isCashedOut = false;
      AviatorAudioService.playBet();
      setState(() {});
    } else {
      // Refund if bet placement failed
      provider.addWinnings(slot.amount);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: AppColors.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _cancelBet(int slotNum) async {
    final provider = context.read<AppProvider>();
    final slot = slotNum == 1 ? _slot1 : _slot2;

    if (!slot.isPlaced || slot.betId == null) {
      slot.isPlaced = false;
      setState(() {});
      return;
    }

    final res = await ApiService.cancelAviatorBet(
      userId: provider.user.id,
      betId: slot.betId!,
    );

    if (res.success) {
      if (res.wallet != null) {
        provider.updateWallet(res.wallet!);
      }
      slot.reset();
      setState(() {});
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: AppColors.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _cashOutSlot(int slotNum) async {
    if (_state != AviatorState.flying) return;
    final slot = slotNum == 1 ? _slot1 : _slot2;
    if (!slot.isPlaced || slot.isCashedOut) return;

    final provider = context.read<AppProvider>();
    final res = await ApiService.cashoutAviatorBet(
      userId: provider.user.id,
      betId: slot.betId,
    );

    if (res.success) {
      if (res.wallet != null) {
        provider.updateWallet(res.wallet!);
      }
      slot.isCashedOut = true;
      slot.cashoutMultiplier = res.cashoutMultiplier;
      slot.wonAmount = res.wonAmount;

      AviatorAudioService.playCashout();
      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.flight_takeoff, color: Colors.white),
                const SizedBox(width: 8),
                Text('Cashed Out @ ${res.cashoutMultiplier}x! Won ₹${res.wonAmount}'),
              ],
            ),
            backgroundColor: AppColors.accentGreen,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: AppColors.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Color _getMultiplierColor(double m) {
    if (m < 2.0) return const Color(0xFF3B82F6); // Blue
    if (m < 10.0) return const Color(0xFF8B5CF6); // Purple
    if (m < 50.0) return const Color(0xFFEC4899); // Pink
    return const Color(0xFFF59E0B); // Gold
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final wallet = provider.wallet;

    return Scaffold(
      backgroundColor: const Color(0xFF0F141C),
      appBar: _buildAppBar(context, wallet.totalBalance),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final isDesktop = constraints.maxWidth >= 1050;
            final isWideScreen = constraints.maxWidth >= 720;

            final mainContent = Column(
              children: [
                // 1. History Badges Bar
                _buildHistoryRibbon(),

                // 2. Flight Radar & Canvas Area
                Expanded(
                  flex: 5,
                  child: _buildFlightStage(),
                ),

                // 3. Betting Controls
                _buildBettingSection(isWideScreen: isWideScreen),
              ],
            );

            if (isDesktop) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildLiveBetsSidebar(),
                      Expanded(child: mainContent),
                    ],
                  ),
                ),
              );
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: mainContent,
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, int balance) {
    return AppBar(
      backgroundColor: const Color(0xFF131924),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
        onPressed: () => Navigator.maybePop(context),
      ),
      titleSpacing: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFFE51D35),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE51D35).withValues(alpha: 0.4),
                  blurRadius: 6,
                ),
              ],
            ),
            child: const Icon(Icons.flight, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 6),
          const Text(
            'AVIATOR',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              fontSize: 15,
              color: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        // Wallet balance
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2838),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet, size: 13, color: AppColors.accentGreen),
              const SizedBox(width: 4),
              Text(
                '₹$balance',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),

        // Sound Toggle
        IconButton(
          onPressed: () {
            setState(() {
              _isSoundMuted = !_isSoundMuted;
              AviatorAudioService.setMuted(_isSoundMuted);
            });
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          icon: Icon(
            _isSoundMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color: _isSoundMuted ? Colors.white38 : AppColors.accentAmber,
            size: 18,
          ),
        ),

        // How to Play Info Dialog
        IconButton(
          onPressed: () => _showRulesDialog(context),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          icon: const Icon(Icons.help_outline_rounded, color: Colors.white70, size: 18),
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _buildHistoryRibbon() {
    return Container(
      height: 38,
      color: const Color(0xFF131924),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _history.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (ctx, i) {
          final m = _history[i];
          final color = _getMultiplierColor(m);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              '${m.toStringAsFixed(2)}x',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlightStage() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF090D14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Canvas Flight Graph (GPU isolated & RepaintBoundary)
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _flightTimeNotifier,
                builder: (ctx, _) {
                  return CustomPaint(
                    painter: AviatorFlightPainter(
                      progress: _flightProgressNotifier.value,
                      multiplier: _multiplierNotifier.value,
                      isCrashed: _state == AviatorState.crashed,
                      isWaiting: _state == AviatorState.waiting,
                      countdownProgress: (_maxCountdown - _countdownNotifier.value) / _maxCountdown,
                      flightTimeSec: _flightTimeNotifier.value,
                    ),
                  );
                },
              ),
            ),
          ),

          // Central Animated Status / Multiplier
          if (_state == AviatorState.waiting)
            _buildWaitingIndicator()
          else if (_state == AviatorState.flying)
            _buildLiveMultiplierDisplay()
          else
            _buildCrashedDisplay(),

          // Live Active Players Chips (Top-Left corner)
          Positioned(
            top: 12,
            left: 12,
            child: RepaintBoundary(child: _buildLivePlayersBadge()),
          ),

          // Provably Fair & Round ID Badge (Bottom-Left corner)
          if (_roundId.isNotEmpty)
            Positioned(
              bottom: 8,
              left: 12,
              child: RepaintBoundary(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151C28).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_outlined, size: 10, color: Color(0xFF00D2D3)),
                      const SizedBox(width: 4),
                      Text(
                        'PROVABLY FAIR • ${_roundId.length > 10 ? _roundId.substring(0, 10) : _roundId}${_provablyFairHash.isNotEmpty ? ' • ${_provablyFairHash.substring(0, 6)}...' : ''}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
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

  Widget _buildWaitingIndicator() {
    return ValueListenableBuilder<double>(
      valueListenable: _countdownNotifier,
      builder: (ctx, countdown, _) {
        final progress = (_maxCountdown - countdown) / _maxCountdown;
        return RepaintBoundary(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      strokeWidth: 5,
                      backgroundColor: Colors.white12,
                      color: const Color(0xFFE51D35),
                    ),
                    const Icon(Icons.flight, color: Color(0xFFE51D35), size: 28),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'WAITING FOR NEXT ROUND',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Takes off in ${countdown.toStringAsFixed(1)}s',
                style: const TextStyle(
                  color: Color(0xFFFFD32A),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLiveMultiplierDisplay() {
    return ValueListenableBuilder<double>(
      valueListenable: _multiplierNotifier,
      builder: (ctx, multiplier, _) {
        return RepaintBoundary(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${multiplier.toStringAsFixed(2)}x',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                  color: Colors.white,
                  shadows: [
                    BoxShadow(
                      color: const Color(0xFFE51D35).withValues(alpha: 0.6),
                      blurRadius: 28,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCrashedDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE51D35).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE51D35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE51D35).withValues(alpha: 0.3),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'FLEW AWAY!',
            style: TextStyle(
              color: Color(0xFFE51D35),
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_currentMultiplier.toStringAsFixed(2)}x',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePlayersBadge() {
    final cashedCount = _livePlayers.where((p) => p.cashout != null).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF151C28).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.accentGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${_livePlayers.length} in Lobby',
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700),
          ),
          if (_state == AviatorState.flying && cashedCount > 0) ...[
            const SizedBox(width: 6),
            Text(
              '($cashedCount won)',
              style: const TextStyle(color: AppColors.accentGreen, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        ],
      ),
    );
  }

  // --- Live Bets Sidebar for Widescreen / Desktop ---

  Widget _buildLiveBetsSidebar() {
    return Container(
      width: 280,
      margin: const EdgeInsets.fromLTRB(12, 12, 0, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131924),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF182030),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.accentGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'LIVE ROUND BETS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_livePlayers.length} Active',
                    style: const TextStyle(
                      color: AppColors.accentGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Live Bets List
          Expanded(
            child: _livePlayers.isEmpty
                ? const Center(
                    child: Text(
                      'Waiting for bets...',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: _livePlayers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (ctx, idx) {
                      final p = _livePlayers[idx];
                      final hasCashed = p.cashout != null;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: hasCashed
                              ? AppColors.accentGreen.withValues(alpha: 0.1)
                              : const Color(0xFF1A2230),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: hasCashed
                                ? AppColors.accentGreen.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.04),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(0xFF2C3E50),
                              child: Text(
                                p.avatar,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '₹${p.bet}',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (hasCashed)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accentGreen,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${p.cashout!.toStringAsFixed(2)}x',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              )
                            else if (_state == AviatorState.flying)
                              const Text(
                                'In Flight',
                                style: TextStyle(
                                  color: Color(0xFFFFD32A),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            else
                              const Text(
                                'Waiting',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
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
  }

  // --- Betting Section with Dual Controls ---

  Widget _buildBettingSection({required bool isWideScreen}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF131924),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: isWideScreen
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildBetControlCard(
                    slotNum: 1,
                    slot: _slot1,
                    betCtrl: _bet1Controller,
                    autoCtrl: _auto1Controller,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBetControlCard(
                    slotNum: 2,
                    slot: _slot2,
                    betCtrl: _bet2Controller,
                    autoCtrl: _auto2Controller,
                  ),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bet Panels Tab Switcher (Single Bet / Dual Bet)
                Row(
                  children: [
                    _buildBetTabButton('BET 1', 0),
                    const SizedBox(width: 8),
                    _buildBetTabButton('BET 2', 1),
                  ],
                ),
                const SizedBox(height: 10),

                // Active Bet Control Panel
                if (_activeBetTab == 0)
                  _buildBetControlCard(
                    slotNum: 1,
                    slot: _slot1,
                    betCtrl: _bet1Controller,
                    autoCtrl: _auto1Controller,
                  )
                else
                  _buildBetControlCard(
                    slotNum: 2,
                    slot: _slot2,
                    betCtrl: _bet2Controller,
                    autoCtrl: _auto2Controller,
                  ),
              ],
            ),
    );
  }

  Widget _buildBetTabButton(String title, int index) {
    final isActive = _activeBetTab == index;
    final slot = index == 0 ? _slot1 : _slot2;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeBetTab = index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF1E2838) : const Color(0xFF0F141C),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? const Color(0xFFE51D35) : Colors.white10,
              width: isActive ? 1.2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white54,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              if (slot.isPlaced) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: slot.isCashedOut ? AppColors.accentGreen : const Color(0xFFFFD32A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    slot.isCashedOut ? 'WON' : '₹${slot.amount}',
                    style: TextStyle(
                      color: slot.isCashedOut ? Colors.white : Colors.black,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBetControlCard({
    required int slotNum,
    required BetSlotState slot,
    required TextEditingController betCtrl,
    required TextEditingController autoCtrl,
  }) {
    final isFlying = _state == AviatorState.flying;
    final isWaiting = _state == AviatorState.waiting;
    final currentWin = (slot.amount * _currentMultiplier).round();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2230),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Amount Controls
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    // Amount Input with - / + (Black Box)
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 16, color: Colors.white70),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: slot.isPlaced ? null : () {
                              final v = max(10, slot.amount - 10);
                              slot.amount = v;
                              betCtrl.text = '$v';
                              setState(() {});
                            },
                          ),
                          Expanded(
                            child: TextField(
                              controller: betCtrl,
                              enabled: !slot.isPlaced,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              cursorColor: const Color(0xFFFFD32A),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                filled: true,
                                fillColor: Colors.transparent,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                prefixText: '₹',
                                prefixStyle: TextStyle(
                                  color: Color(0xFFFFD32A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                              ),
                              onChanged: (v) {
                                slot.amount = int.tryParse(v) ?? 10;
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 16, color: Colors.white70),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: slot.isPlaced ? null : () {
                              final v = slot.amount + 50;
                              slot.amount = v;
                              betCtrl.text = '$v';
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Quick Chips (+₹10, +₹50, +₹100, +₹500)
                    Row(
                      children: [10, 50, 100, 500].map((amt) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1.5),
                            child: InkWell(
                              onTap: slot.isPlaced ? null : () {
                                slot.amount = amt;
                                betCtrl.text = '$amt';
                                setState(() {});
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white12),
                                ),
                                alignment: Alignment.center,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '+$amt',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
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
              const SizedBox(width: 8),

              // Right: Big Dynamic Action Button
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 68,
                  child: _buildActionButton(
                    slotNum: slotNum,
                    slot: slot,
                    isFlying: isFlying,
                    isWaiting: isWaiting,
                    currentWin: currentWin,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Auto Cashout Row (Black Box)
          Row(
            children: [
              SizedBox(
                height: 22,
                width: 22,
                child: Checkbox(
                  value: slot.autoCashoutEnabled,
                  activeColor: const Color(0xFFE51D35),
                  side: const BorderSide(color: Colors.white38),
                  onChanged: slot.isPlaced ? null : (v) {
                    setState(() => slot.autoCashoutEnabled = v ?? false);
                  },
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Auto Cash Out',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (slot.autoCashoutEnabled)
                Container(
                  width: 70,
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24, width: 1.2),
                  ),
                  child: TextField(
                    controller: autoCtrl,
                    enabled: !slot.isPlaced,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    cursorColor: const Color(0xFFFFD32A),
                    style: const TextStyle(color: Color(0xFFFFD32A), fontSize: 11, fontWeight: FontWeight.w900),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      suffixText: 'x',
                      suffixStyle: TextStyle(color: Colors.white54, fontSize: 10),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) {
                      slot.autoCashoutValue = double.tryParse(v) ?? 2.0;
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required int slotNum,
    required BetSlotState slot,
    required bool isFlying,
    required bool isWaiting,
    required int currentWin,
  }) {
    // 1. If currently Flying and Player has placed bet & NOT yet cashed out
    if (isFlying && slot.isPlaced && !slot.isCashedOut) {
      return ElevatedButton(
        onPressed: () => _cashOutSlot(slotNum),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF9F1A),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 6,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'CASH OUT',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            ),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '₹$currentWin',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
    }

    // 2. If Cashed Out successfully
    if (slot.isCashedOut) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.accentGreen.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accentGreen, width: 1.5),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: AppColors.accentGreen, size: 18),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'WON ₹${slot.wonAmount}!',
                style: const TextStyle(
                  color: AppColors.accentGreen,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 3. If Waiting and Bet is already placed
    if (isWaiting && slot.isPlaced) {
      return ElevatedButton(
        onPressed: () => _cancelBet(slotNum),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC0392B),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('BET PLACED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
            ),
            SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('CANCEL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
    }

    // 4. If Waiting and Bet is NOT placed
    if (isWaiting) {
      return ElevatedButton(
        onPressed: () => _placeBet(slotNum),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2ED573),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('BET', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('₹${slot.amount}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
    }

    // 5. Plane is Flying but player didn't bet in time
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: const Text(
        'WAITING FOR\nNEXT ROUND',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  void _showRulesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151C28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.flight_takeoff, color: Color(0xFFE51D35)),
            SizedBox(width: 8),
            Text('How to Play Aviator', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '1. Place your bet before the plane takes off during the 5s countdown.\n\n'
              '2. Watch the multiplier climb as the plane ascends into the sky.\n\n'
              '3. Cash out before the plane flies away to win (Bet × Multiplier)!\n\n'
              '4. If the plane crashes before you cash out, the bet is lost.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE51D35),
              foregroundColor: Colors.white,
            ),
            child: const Text('Got It!'),
          ),
        ],
      ),
    );
  }
}
