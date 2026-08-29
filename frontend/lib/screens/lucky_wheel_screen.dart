import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/aviator_audio_service.dart';
import '../theme/app_theme.dart';

class LuckyWheelScreen extends StatefulWidget {
  const LuckyWheelScreen({super.key});

  @override
  State<LuckyWheelScreen> createState() => _LuckyWheelScreenState();
}

class _LuckyWheelScreenState extends State<LuckyWheelScreen> with SingleTickerProviderStateMixin {
  // Game Configuration & State
  String _selectedRisk = 'medium'; // 'low' | 'medium' | 'high'
  int _betAmount = 50;
  bool _isSpinning = false;
  String? _roundMessage;
  bool _isWinCelebration = false;
  List<dynamic> _history = [];

  // Wheel Segments (12 segments default)
  List<dynamic> _segments = [];

  // Wheel Animation
  late AnimationController _wheelController;
  late Animation<double> _wheelAnimation;
  double _currentWheelAngle = 0.0;
  double _targetWheelAngle = 0.0;
  int _lastTickSegment = -1;

  final TextEditingController _betController = TextEditingController(text: '50');
  final List<int> _quickBets = [10, 50, 100, 200, 500, 1000];

  final Map<String, ({String label, Color color, String desc})> _riskConfigs = {
    'low': (
      label: 'Low Risk',
      color: const Color(0xFF0FB9B1),
      desc: 'High hit rate, multipliers up to 5x',
    ),
    'medium': (
      label: 'Classic Neon',
      color: const Color(0xFF3867D6),
      desc: 'Balanced risk, multipliers up to 25x',
    ),
    'high': (
      label: 'Jackpot Gold',
      color: const Color(0xFFFA8231),
      desc: 'High roller thrill, multipliers up to 100x!',
    ),
  };

  @override
  void initState() {
    super.initState();
    _loadSegmentsForRisk(_selectedRisk);

    _wheelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    _wheelAnimation = CurvedAnimation(
      parent: _wheelController,
      curve: Curves.easeOutCubic,
    );

    _wheelController.addListener(() {
      final currentAngle = _currentWheelAngle + (_targetWheelAngle - _currentWheelAngle) * _wheelAnimation.value;

      // Play tick sound when passing slices
      if (_segments.isNotEmpty) {
        final totalSegments = _segments.length;
        final sliceAngle = (2 * pi) / totalSegments;
        final currentSegment = (currentAngle / sliceAngle).floor() % totalSegments;
        if (currentSegment != _lastTickSegment) {
          _lastTickSegment = currentSegment;
          AviatorAudioService.playWheelClick();
        }
      }

      setState(() {});
    });

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
    _wheelController.dispose();
    _betController.dispose();
    super.dispose();
  }

  Future<void> _loadSegmentsForRisk(String risk) async {
    final segs = await ApiService.getWheelSegments(risk);
    if (mounted) {
      setState(() {
        _segments = segs;
      });
    }
  }

  Future<void> _refreshHistory() async {
    final hist = await ApiService.getWheelHistory();
    if (mounted) setState(() => _history = hist);
  }

  Future<void> _handleSpin() async {
    if (_isSpinning) return;
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
      _isSpinning = true;
      _roundMessage = null;
      _isWinCelebration = false;
    });

    AviatorAudioService.playBet();

    final res = await ApiService.spinWheel(
      userId: provider.user.id,
      amount: _betAmount,
      risk: _selectedRisk,
    );

    if (!mounted) return;

    if (res.success) {
      final segmentCount = _segments.isNotEmpty ? _segments.length : 12;
      final landingIndex = res.landingIndex;

      // Wheel calculations:
      // Slices are laid out clockwise starting from top/right
      // To land slice at top pointer (angle = 3*pi/2 or -pi/2), we compute target angle
      final sliceAngle = (2 * pi) / segmentCount;
      // Center of target slice
      final targetSliceCenter = (landingIndex + 0.5) * sliceAngle;

      // Spin at least 5 to 7 full rotations for excitement
      const fullRotations = 5 * 2 * pi;
      // Calculate delta angle
      _currentWheelAngle = _currentWheelAngle % (2 * pi);
      _targetWheelAngle = _currentWheelAngle + fullRotations + (2 * pi - targetSliceCenter) + (3 * pi / 2);

      _wheelController.forward(from: 0.0).then((_) {
        if (!mounted) return;

        if (res.wallet != null) {
          provider.updateWallet(res.wallet!);
        }

        if (res.isWin) {
          AviatorAudioService.playWinFanfare();
        }

        setState(() {
          _isSpinning = false;
          _isWinCelebration = res.isWin;
          _currentWheelAngle = _targetWheelAngle;
          _roundMessage = res.isWin
              ? '🎉 WON ₹${res.wonAmount} (${res.multiplier}x)!'
              : '⚡ Hit 0x - Try Again!';
        });

        _refreshHistory();
      });
    } else {
      setState(() => _isSpinning = false);
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
      backgroundColor: const Color(0xFF090D16),
      appBar: _buildAppBar(balance),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Risk Selector Tabs
              _buildRiskSelectorTabs(),
              const SizedBox(height: 16),

              // 2. Animated Lucky Wheel CustomPainter Widget
              _buildWheelDisplay(),
              const SizedBox(height: 16),

              // 3. Result Message Banner
              if (_roundMessage != null) ...[
                _buildResultBanner(),
                const SizedBox(height: 14),
              ],

              // 4. Spin Button
              _buildSpinButton(),
              const SizedBox(height: 16),

              // 5. Bet Input & Quick Bet Controls
              _buildBetControlsCard(),
              const SizedBox(height: 16),

              // 6. Recent Spin Multipliers History
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
                colors: [Color(0xFFFF9F1A), Color(0xFFFF4757)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.pie_chart, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Text(
            'LUCKY WHEEL',
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

  // --- Risk Selector Tabs ---
  Widget _buildRiskSelectorTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF131C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: _riskConfigs.entries.map((entry) {
          final riskKey = entry.key;
          final cfg = entry.value;
          final isSelected = _selectedRisk == riskKey;

          return Expanded(
            child: InkWell(
              onTap: _isSpinning
                  ? null
                  : () {
                      setState(() => _selectedRisk = riskKey);
                      _loadSegmentsForRisk(riskKey);
                    },
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? cfg.color : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  cfg.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Wheel Display Widget ---
  Widget _buildWheelDisplay() {
    final curAngle = _wheelController.isAnimating
        ? _currentWheelAngle + (_targetWheelAngle - _currentWheelAngle) * _wheelAnimation.value
        : _currentWheelAngle;

    return Center(
      child: SizedBox(
        width: 320,
        height: 320,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer Neon Glow Ring
            Container(
              width: 310,
              height: 310,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _riskConfigs[_selectedRisk]!.color.withValues(alpha: 0.35),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),

            // Rotating Wheel Canvas
            Transform.rotate(
              angle: curAngle,
              child: CustomPaint(
                size: const Size(300, 300),
                painter: _WheelCanvasPainter(segments: _segments),
              ),
            ),

            // Center Golden Hub
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFFFFD32A), Color(0xFFFA8231), Color(0xFF0F172A)],
                ),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(Icons.star, color: Colors.white, size: 24),
            ),

            // Top Pointer Needle
            Positioned(
              top: 0,
              child: CustomPaint(
                size: const Size(28, 36),
                painter: _PointerPainter(),
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

  // --- Spin Action Button ---
  Widget _buildSpinButton() {
    return ElevatedButton(
      onPressed: _isSpinning ? null : _handleSpin,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFA8231),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 6,
        shadowColor: const Color(0xFFFA8231).withValues(alpha: 0.4),
      ),
      child: _isSpinning
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 10),
                Text('SPINNING...', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              ],
            )
          : Text(
              'SPIN WHEEL FOR ₹$_betAmount',
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
                          enabled: !_isSpinning,
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
              _buildSmallBetModifier('1/2', () {
                if (_isSpinning) return;
                final newAmount = max(10, (_betAmount / 2).round());
                _betController.text = '$newAmount';
              }),
              const SizedBox(width: 6),
              _buildSmallBetModifier('2X', () {
                if (_isSpinning) return;
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
                    onTap: _isSpinning ? null : () => _betController.text = '$q',
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
      onTap: _isSpinning ? null : onTap,
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
          'RECENT SPINS',
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
                  isWin ? '${mult.toStringAsFixed(1)}x' : '0x',
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

// --- Wheel Painter ---
class _WheelCanvasPainter extends CustomPainter {
  final List<dynamic> segments;

  _WheelCanvasPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final total = segments.isNotEmpty ? segments.length : 12;
    final sweep = (2 * pi) / total;

    // Outer Rim
    final rimPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius - 3, rimPaint);

    final borderGold = Paint()
      ..color = const Color(0xFFFFD32A)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius - 6, borderGold);

    for (int i = 0; i < total; i++) {
      final startAngle = i * sweep;
      final seg = segments.isNotEmpty ? segments[i] : null;

      Color segColor;
      if (seg != null && seg['color'] != null) {
        segColor = _parseColor(seg['color'].toString());
      } else {
        segColor = i % 2 == 0 ? const Color(0xFF3867D6) : const Color(0xFFE51D35);
      }

      final slicePaint = Paint()
        ..color = segColor
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 6),
        startAngle,
        sweep,
        true,
        slicePaint,
      );

      // Slice divider line
      final dividerPaint = Paint()
        ..color = Colors.white24
        ..strokeWidth = 1.5;
      final edgeX = center.dx + (radius - 6) * cos(startAngle);
      final edgeY = center.dy + (radius - 6) * sin(startAngle);
      canvas.drawLine(center, Offset(edgeX, edgeY), dividerPaint);

      // Draw Slice Text
      final label = seg != null ? (seg['label'] ?? '0x').toString() : '${i}x';
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(startAngle + sweep / 2);

      final textSpan = TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(radius * 0.55, -textPainter.height / 2));
      canvas.restore();
    }
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF3867D6);
    }
  }

  @override
  bool shouldRepaint(covariant _WheelCanvasPainter oldDelegate) =>
      oldDelegate.segments != segments;
}

// --- Top Pointer Needle Painter ---
class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.5, h)
      ..lineTo(0, 0)
      ..lineTo(w, 0)
      ..close();

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, shadow);

    final needlePaint = Paint()..color = const Color(0xFFFFD32A);
    canvas.drawPath(path, needlePaint);

    final innerPath = Path()
      ..moveTo(w * 0.5, h - 8)
      ..lineTo(w * 0.25, 4)
      ..lineTo(w * 0.75, 4)
      ..close();
    final innerPaint = Paint()..color = Colors.white;
    canvas.drawPath(innerPath, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) => false;
}
