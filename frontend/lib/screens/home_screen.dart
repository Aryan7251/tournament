import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav_bar.dart';
import 'games_screen.dart';
import 'deposit_screen.dart';
import 'withdraw_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currentTab = provider.selectedTabIndex;

    final screens = const [
      GamesScreen(),
      DepositScreen(),
      WithdrawScreen(),
      ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: IndexedStack(
            index: currentTab.clamp(0, screens.length - 1),
            children: screens,
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}
