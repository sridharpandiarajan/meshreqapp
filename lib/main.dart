import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/services/device_identity_service.dart';
import 'core/services/firebase_auth_service.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DeviceIdentityService.init();
  await Hive.openBox('emergency_profile_box');
  await FirebaseAuthService.init();
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