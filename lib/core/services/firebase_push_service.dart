import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'live_alerts_service.dart';

const String areaAlertsTopic = 'meshresq_area_alerts';

@pragma('vm:entry-point')
Future<void> meshResQFirebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Subscribes this app installation to command-wide FCM area alerts.
class FirebasePushService {
  FirebasePushService._();

  static final FirebasePushService instance = FirebasePushService._();

  final StreamController<LiveAreaAlert> _alerts =
      StreamController<LiveAreaAlert>.broadcast();
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  bool _started = false;
  bool _starting = false;

  Stream<LiveAreaAlert> get alerts => _alerts.stream;

  static Future<void> registerBackgroundHandler() async {
    if (Firebase.apps.isEmpty) return;
    FirebaseMessaging.onBackgroundMessage(
      meshResQFirebaseBackgroundHandler,
    );
  }

  Future<void> start() async {
    if (_started || _starting || Firebase.apps.isEmpty) return;
    _starting = true;
    try {
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final allowed =
          permission.authorizationStatus == AuthorizationStatus.authorized ||
              permission.authorizationStatus == AuthorizationStatus.provisional;
      if (!allowed) {
        debugPrint('[MeshReQ push] Notification permission was not granted.');
        _started = true;
        return;
      }

      await messaging.subscribeToTopic(areaAlertsTopic);
      _tokenSubscription = messaging.onTokenRefresh.listen((_) {
        unawaited(_subscribeAgain(messaging));
      });
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(_publish);
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_publish);

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) _publish(initialMessage);

      _started = true;
      debugPrint('[MeshReQ push] Subscribed to area alerts.');
    } catch (error) {
      debugPrint('[MeshReQ push] Could not initialize notifications: $error');
    } finally {
      _starting = false;
    }
  }

  Future<void> stop() async {
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    _tokenSubscription = null;
    _foregroundSubscription = null;
    _openedSubscription = null;
    _started = false;
  }

  Future<void> _subscribeAgain(FirebaseMessaging messaging) async {
    try {
      await messaging.subscribeToTopic(areaAlertsTopic);
    } catch (error) {
      debugPrint('[MeshReQ push] Topic resubscription failed: $error');
    }
  }

  void _publish(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    final notification = message.notification;
    if (notification?.title != null) {
      data.putIfAbsent('title', () => notification!.title!);
    }
    if (notification?.body != null) {
      data.putIfAbsent('message', () => notification!.body!);
    }
    _alerts.add(LiveAreaAlert.fromJson(data));
  }
}
