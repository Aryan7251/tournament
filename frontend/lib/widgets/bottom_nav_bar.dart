import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final selectedIdx = provider.selectedTabIndex;

    final navItems = [
      (
        icon: Icons.casino_outlined,
        activeIcon: Icons.casino_rounded,
        label: 'Games'
      ),
      (
        icon: Icons.add_card_outlined,
        activeIcon: Icons.add_card_rounded,
        label: 'Deposit'
      ),
      (
        icon: Icons.currency_rupee_outlined,
        activeIcon: Icons.currency_rupee_rounded,
        label: 'Withdraw'
      ),
      (
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profile'
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (idx) {
              final item = navItems[idx];
              final isSelected = selectedIdx == idx;

              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => provider.setSelectedTab(idx),
                    borderRadius: BorderRadius.circular(12),
                    splashColor: AppColors.accentAmber.withValues(alpha: 0.1),
                    highlightColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Top Active Indicator Pill
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: isSelected ? 16 : 0,
                            height: 3,
                            margin: const EdgeInsets.only(bottom: 3),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.accentAmber : Colors.transparent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Icon(
                            isSelected ? item.activeIcon : item.icon,
                            size: 22,
                            color: isSelected
                                ? AppColors.accentAmber
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
