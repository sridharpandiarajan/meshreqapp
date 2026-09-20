import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dtn_bundle_storage_service.dart';
import 'mesh_api_service.dart';

class DTNSyncService {
  static Timer? _syncTimer;
  static bool _isSyncing = false;
  static final ValueNotifier<String> syncStatusNotifier = ValueNotifier<String>("Idle");
  static final ValueNotifier<DateTime?> lastSyncTimeNotifier = ValueNotifier<DateTime?>(null);

  /// Starts periodic background synchronization worker
  static void startPeriodicSync({Duration interval = const Duration(seconds: 12)}) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) => syncPendingBundles());
    debugPrint('[DTN Sync] Background sync worker started (interval: ${interval.inSeconds}s)');
  }

  /// Stops background worker
  static void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Flushes all pending bundles in local DTN storage to the FastAPI cloud backend
  static Future<int> syncPendingBundles() async {
    if (_isSyncing) return 0;
    _isSyncing = true;

    try {
      final pendingBundles = DTNBundleStorageService.getPendingUploadBundles();
      if (pendingBundles.isEmpty) {
        _isSyncing = false;
        return 0;
      }

      syncStatusNotifier.value = "Uplinking ${pendingBundles.length} packet(s)...";
      debugPrint('[DTN Sync] Attempting to upload ${pendingBundles.length} pending DTN packet(s)...');

      int syncedCount = 0;
      for (final bundle in pendingBundles) {
        final payload = Map<String, dynamic>.from(bundle['payload'] ?? bundle);
        final uuid = payload['incident_uuid'] as String?;
        if (uuid == null) continue;

        // Attempt HTTP upload to FastAPI backend
        final result = await MeshApiService.uploadBundle(payload);
        if (result['success'] == true && result['offline'] != true) {
          await DTNBundleStorageService.markAsSynced(uuid);
          syncedCount++;
          debugPrint('[DTN Sync] Successfully uploaded packet to cloud: $uuid (Hops: ${payload['hop_count']})');
        } else {
          debugPrint('[DTN Sync] Backend not reachable for $uuid, keeping in offline DTN buffer.');
        }
      }

      if (syncedCount > 0) {
        lastSyncTimeNotifier.value = DateTime.now();
        syncStatusNotifier.value = "Uploaded $syncedCount packet(s) to Cloud";
      } else {
        syncStatusNotifier.value = "Cloud unreachable (Bundles safe offline)";
      }

      _isSyncing = false;
      return syncedCount;
    } catch (e) {
      debugPrint('[DTN Sync] Error syncing bundles: $e');
      syncStatusNotifier.value = "Sync error: $e";
      _isSyncing = false;
      return 0;
    }
  }
}
