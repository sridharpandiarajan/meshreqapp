import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'device_identity_service.dart';

enum BundleSyncStatus {
  pendingRelay,   // Created on this device, waiting to send over mesh or upload
  storedMule,     // Received from another phone over BLE, stored locally to mule
  syncedToCloud,  // Successfully received by FastAPI cloud backend
}

class DTNBundleStorageService {
  static const String boxName = 'dtn_bundles_box';
  static final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> totalStoredNotifier = ValueNotifier<int>(0);

  static Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }
    _updateNotifiers();
  }

  static Box get _box => Hive.box(boxName);

  static void _updateNotifiers() {
    if (!Hive.isBoxOpen(boxName)) return;
    final all = _box.values.toList();
    totalStoredNotifier.value = all.length;
    final pending = all.where((item) {
      final map = _toMap(item);
      return map['sync_status'] != BundleSyncStatus.syncedToCloud.name;
    }).length;
    pendingCountNotifier.value = pending;
  }

  static Map<String, dynamic> _toMap(dynamic item) {
    if (item is Map) {
      return Map<String, dynamic>.from(item);
    }
    if (item is String) {
      try {
        return jsonDecode(item);
      } catch (_) {}
    }
    return {};
  }

  /// Saves an SOS bundle originated on this device
  static Future<void> saveOutgoingBundle(Map<String, dynamic> payload) async {
    await init();
    final uuid = payload['incident_uuid'] as String? ?? 'SOS-${DateTime.now().millisecondsSinceEpoch}';
    final bundle = {
      'incident_uuid': uuid,
      'payload': payload,
      'hop_count': payload['hop_count'] ?? 1,
      'hop_path': payload['hop_path'] ?? [],
      'sync_status': BundleSyncStatus.pendingRelay.name,
      'created_at': DateTime.now().toIso8601String(),
      'origin_device': DeviceIdentityService.getOrCreateDeviceUUID(),
      'is_local_origin': true,
    };

    await _box.put(uuid, bundle);
    _updateNotifiers();
    debugPrint('[DTN Storage] Outgoing SOS saved to local buffer: $uuid');
  }

  /// Saves a bundle received from another mobile via Bluetooth / Nearby P2P
  static Future<bool> saveReceivedMuleBundle(Map<String, dynamic> incomingPacket) async {
    await init();
    final payload = Map<String, dynamic>.from(incomingPacket['payload'] ?? incomingPacket);
    final uuid = payload['incident_uuid'] as String?;
    if (uuid == null || uuid.isEmpty) return false;

    final myDeviceId = DeviceIdentityService.getOrCreateDeviceUUID();
    final existingRaw = _box.get(uuid);

    int incomingHopCount = (payload['hop_count'] is int) ? payload['hop_count'] as int : 1;
    List<dynamic> incomingHopPath = (payload['hop_path'] is List) ? List.from(payload['hop_path']) : [];

    // Append this node as a Data Mule in the hop path
    final myHopRecord = {
      'node_id': 'NODE-$myDeviceId',
      'type': 'PEER_BLE_MULE',
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Prevent duplicate entries of the same device in immediate succession
    final alreadyContainsMyHop = incomingHopPath.any((h) => h is Map && h['node_id'] == 'NODE-$myDeviceId');
    if (!alreadyContainsMyHop) {
      incomingHopPath.add(myHopRecord);
      incomingHopCount += 1;
    }

    payload['hop_count'] = incomingHopCount;
    payload['hop_path'] = incomingHopPath;

    if (existingRaw != null) {
      final existing = _toMap(existingRaw);
      final existingHops = (existing['hop_path'] is List) ? (existing['hop_path'] as List).length : 0;
      if (incomingHopPath.length > existingHops) {
        existing['hop_path'] = incomingHopPath;
        existing['hop_count'] = incomingHopCount;
        existing['payload'] = payload;
        await _box.put(uuid, existing);
        _updateNotifiers();
        debugPrint('[DTN Storage] Updated hop path for existing mule bundle: $uuid (Hops: $incomingHopCount)');
        return true;
      }
      return false; // Already stored with equal or better hop information
    }

    final bundle = {
      'incident_uuid': uuid,
      'payload': payload,
      'hop_count': incomingHopCount,
      'hop_path': incomingHopPath,
      'sync_status': BundleSyncStatus.storedMule.name,
      'created_at': DateTime.now().toIso8601String(),
      'origin_device': incomingPacket['origin_device'] ?? 'REMOTE_PEER',
      'is_local_origin': false,
    };

    await _box.put(uuid, bundle);
    _updateNotifiers();
    debugPrint('[DTN Storage] Stored NEW mule bundle from peer: $uuid (Hops: $incomingHopCount)');
    return true;
  }

  /// Returns all bundles that need to be uploaded to cloud
  static List<Map<String, dynamic>> getPendingUploadBundles() {
    if (!Hive.isBoxOpen(boxName)) return [];
    return _box.values
        .map((item) => _toMap(item))
        .where((b) => b['sync_status'] != BundleSyncStatus.syncedToCloud.name)
        .toList();
  }

  /// Marks a bundle as successfully uploaded to the backend
  static Future<void> markAsSynced(String incidentUuid) async {
    if (!Hive.isBoxOpen(boxName)) return;
    final item = _box.get(incidentUuid);
    if (item != null) {
      final map = _toMap(item);
      map['sync_status'] = BundleSyncStatus.syncedToCloud.name;
      map['synced_at'] = DateTime.now().toIso8601String();
      await _box.put(incidentUuid, map);
      _updateNotifiers();
      debugPrint('[DTN Storage] Bundle $incidentUuid marked as SYNCED_TO_CLOUD');
    }
  }

  /// Returns all stored bundles
  static List<Map<String, dynamic>> getAllBundles() {
    if (!Hive.isBoxOpen(boxName)) return [];
    return _box.values.map((item) => _toMap(item)).toList();
  }
}
