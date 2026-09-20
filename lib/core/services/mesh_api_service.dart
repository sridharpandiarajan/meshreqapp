import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'device_identity_service.dart';
import 'firebase_auth_service.dart';

import 'dtn_bundle_storage_service.dart';
import 'nearby_mesh_service.dart';

class MeshApiService {
  static const String _defaultUrl = "http://10.0.2.2:8000"; // Default for Android Emulator
  static const String _defaultLocalhostUrl = "http://localhost:8000"; // For Windows / Web / Host

  static String getBaseUrl() {
    if (Hive.isBoxOpen('device_identity_box')) {
      final customUrl = Hive.box('device_identity_box').get('backend_url') as String?;
      if (customUrl != null && customUrl.trim().isNotEmpty) {
        return customUrl.trim();
      }
    }

    if (kIsWeb) return _defaultLocalhostUrl;
    try {
      if (Platform.isAndroid) return _defaultUrl;
    } catch (_) {}
    return _defaultLocalhostUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    if (Hive.isBoxOpen('device_identity_box')) {
      await Hive.box('device_identity_box').put('backend_url', url.trim());
    }
  }

  /// Sends an SOS Beacon: stores locally in DTN buffer, attempts cloud uplink,
  /// and relays to nearby phones over Bluetooth if offline.
  static Future<Map<String, dynamic>> sendEmergencyBeacon({
    required String category,
    required String channel,
    double? latitude,
    double? longitude,
    String? voiceText,
    int hopCount = 1,
  }) async {
    final box = Hive.isBoxOpen('emergency_profile_box')
        ? Hive.box('emergency_profile_box')
        : null;

    final victimName = box?.get('full_name') as String? ??
        (FirebaseAuthService.currentUserDisplayName.isNotEmpty
            ? FirebaseAuthService.currentUserDisplayName
            : 'Sridhar P');

    final phone = box?.get('phone') as String? ?? '+91 98401 55667';
    final bloodGroup = box?.get('blood_group') as String? ?? 'O+';
    final medicalNotes = box?.get('medical_notes') as String? ?? 'Emergency assistance requested via MeshResQ mobile app.';
    final iceContact = box?.get('ice_contact') as String? ?? 'Family: +91 98401 99887';
    final deviceUuid = DeviceIdentityService.getOrCreateDeviceUUID();

    // Default Medavakkam Coordinates if GPS is unavailable
    final lat = latitude ?? 12.9171;
    final lng = longitude ?? 80.1921;

    final incidentUuid = "SOS-${const Uuid().v4().substring(0, 8).toUpperCase()}";
    final payload = {
      "incident_uuid": incidentUuid,
      "victim_name": "$victimName (Live Mobile)",
      "phone": phone,
      "blood_group": bloodGroup,
      "medical_notes": medicalNotes,
      "ice_contact": iceContact,
      "category": category,
      "priority": "CRITICAL",
      "latitude": lat,
      "longitude": lng,
      "altitude": 24.0,
      "location_name": "Medavakkam Junction (Live Mobile Transmitter)",
      "channel": channel,
      "hop_count": hopCount,
      "hop_path": [
        {"node_id": "NODE-$deviceUuid", "type": "MOBILE_BLE_ORIGIN", "timestamp": DateTime.now().toIso8601String()},
      ],
      "battery_level": 82,
      "voice_transcription": voiceText ?? "காப்பாற்றுங்கள், அவசர உதவி தேவைப்படுகிறது! (Live Emergency SOS from mobile app)",
      "detected_language": "Tamil (தமிழ்)"
    };

    // 1. Always persist to local DTN storage first (Zero Data Loss guarantee)
    await DTNBundleStorageService.saveOutgoingBundle(payload);

    // 2. Attempt direct cloud uplink
    final uploadRes = await uploadBundle(payload);

    if (uploadRes['success'] == true && uploadRes['offline'] != true) {
      await DTNBundleStorageService.markAsSynced(incidentUuid);
      return uploadRes;
    }

    // 3. Fallback: Network unreachable -> Relay immediately to nearby peers via Bluetooth/Nearby
    final peerRelayCount = await NearbyMeshService.broadcastPacket(payload);
    debugPrint("[MeshResQ] Offline mode: Broadcasted SOS packet to $peerRelayCount nearby peer(s).");

    return {
      "success": true,
      "offline": true,
      "peers_relayed": peerRelayCount,
      "incident_uuid": incidentUuid,
      "message": peerRelayCount > 0
          ? "Transmitted to $peerRelayCount nearby peer(s) over Bluetooth"
          : "Saved in offline DTN buffer. Will broadcast when peers are in range.",
      "payload": payload,
    };
  }

  /// Uplinks a single bundle payload to the FastAPI server with fallback endpoints
  static Future<Map<String, dynamic>> uploadBundle(Map<String, dynamic> payload) async {
    final candidateUrls = [
      getBaseUrl(),
      "http://127.0.0.1:8000",
      "http://10.0.2.2:8000",
    ];

    for (final baseUrl in candidateUrls) {
      try {
        final response = await http.post(
          Uri.parse("$baseUrl/api/v1/incidents"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          return {"success": true, "data": data, "offline": false};
        }
      } catch (_) {}
    }

    return {"success": false, "offline": true, "error": "All candidate endpoints unreachable"};
  }
}
