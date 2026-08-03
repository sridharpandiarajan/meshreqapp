import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/splash_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MeshResQApp());
}

class MeshResQApp extends StatelessWidget {
  const MeshResQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeshResQ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      // No light theme exists yet -- every screen is hand-themed for
      // the dark rugged-hardware palette, so the app is pinned to dark
      // rather than following ThemeMode.system.
      themeMode: ThemeMode.dark,
      home: const SplashPage(),
    );
  }
}