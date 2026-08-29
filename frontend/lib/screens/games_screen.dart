import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/game_thumbnail.dart';
import 'aviator_screen.dart';
import 'mines_screen.dart';
import 'lucky_wheel_screen.dart';
import 'cyber_dice_screen.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  String _selectedCategory = 'ALL';

  final List<({String id, String label, IconData icon})> _categories = [
    (id: 'ALL', label: 'All Games', icon: Icons.grid_view_rounded),
    (id: 'CRASH', label: 'Crash Games', icon: Icons.flight_takeoff),
    (id: 'CASINO', label: 'Quick Win', icon: Icons.casino),
    (id: 'CARDS', label: 'Card Games', icon: Icons.style),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final wallet = provider.wallet;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Featured Banner: Aviator with Animated Thumbnail & Play CTA
          _buildFeaturedAviatorBanner(context, wallet.totalBalance),
          const SizedBox(height: 20),

          // Categories Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(
                      cat.icon,
                      size: 16,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                    label: Text(cat.label),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategory = cat.id),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Instant Play Lobby',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.circle, color: AppColors.accentGreen, size: 6),
                    SizedBox(width: 4),
                    Text(
                      'Live 24/7',
                      style: TextStyle(
                        color: AppColors.accentGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Games Grid with Custom Visual Thumbnails
          _buildGamesGrid(context),
        ],
      ),
    );
  }

  Widget _buildFeaturedAviatorBanner(BuildContext context, int balance) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8E0E00), Color(0xFF1F1C18), Color(0xFF0F141C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE51D35).withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE51D35).withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE51D35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'HOT CRASH GAME',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.volume_up, color: Color(0xFFFFD32A), size: 13),
                    SizedBox(width: 4),
                    Text(
                      'Audio FX Included',
                      style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Thumbnail & Description Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Large Thumbnail Box
              const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                child: SizedBox(
                  width: 110,
                  height: 85,
                  child: GameThumbnail(type: GameThumbnailType.aviator, height: 85, width: 110),
                ),
              ),
              const SizedBox(width: 14),

              // Title and Pitch
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'AVIATOR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Cash out up to 100x multiplier before the plane flies away!',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Play CTA Button
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AviatorScreen()),
                    );
                  },
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: const Text(
                    'PLAY AVIATOR NOW',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE51D35),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGamesGrid(BuildContext context) {
    final allGames = [
      (
        title: 'Aviator',
        category: 'Crash & Multiplier',
        categoryGroup: 'CRASH',
        tag: 'LIVE',
        tagColor: const Color(0xFFE51D35),
        btnColor: const Color(0xFFE51D35),
        type: GameThumbnailType.aviator,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AviatorScreen()),
          );
        },
        isAvailable: true,
      ),
      (
        title: 'Mines Gold',
        category: 'Grid Diamonds',
        categoryGroup: 'CASINO',
        tag: 'HOT',
        tagColor: const Color(0xFF00D2D3),
        btnColor: const Color(0xFF00D2D3),
        type: GameThumbnailType.mines,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MinesScreen()),
          );
        },
        isAvailable: true,
      ),
      (
        title: 'Lucky Wheel',
        category: 'Spin & Win',
        categoryGroup: 'CASINO',
        tag: 'POPULAR',
        tagColor: const Color(0xFFFF9F1A),
        btnColor: const Color(0xFFFF9F1A),
        type: GameThumbnailType.wheel,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LuckyWheelScreen()),
          );
        },
        isAvailable: true,
      ),
      (
        title: 'Cyber Dice',
        category: 'High / Low & Target',
        categoryGroup: 'CASINO',
        tag: 'HOT',
        tagColor: const Color(0xFF9C88FF),
        btnColor: const Color(0xFF9C88FF),
        type: GameThumbnailType.dice,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CyberDiceScreen()),
          );
        },
        isAvailable: true,
      ),
      (
        title: 'Plinko Drop',
        category: 'Pyramid Bounce',
        categoryGroup: 'CASINO',
        tag: 'SOON',
        tagColor: const Color(0xFF2ED573),
        btnColor: const Color(0xFF2ED573),
        type: GameThumbnailType.plinko,
        onTap: () {},
        isAvailable: false,
      ),
      (
        title: 'Dragon Tiger',
        category: 'Card Clash',
        categoryGroup: 'CARDS',
        tag: 'SOON',
        tagColor: const Color(0xFFFF4757),
        btnColor: const Color(0xFFFF4757),
        type: GameThumbnailType.dragonTiger,
        onTap: () {},
        isAvailable: false,
      ),
      (
        title: 'Penalty Shot',
        category: 'Spot Kick',
        categoryGroup: 'CASINO',
        tag: 'SOON',
        tagColor: const Color(0xFF20BF6B),
        btnColor: const Color(0xFF20BF6B),
        type: GameThumbnailType.penalty,
        onTap: () {},
        isAvailable: false,
      ),
      (
        title: 'JetX Space',
        category: 'Space Rocket',
        categoryGroup: 'CRASH',
        tag: 'SOON',
        tagColor: const Color(0xFF3867D6),
        btnColor: const Color(0xFF3867D6),
        type: GameThumbnailType.jetX,
        onTap: () {},
        isAvailable: false,
      ),
    ];

    final filtered = allGames.where((g) {
      if (_selectedCategory == 'ALL') return true;
      return g.categoryGroup == _selectedCategory;
    }).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.76,
      ),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final g = filtered[i];
        return InkWell(
          onTap: g.isAvailable ? g.onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: g.isAvailable ? g.tagColor.withValues(alpha: 0.4) : AppColors.border,
                width: g.isAvailable ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Visual Graphical Game Thumbnail Header
                Stack(
                  children: [
                    GameThumbnail(
                      type: g.type,
                      height: 105,
                      width: double.infinity,
                    ),

                    // Top Badge / Tag
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: g.tagColor,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          g.tag,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                    // Sound FX Indicator
                    if (g.isAvailable)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.volume_up, size: 12, color: AppColors.accentAmber),
                        ),
                      ),
                  ],
                ),

                // 2. Details & Action Button
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        g.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Button
                      SizedBox(
                        width: double.infinity,
                        height: 32,
                        child: ElevatedButton(
                          onPressed: g.isAvailable ? g.onTap : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: g.isAvailable ? g.btnColor : AppColors.surfaceElevated,
                            foregroundColor: g.isAvailable ? Colors.white : AppColors.textMuted,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: g.isAvailable ? 2 : 0,
                          ),
                          child: Text(
                            g.isAvailable ? 'PLAY' : 'COMING SOON',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
