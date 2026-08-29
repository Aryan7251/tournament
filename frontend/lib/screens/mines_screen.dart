import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/aviator_audio_service.dart';
import '../theme/app_theme.dart';

class MinesScreen extends StatefulWidget {
  const MinesScreen({super.key});

  @override
  State<MinesScreen> createState() => _MinesScreenState();
}

class _MinesScreenState extends State<MinesScreen> with TickerProviderStateMixin {
  // Game State
  bool _isLoading = false;
  bool _isActive = false;
  String? _currentRoundId;
  int _mineCount = 3;
  int _betAmount = 50;

  // 25 Tiles State
  // null = unrevealed, true = diamond, false = mine
  final List<bool?> _tileState = List.filled(25, null);
  final Set<int> _revealedIndices = {};
  List<int>? _allMines;

  double _currentMultiplier = 1.0;
  double _nextMultiplier = 1.13;
  int _currentWonAmount = 0;
  String? _roundMessage;
  bool _isWinCelebration = false;

  // Recent History
  List<dynamic> _history = [];

  // Controllers
  final TextEditingController _betController = TextEditingController(text: '50');
  late AnimationController _celebrationController;

  final List<int> _mineOptions = [1, 2, 3, 5, 8, 10, 15, 20, 24];
  final List<int> _quickBets = [10, 50, 100, 200, 500, 1000];

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _betController.addListener(() {
      final val = int.tryParse(_betController.text);
      if (val != null && val != _betAmount) {
        setState(() => _betAmount = val);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkActiveGameAndHistory();
    });
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    _betController.dispose();
    super.dispose();
  }

  Future<void> _checkActiveGameAndHistory() async {
    final provider = context.read<AppProvider>();
    final userId = provider.user.id;

    // Load History
    final hist = await ApiService.getMinesHistory();
    if (mounted) {
      setState(() => _history = hist);
    }

    // Check Active Game
    final active = await ApiService.getMinesState(userId);
    if (active != null && mounted) {
      final rawRevealed = active['revealedIndices'] as List<dynamic>? ?? [];
      final rev = rawRevealed.map((e) => (e as num).toInt()).toSet();

      setState(() {
        _isActive = true;
        _currentRoundId = active['id'] as String?;
        _mineCount = (active['mineCount'] as num?)?.toInt() ?? 3;
        _betAmount = (active['amount'] as num?)?.toInt() ?? 50;
        _betController.text = '$_betAmount';
        _currentMultiplier = (active['currentMultiplier'] as num?)?.toDouble() ?? 1.0;
        _nextMultiplier = (active['nextMultiplier'] as num?)?.toDouble() ?? 1.13;
        _currentWonAmount = (active['wonAmount'] as num?)?.toInt() ?? 0;

        _revealedIndices.clear();
        _revealedIndices.addAll(rev);
        for (int i = 0; i < 25; i++) {
          if (_revealedIndices.contains(i)) {
            _tileState[i] = true;
          } else {
            _tileState[i] = null;
          }
        }
      });
    }
  }

  // --- Start Game ---
  Future<void> _handleStartGame() async {
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
      _isLoading = true;
      _roundMessage = null;
      _isWinCelebration = false;
      _allMines = null;
      _revealedIndices.clear();
      for (int i = 0; i < 25; i++) {
        _tileState[i] = null;
      }
    });

    AviatorAudioService.playBet();

    final res = await ApiService.startMines(
      userId: provider.user.id,
      amount: _betAmount,
      mineCount: _mineCount,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success && res.round != null) {
      if (res.wallet != null) {
        provider.updateWallet(res.wallet!);
      }
      final r = res.round!;
      setState(() {
        _isActive = true;
        _currentRoundId = r['id'] as String?;
        _currentMultiplier = (r['currentMultiplier'] as num?)?.toDouble() ?? 1.0;
        _nextMultiplier = (r['nextMultiplier'] as num?)?.toDouble() ?? 1.13;
        _currentWonAmount = 0;
      });
    } else {
      _showSnackBar(res.message, isError: true);
    }
  }

  // --- Reveal Tile ---
  Future<void> _handleTileTap(int index) async {
    if (!_isActive || _isLoading || _tileState[index] != null || _currentRoundId == null) {
      return;
    }

    final provider = context.read<AppProvider>();
    setState(() => _isLoading = true);

    final res = await ApiService.revealMinesTile(
      userId: provider.user.id,
      roundId: _currentRoundId!,
      tileIndex: index,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success) {
      if (res.isMine) {
        // Exploded!
        AviatorAudioService.playExplosion();
        setState(() {
          _isActive = false;
          _tileState[index] = false;
          _allMines = res.allMines ?? [index];
          _roundMessage = '💥 BOOM! You hit a Mine!';
        });

        // Reveal remaining mines
        if (_allMines != null) {
          for (final m in _allMines!) {
            _tileState[m] = false;
          }
        }
        _refreshHistory();
      } else {
        // Diamond Found!
        AviatorAudioService.playDiamond();
        setState(() {
          _tileState[index] = true;
          _revealedIndices.add(index);
          _currentMultiplier = res.currentMultiplier;
          _currentWonAmount = res.wonAmount;
          _nextMultiplier = res.nextMultiplier ?? res.currentMultiplier;
        });

        if (res.status == 'cashed_out') {
          // Auto cashout on clearing all diamonds!
          _triggerWinCelebration(res.wonAmount, res.currentMultiplier);
          if (res.wallet != null) {
            provider.updateWallet(res.wallet!);
          }
          if (res.allMines != null) {
            _allMines = res.allMines;
            for (final m in res.allMines!) {
              if (_tileState[m] == null) _tileState[m] = false;
            }
          }
          _refreshHistory();
        }
      }
    } else {
      _showSnackBar(res.message, isError: true);
    }
  }

  // --- Cashout ---
  Future<void> _handleCashout() async {
    if (!_isActive || _isLoading || _revealedIndices.isEmpty || _currentRoundId == null) {
      return;
    }

    final provider = context.read<AppProvider>();
    setState(() => _isLoading = true);

    final res = await ApiService.cashoutMines(
      userId: provider.user.id,
      roundId: _currentRoundId!,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success) {
      if (res.wallet != null) {
        provider.updateWallet(res.wallet!);
      }
      _triggerWinCelebration(res.wonAmount, res.multiplier);
      if (res.allMines != null) {
        setState(() {
          _allMines = res.allMines;
          for (final m in res.allMines!) {
            if (_tileState[m] == null) _tileState[m] = false;
          }
        });
      }
      _refreshHistory();
    } else {
      _showSnackBar(res.message, isError: true);
    }
  }

  // --- Random Tile Pick ---
  void _pickRandomTile() {
    if (!_isActive || _isLoading) return;
    final unrevealed = <int>[];
    for (int i = 0; i < 25; i++) {
      if (_tileState[i] == null) unrevealed.add(i);
    }
    if (unrevealed.isNotEmpty) {
      final randIdx = unrevealed[Random().nextInt(unrevealed.length)];
      _handleTileTap(randIdx);
    }
  }

  void _triggerWinCelebration(int amount, double mult) {
    AviatorAudioService.playWinFanfare();
    _celebrationController.forward(from: 0.0);
    setState(() {
      _isActive = false;
      _isWinCelebration = true;
      _roundMessage = '🏆 WON ₹$amount @ ${mult}x!';
    });
  }

  Future<void> _refreshHistory() async {
    final hist = await ApiService.getMinesHistory();
    if (mounted) setState(() => _history = hist);
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
      backgroundColor: const Color(0xFF090D16),
      appBar: _buildAppBar(balance),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Provably Fair Banner & Recent Multipliers
              _buildTopStatsBar(),
              const SizedBox(height: 12),

              // 2. 5x5 Mines Grid Board
              _buildMinesGridBoard(),
              const SizedBox(height: 14),

              // 3. Multiplier & Current Payout Status Bar
              _buildMultiplierStatusBar(),
              const SizedBox(height: 14),

              // 4. Action Button (Start / Cashout)
              _buildMainActionButton(),
              const SizedBox(height: 16),

              // 5. Betting Controls (Mine count + Bet presets)
              _buildBetControlsCard(),
              const SizedBox(height: 16),

              // 6. Recent Games History Bar
              _buildRecentHistorySection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- Header ---
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
                colors: [Color(0xFF00D2D3), Color(0xFF10AC84)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.diamond, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Text(
            'MINES GOLD',
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
        // Sound toggle
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
        // Balance Chip
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

  // --- Top Stats Bar ---
  Widget _buildTopStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131C2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user, size: 14, color: Color(0xFF00D2D3)),
          const SizedBox(width: 6),
          const Text(
            'PROVABLY FAIR 97% RTP',
            style: TextStyle(
              color: Color(0xFF00D2D3),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE51D35).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.dangerous, size: 12, color: Color(0xFFE51D35)),
                const SizedBox(width: 4),
                Text(
                  '$_mineCount MINES',
                  style: const TextStyle(
                    color: Color(0xFFFF6B81),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 5x5 Mines Grid Board ---
  Widget _buildMinesGridBoard() {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF101929),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isActive
                ? const Color(0xFF00D2D3).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: _isActive ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _isActive
                  ? const Color(0xFF00D2D3).withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: 25,
          itemBuilder: (context, index) {
            return _buildTile(index);
          },
        ),
      ),
    );
  }

  Widget _buildTile(int index) {
    final state = _tileState[index];
    final isRevealed = state != null;

    Color bg;
    Color borderColor;
    Widget content;

    if (!isRevealed) {
      // Unrevealed Obsidian Tile
      bg = const Color(0xFF1E293B);
      borderColor = _isActive
          ? const Color(0xFF38BDF8).withValues(alpha: 0.3)
          : Colors.white.withValues(alpha: 0.08);

      content = Center(
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
        ),
      );
    } else if (state == true) {
      // Diamond / Gold Nugget
      bg = const Color(0xFF064E3B);
      borderColor = const Color(0xFF10B981);
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.diamond, color: Color(0xFF34D399), size: 26),
            Text(
              '+${((_currentMultiplier - 1.0) * 100).toInt()}%',
              style: const TextStyle(
                color: Color(0xFF6EE7B7),
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    } else {
      // Bomb / Mine
      bg = const Color(0xFF450A0A);
      borderColor = const Color(0xFFEF4444);
      content = const Center(
        child: Icon(Icons.brightness_low, color: Color(0xFFF87171), size: 28),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isRevealed ? 2 : 1),
        boxShadow: [
          if (isRevealed && state == true)
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.4),
              blurRadius: 10,
            )
          else if (isRevealed && state == false)
            BoxShadow(
              color: const Color(0xFFEF4444).withValues(alpha: 0.5),
              blurRadius: 10,
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: (_isActive && !isRevealed && !_isLoading)
              ? () => _handleTileTap(index)
              : null,
          child: content,
        ),
      ),
    );
  }

  // --- Multiplier Status Bar ---
  Widget _buildMultiplierStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B),
            _isActive ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Gems Uncovered
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DIAMONDS',
                style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.diamond, size: 14, color: Color(0xFF00D2D3)),
                  const SizedBox(width: 4),
                  Text(
                    '${_revealedIndices.length} / ${25 - _mineCount}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),

          // Next Multiplier
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'NEXT TILE',
                style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                '${_nextMultiplier.toStringAsFixed(2)}x',
                style: const TextStyle(color: Color(0xFFFFD32A), fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ],
          ),

          // Current Cashout Value
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'CURRENT PAYOUT',
                style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                _isActive && _revealedIndices.isNotEmpty
                    ? '₹$_currentWonAmount (${_currentMultiplier.toStringAsFixed(2)}x)'
                    : '₹0',
                style: TextStyle(
                  color: _isActive && _revealedIndices.isNotEmpty ? const Color(0xFF10B981) : Colors.white54,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Main Action Button ---
  Widget _buildMainActionButton() {
    if (_roundMessage != null && !_isActive) {
      // Display End of Round Banner above button
      return Column(
        children: [
          Container(
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
                  _isWinCelebration ? Icons.emoji_events : Icons.sentiment_dissatisfied,
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
          ),
          const SizedBox(height: 12),
          _buildStartGameButton(),
        ],
      );
    }

    if (_isActive) {
      if (_revealedIndices.isNotEmpty) {
        // Active with cashout ready
        return Row(
          children: [
            // Random Pick Button
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _pickRandomTile,
                icon: const Icon(Icons.casino, size: 16, color: Color(0xFF38BDF8)),
                label: const Text('AUTO PICK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF38BDF8),
                  side: const BorderSide(color: Color(0xFF38BDF8)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Cashout Button
            Expanded(
              flex: 4,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleCashout,
                icon: const Icon(Icons.download, size: 20, color: Colors.black),
                label: Text(
                  'CASHOUT ₹$_currentWonAmount (${_currentMultiplier.toStringAsFixed(2)}x)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD32A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 6,
                  shadowColor: const Color(0xFFFFD32A).withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        );
      } else {
        // Active but 0 tiles clicked
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _pickRandomTile,
                icon: const Icon(Icons.casino, size: 18, color: Color(0xFF00D2D3)),
                label: const Text(
                  'PICK RANDOM TILE TO START',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF00D2D3)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF00D2D3), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        );
      }
    }

    return _buildStartGameButton();
  }

  Widget _buildStartGameButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleStartGame,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 4,
        shadowColor: const Color(0xFF10B981).withValues(alpha: 0.4),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Text(
              'START MINES GAME',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.8),
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
          // 1. Mine Count Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MINES COUNT',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800),
              ),
              Text(
                '$_mineCount of 25 tiles',
                style: const TextStyle(color: Color(0xFFFF6B81), fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _mineOptions.map((count) {
                final isSelected = _mineCount == count;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: _isActive ? null : () => setState(() => _mineCount = count),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFEF4444) : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFEF4444) : Colors.white12,
                        ),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // 2. Bet Amount Input & Presets
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
                          enabled: !_isActive,
                          keyboardType: TextInputType.number,
                          cursorColor: const Color(0xFFFFD32A),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Half & Double buttons
              _buildSmallBetModifier('1/2', () {
                if (_isActive) return;
                final newAmount = max(10, (_betAmount / 2).round());
                _betController.text = '$newAmount';
              }),
              const SizedBox(width: 6),
              _buildSmallBetModifier('2X', () {
                if (_isActive) return;
                final newAmount = _betAmount * 2;
                _betController.text = '$newAmount';
              }),
            ],
          ),
          const SizedBox(height: 8),

          // Quick Preset Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickBets.map((q) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: _isActive ? null : () => _betController.text = '$q',
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
      onTap: _isActive ? null : onTap,
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
          'RECENT ROUNDS',
          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _history.take(10).map((item) {
              final mult = (item['multiplier'] as num?)?.toDouble() ?? 0.0;
              final isWin = mult > 0;
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
                  isWin ? '${mult.toStringAsFixed(2)}x' : '0x',
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
