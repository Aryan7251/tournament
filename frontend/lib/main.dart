import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/connectivity_service.dart';
import 'theme/app_theme.dart';
import 'widgets/connectivity_banner.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ConnectivityService().initialize();
  runApp(const TournamentApp());
}

class TournamentApp extends StatelessWidget {
  const TournamentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        title: 'LuckyWin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        builder: (context, child) {
          return ConnectivityWrapper(
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const _AppRoot(),
      ),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    return provider.isLoggedIn ? const HomeScreen() : const AuthScreen();
  }
}

