import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/services/device_identity_service.dart';
import 'core/services/firebase_auth_service.dart';
import 'core/services/dtn_bundle_storage_service.dart';
import 'core/services/dtn_sync_service.dart';
import 'core/services/live_alerts_service.dart';
import 'core/services/firebase_push_service.dart';
import 'core/theme/app_color.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DeviceIdentityService.init();
  await Hive.openBox('emergency_profile_box');
  await Hive.openBox('broadcasts_cache_box');
  await DTNBundleStorageService.init();
  await FirebaseAuthService.init();
  await FirebasePushService.registerBackgroundHandler();
  DTNSyncService.startPeriodicSync();
  runApp(const MeshReQApp());
}

class MeshReQApp extends StatefulWidget {
  const MeshReQApp({super.key});

  @override
  State<MeshReQApp> createState() => _MeshReQAppState();
}

class _MeshReQAppState extends State<MeshReQApp> {
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final StreamSubscription<LiveAreaAlert> _alertSubscription;
  late final StreamSubscription<LiveAreaAlert> _pushSubscription;
  final Set<int> _shownAlertIds = <int>{};

  @override
  void initState() {
    super.initState();
    _alertSubscription = LiveAlertsService.instance.alerts.listen(_showAlert);
    _pushSubscription = FirebasePushService.instance.alerts.listen(_showAlert);
    unawaited(LiveAlertsService.instance.start());
  }

  @override
  void dispose() {
    unawaited(_alertSubscription.cancel());
    unawaited(_pushSubscription.cancel());
    unawaited(LiveAlertsService.instance.stop());
    unawaited(FirebasePushService.instance.stop());
    super.dispose();
  }

  void _showAlert(LiveAreaAlert alert) {
    if (alert.id != 0 && !_shownAlertIds.add(alert.id)) return;
    final color = switch (alert.severity.toUpperCase()) {
      'FLASH_URGENT' => AppColors.distress,
      'ALL_CLEAR' => AppColors.oliveDim,
      'ADVISORY' => AppColors.amberDim,
      _ => AppColors.distressDim,
    };
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 10),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'AREA ALERT · ${alert.severity.replaceAll('_', ' ')}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(alert.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(alert.message, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
          action: SnackBarAction(
            label: 'VIEW',
            textColor: Colors.white,
            onPressed: () => _showAlertDetails(alert),
          ),
        ),
      );
  }

  void _showAlertDetails(LiveAreaAlert alert) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(alert.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert.severity.replaceAll('_', ' ')),
            const SizedBox(height: 12),
            Text(alert.message),
            const SizedBox(height: 12),
            Text(
              'Alert area: ${alert.latitude.toStringAsFixed(4)}, '
              '${alert.longitude.toStringAsFixed(4)} · '
              '${(alert.radiusMeters / 1000).toStringAsFixed(1)} km radius',
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeshReQ',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      theme: AppTheme.darkTheme,
      // No light theme exists yet -- every screen is hand-themed for
      // the dark rugged-hardware palette, so the app is pinned to dark
      // rather than following ThemeMode.system.
      themeMode: ThemeMode.dark,
      home: const SplashPage(),
    );
  }
}
