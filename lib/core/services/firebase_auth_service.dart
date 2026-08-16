import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'device_identity_service.dart';

/// Hybrid Offline-First Firebase Authentication Service for MeshResQ.
/// 
/// In emergency/disaster scenarios, connectivity may be completely offline.
/// This service allows full Firebase cloud auth when online, while persisting 
/// the authenticated session in Hive and offering an instant Emergency Bypass.
class FirebaseAuthService {
  static const String _boxName = 'auth_session_box';
  static bool _firebaseInitialized = false;

  static Future<void> init() async {
    try {
      await Hive.openBox(_boxName);
    } catch (e) {
      debugPrint("Hive auth box init error: $e");
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _firebaseInitialized = true;
    } catch (e) {
      // Firebase may not have google-services.json configured in offline/demo mode.
      debugPrint("Firebase init note: Running in offline-first resilient mode ($e)");
      _firebaseInitialized = false;
    }
  }

  static Box get _box => Hive.box(_boxName);

  static bool get isAuthenticated {
    if (_firebaseInitialized && FirebaseAuth.instance.currentUser != null) {
      return true;
    }
    return _box.get('is_authenticated', defaultValue: false);
  }

  static bool get isEmergencyBypass {
    return _box.get('is_emergency_bypass', defaultValue: false);
  }

  static String get currentUserEmail {
    if (_firebaseInitialized && FirebaseAuth.instance.currentUser?.email != null) {
      return FirebaseAuth.instance.currentUser!.email!;
    }
    return _box.get('email', defaultValue: '');
  }

  static String get currentUserDisplayName {
    if (_firebaseInitialized && FirebaseAuth.instance.currentUser?.displayName != null) {
      return FirebaseAuth.instance.currentUser!.displayName!;
    }
    return _box.get('display_name', defaultValue: '');
  }

  static String get currentUserId {
    if (_firebaseInitialized && FirebaseAuth.instance.currentUser != null) {
      return FirebaseAuth.instance.currentUser!.uid;
    }
    return _box.get('uid', defaultValue: DeviceIdentityService.getOrCreateDeviceUUID());
  }

  /// Sign In with Email and Password
  static Future<Map<String, dynamic>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      if (_firebaseInitialized) {
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );

        final user = credential.user;
        await _box.put('is_authenticated', true);
        await _box.put('is_emergency_bypass', false);
        await _box.put('email', user?.email ?? email.trim());
        await _box.put('display_name', user?.displayName ?? '');
        await _box.put('uid', user?.uid ?? DeviceIdentityService.getOrCreateDeviceUUID());

        return {'success': true, 'user': user};
      } else {
        // Offline / Resilient Local Authentication
        await _box.put('is_authenticated', true);
        await _box.put('is_emergency_bypass', false);
        await _box.put('email', email.trim());
        await _box.put('display_name', email.split('@').first);
        await _box.put('uid', DeviceIdentityService.getOrCreateDeviceUUID());

        return {'success': true, 'message': 'Authenticated in local resilient mode'};
      }
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': e.message ?? 'Authentication failed'};
    } catch (e) {
      // Fallback for offline mode
      await _box.put('is_authenticated', true);
      await _box.put('is_emergency_bypass', false);
      await _box.put('email', email.trim());
      await _box.put('uid', DeviceIdentityService.getOrCreateDeviceUUID());
      return {'success': true, 'message': 'Authenticated offline'};
    }
  }

  /// Register Citizen / Student / Responder Account
  static Future<Map<String, dynamic>> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      if (_firebaseInitialized) {
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );

        final user = credential.user;
        if (user != null && displayName.isNotEmpty) {
          await user.updateDisplayName(displayName.trim());
        }

        await _box.put('is_authenticated', true);
        await _box.put('is_emergency_bypass', false);
        await _box.put('email', user?.email ?? email.trim());
        await _box.put('display_name', displayName.trim());
        await _box.put('uid', user?.uid ?? DeviceIdentityService.getOrCreateDeviceUUID());

        return {'success': true, 'user': user};
      } else {
        // Offline / Resilient Local Registration
        await _box.put('is_authenticated', true);
        await _box.put('is_emergency_bypass', false);
        await _box.put('email', email.trim());
        await _box.put('display_name', displayName.trim());
        await _box.put('uid', DeviceIdentityService.getOrCreateDeviceUUID());

        return {'success': true, 'message': 'Account registered locally'};
      }
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': e.message ?? 'Registration failed'};
    } catch (e) {
      await _box.put('is_authenticated', true);
      await _box.put('is_emergency_bypass', false);
      await _box.put('email', email.trim());
      await _box.put('display_name', displayName.trim());
      await _box.put('uid', DeviceIdentityService.getOrCreateDeviceUUID());
      return {'success': true, 'message': 'Registered in offline mode'};
    }
  }

  /// Fast Emergency Bypass: Never block SOS transmitter in active disaster
  static Future<void> emergencyBypass() async {
    await _box.put('is_authenticated', true);
    await _box.put('is_emergency_bypass', true);
    await _box.put('email', 'emergency-guest@meshresq.local');
    await _box.put('display_name', 'Emergency Citizen Beacon');
    await _box.put('uid', DeviceIdentityService.getOrCreateDeviceUUID());
  }

  /// Sign Out and Clear Session
  static Future<void> signOut() async {
    try {
      if (_firebaseInitialized) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (_) {}
    await _box.put('is_authenticated', false);
    await _box.put('is_emergency_bypass', false);
    await _box.delete('email');
    await _box.delete('display_name');
  }
}
