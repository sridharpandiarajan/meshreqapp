import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'device_identity_service.dart';
import 'dtn_bundle_storage_service.dart';
import 'dtn_sync_service.dart';

class NearbyMeshService {
  static const String serviceId = "org.meshresq.dtn.mesh";
  static final Strategy meshStrategy = Strategy.P2P_CLUSTER;

  static final ValueNotifier<bool> isMeshActiveNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<int> peerCountNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<String> lastEventNotifier = ValueNotifier<String>("Mesh Offline");

  static final Set<String> _connectedEndpoints = {};
  static bool _isStarting = false;

  /// Starts dual-mode advertising & discovery for autonomous peer mesh relay
  static Future<bool> startMesh() async {
    if (_isStarting || isMeshActiveNotifier.value) return true;
    _isStarting = true;

    try {
      if (!kIsWeb && Platform.isAndroid) {
        // Verify permissions
        final status = await [
          Permission.locationWhenInUse,
          Permission.bluetoothScan,
          Permission.bluetoothAdvertise,
          Permission.bluetoothConnect,
          Permission.nearbyWifiDevices,
        ].request();

        debugPrint('[NearbyMesh] Permission statuses: $status');
      }

      final deviceId = DeviceIdentityService.getOrCreateDeviceUUID();
      final nickname = "NODE-$deviceId";

      lastEventNotifier.value = "Starting BLE / P2P Mesh...";

      if (!kIsWeb && Platform.isAndroid) {
        // 1. Start Advertising so other phones can discover this node
        final adStarted = await Nearby().startAdvertising(
          nickname,
          meshStrategy,
          serviceId: serviceId,
          onConnectionInitiated: (endpointId, connectionInfo) async {
            debugPrint('[NearbyMesh] Connection initiated by $endpointId (${connectionInfo.endpointName})');
            await _handleConnectionInitiated(endpointId);
          },
          onConnectionResult: (endpointId, status) {
            _handleConnectionResult(endpointId, status);
          },
          onDisconnected: (endpointId) {
            _handleDisconnected(endpointId);
          },
        );

        // 2. Start Discovery so this node can discover nearby phones
        final disStarted = await Nearby().startDiscovery(
          nickname,
          meshStrategy,
          serviceId: serviceId,
          onEndpointFound: (endpointId, endpointName, serviceId) async {
            debugPrint('[NearbyMesh] Discovered peer endpoint $endpointId ($endpointName)');
            lastEventNotifier.value = "Discovered peer $endpointName";
            // Auto-connect to discoverable peer
            try {
              await Nearby().requestConnection(
                nickname,
                endpointId,
                onConnectionInitiated: (id, info) async {
                  await _handleConnectionInitiated(id);
                },
                onConnectionResult: (id, status) {
                  _handleConnectionResult(id, status);
                },
                onDisconnected: (id) {
                  _handleDisconnected(id);
                },
              );
            } catch (e) {
              debugPrint('[NearbyMesh] Request connection error: $e');
            }
          },
          onEndpointLost: (endpointId) {
            debugPrint('[NearbyMesh] Endpoint lost: $endpointId');
          },
        );

        debugPrint('[NearbyMesh] Mesh started. Ad: $adStarted, Dis: $disStarted');
      }

      isMeshActiveNotifier.value = true;
      lastEventNotifier.value = "P2P Cluster Active (Listening & Beacons)";
      _isStarting = false;
      return true;
    } catch (e) {
      debugPrint('[NearbyMesh] Error starting mesh: $e');
      lastEventNotifier.value = "Mesh init error: $e";
      _isStarting = false;
      return false;
    }
  }

  static Future<void> _handleConnectionInitiated(String endpointId) async {
    debugPrint('[NearbyMesh] Auto-accepting connection from $endpointId');
    if (!kIsWeb && Platform.isAndroid) {
      await Nearby().acceptConnection(
        endpointId,
        onPayLoadRecieved: (id, payload) {
          _handlePayloadReceived(id, payload);
        },
      );
    }
  }

  static void _handleConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      _connectedEndpoints.add(endpointId);
      peerCountNotifier.value = _connectedEndpoints.length;
      lastEventNotifier.value = "Connected to Peer ($endpointId)";
      debugPrint('[NearbyMesh] Peer connected: $endpointId. Total peers: ${_connectedEndpoints.length}');

      // Immediately transmit any buffered pending bundles to the newly connected peer
      _flushPendingBundlesToEndpoint(endpointId);
    } else {
      _connectedEndpoints.remove(endpointId);
      peerCountNotifier.value = _connectedEndpoints.length;
      debugPrint('[NearbyMesh] Connection to $endpointId failed with status: $status');
    }
  }

  static void _handleDisconnected(String endpointId) {
    _connectedEndpoints.remove(endpointId);
    peerCountNotifier.value = _connectedEndpoints.length;
    lastEventNotifier.value = "Peer disconnected ($endpointId)";
    debugPrint('[NearbyMesh] Peer disconnected: $endpointId. Remaining peers: ${_connectedEndpoints.length}');
  }

  static Future<void> _handlePayloadReceived(String endpointId, Payload payload) async {
    if (payload.type == PayloadType.BYTES && payload.bytes != null) {
      try {
        final rawString = utf8.decode(payload.bytes!);
        final jsonMap = jsonDecode(rawString) as Map<String, dynamic>;
        debugPrint('[NearbyMesh] Received packet from peer $endpointId: ${jsonMap['incident_uuid']}');

        final saved = await DTNBundleStorageService.saveReceivedMuleBundle(jsonMap);
        if (saved) {
          final uuid = jsonMap['payload']?['incident_uuid'] ?? jsonMap['incident_uuid'];
          final hops = jsonMap['payload']?['hop_count'] ?? jsonMap['hop_count'];
          lastEventNotifier.value = "Mule Packet Cached: $uuid ($hops hops)";

          // Attempt opportunistic cloud upload right away if this phone has internet
          DTNSyncService.syncPendingBundles();
        }
      } catch (e) {
        debugPrint('[NearbyMesh] Error processing received payload: $e');
      }
    }
  }

  /// Broadcasts an SOS packet to all connected peers in radio range
  static Future<int> broadcastPacket(Map<String, dynamic> packet) async {
    if (_connectedEndpoints.isEmpty) {
      debugPrint('[NearbyMesh] No connected peers in range to broadcast to.');
      lastEventNotifier.value = "No peers in range. Stored in DTN Mule queue.";
      return 0;
    }

    final rawBytes = Uint8List.fromList(utf8.encode(jsonEncode(packet)));
    int transmitted = 0;

    for (final endpoint in _connectedEndpoints) {
      try {
        if (!kIsWeb && Platform.isAndroid) {
          await Nearby().sendBytesPayload(endpoint, rawBytes);
          transmitted++;
        }
      } catch (e) {
        debugPrint('[NearbyMesh] Failed to send payload to $endpoint: $e');
      }
    }

    lastEventNotifier.value = "Relayed to $transmitted peer(s) over Bluetooth";
    debugPrint('[NearbyMesh] Broadcast packet sent to $transmitted peers.');
    return transmitted;
  }

  /// Transmits pending local bundles to a specific newly-connected peer
  static Future<void> _flushPendingBundlesToEndpoint(String endpointId) async {
    final pending = DTNBundleStorageService.getPendingUploadBundles();
    if (pending.isEmpty) return;

    debugPrint('[NearbyMesh] Syncing ${pending.length} pending bundle(s) to peer $endpointId...');
    for (final bundle in pending) {
      try {
        final rawBytes = Uint8List.fromList(utf8.encode(jsonEncode(bundle)));
        if (!kIsWeb && Platform.isAndroid) {
          await Nearby().sendBytesPayload(endpointId, rawBytes);
        }
      } catch (e) {
        debugPrint('[NearbyMesh] Error syncing bundle to $endpointId: $e');
      }
    }
  }

  /// Simulates a peer discovery and transmission for local testing / demo
  static Future<void> simulatePeerRelay(Map<String, dynamic> sampleSos) async {
    lastEventNotifier.value = "SIM: Peer Ingesting SOS via BLE...";
    await Future.delayed(const Duration(milliseconds: 600));
    await DTNBundleStorageService.saveReceivedMuleBundle(sampleSos);
    lastEventNotifier.value = "SIM: Packet Saved in Mule Buffer! Triggering Cloud Sync...";
    await DTNSyncService.syncPendingBundles();
  }

  /// Stops all mesh radios and clears connections
  static Future<void> stopMesh() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        await Nearby().stopAdvertising();
        await Nearby().stopDiscovery();
        await Nearby().stopAllEndpoints();
      }
      _connectedEndpoints.clear();
      peerCountNotifier.value = 0;
      isMeshActiveNotifier.value = false;
      lastEventNotifier.value = "Mesh Radios Stopped";
    } catch (e) {
      debugPrint('[NearbyMesh] Error stopping mesh: $e');
    }
  }
}
