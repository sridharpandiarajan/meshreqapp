import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'device_identity_service.dart';
import 'dtn_bundle_storage_service.dart';
import 'dtn_sync_service.dart';

class NearbyMeshService {
  /// Matches application ID in android/app/build.gradle.kts
  static const String serviceId = "com.meshresq.meshresq";
  static final Strategy meshStrategy = Strategy.P2P_CLUSTER;

  static final ValueNotifier<bool> isMeshActiveNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<int> peerCountNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<String> lastEventNotifier = ValueNotifier<String>("Mesh Initializing…");
  static final ValueNotifier<bool> isBluetoothOnNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> isLocationOnNotifier = ValueNotifier<bool>(true);

  static final Set<String> _connectedEndpoints = {};
  static final Set<String> _connectingEndpoints = {};
  static bool _isStarting = false;

  /// Checks device radios and updates notifiers
  static Future<void> checkRadios() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final btOn = await Permission.bluetooth.serviceStatus.isEnabled;
      isBluetoothOnNotifier.value = btOn;
    } catch (_) {}

    try {
      final gpsOn = await Geolocator.isLocationServiceEnabled();
      isLocationOnNotifier.value = gpsOn;
    } catch (_) {}
  }

  /// Starts dual-mode advertising & discovery for autonomous peer mesh relay
  static Future<bool> startMesh() async {
    if (_isStarting) return true;
    _isStarting = true;

    try {
      if (!kIsWeb && Platform.isAndroid) {
        // Clear any previous advertising/discovery session to avoid STATUS_ALREADY_ADVERTISING / DISCOVERING
        try {
          await Nearby().stopAdvertising();
          await Nearby().stopDiscovery();
        } catch (_) {}

        // 1. Request Location permissions (essential for BLE and P2P scanning)
        try {
          final locStatus = await Permission.locationWhenInUse.status;
          if (!locStatus.isGranted && !(await Permission.location.isGranted)) {
            final res = await Permission.locationWhenInUse.request();
            if (!res.isGranted && !(await Permission.location.isGranted)) {
              isMeshActiveNotifier.value = false;
              lastEventNotifier.value = "⚠️ Location permission needed for nearby peer scanning";
              _isStarting = false;
              return false;
            }
          }
        } catch (e) {
          debugPrint('[NearbyMesh] Location permission request error: $e');
        }

        // 2. Request Android 12+ Bluetooth permissions
        try {
          final scanStatus = await Permission.bluetoothScan.status;
          if (!scanStatus.isGranted) {
            await [
              Permission.bluetoothScan,
              Permission.bluetoothAdvertise,
              Permission.bluetoothConnect,
            ].request();
          }
        } catch (e) {
          debugPrint('[NearbyMesh] Bluetooth permissions request error: $e');
        }

        // 3. Request Android 13+ nearby wifi devices permission
        try {
          final wifiNearby = await Permission.nearbyWifiDevices.status;
          if (!wifiNearby.isGranted) {
            await Permission.nearbyWifiDevices.request();
          }
        } catch (e) {
          debugPrint('[NearbyMesh] Nearby wifi devices request error: $e');
        }

        // 4. Check hardware switches
        await checkRadios();
        if (!isBluetoothOnNotifier.value) {
          lastEventNotifier.value = "⚠️ Bluetooth is OFF. Turn ON Bluetooth to discover peers.";
        } else if (!isLocationOnNotifier.value) {
          lastEventNotifier.value = "⚠️ Location (GPS) is OFF. Turn ON Location in phone settings.";
        }
      } else {
        isMeshActiveNotifier.value = false;
        lastEventNotifier.value = "Phone-to-phone mesh is supported on Android devices";
        _isStarting = false;
        return false;
      }

      final deviceId = DeviceIdentityService.getOrCreateDeviceUUID();
      final shortId = deviceId.length >= 8 ? deviceId.substring(0, 8).toUpperCase() : deviceId.toUpperCase();
      final nickname = "NODE-$shortId";

      lastEventNotifier.value = "Starting nearby peer search…";

      // 1. Start Advertising so other phones can discover this node
      bool adStarted = false;
      String? adError;
      try {
        adStarted = await Nearby().startAdvertising(
          nickname,
          meshStrategy,
          serviceId: serviceId,
          onConnectionInitiated: (endpointId, connectionInfo) async {
            debugPrint('[NearbyMesh] Connection initiated by $endpointId (${connectionInfo.endpointName})');
            lastEventNotifier.value = "Incoming connection from ${connectionInfo.endpointName}. Accepting…";
            await _handleConnectionInitiated(endpointId);
          },
          onConnectionResult: (endpointId, status) {
            _handleConnectionResult(endpointId, status);
          },
          onDisconnected: (endpointId) {
            _handleDisconnected(endpointId);
          },
        );
      } catch (e) {
        adError = e.toString();
        debugPrint('[NearbyMesh] startAdvertising error: $e');
      }

      // 2. Start Discovery so this node can discover nearby phones
      bool disStarted = false;
      String? disError;
      try {
        disStarted = await Nearby().startDiscovery(
          nickname,
          meshStrategy,
          serviceId: serviceId,
          onEndpointFound: (endpointId, endpointName, foundServiceId) async {
            debugPrint('[NearbyMesh] Discovered peer endpoint $endpointId ($endpointName)');
            lastEventNotifier.value = "Found $endpointName. Connecting…";

            if (_connectedEndpoints.contains(endpointId) || _connectingEndpoints.contains(endpointId)) {
              debugPrint('[NearbyMesh] Already connected or handshaking with $endpointId');
              return;
            }

            _connectingEndpoints.add(endpointId);

            try {
              await Nearby().requestConnection(
                nickname,
                endpointId,
                onConnectionInitiated: (id, info) async {
                  debugPrint('[NearbyMesh] Handshake request initiated to $id (${info.endpointName})');
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
              _connectingEndpoints.remove(endpointId);
              debugPrint('[NearbyMesh] Request connection error: $e');
              lastEventNotifier.value = "Connecting to $endpointName error: $e";
            }
          },
          onEndpointLost: (endpointId) {
            debugPrint('[NearbyMesh] Endpoint lost: $endpointId');
          },
        );
      } catch (e) {
        disError = e.toString();
        debugPrint('[NearbyMesh] startDiscovery error: $e');
      }

      debugPrint('[NearbyMesh] Mesh started. Ad: $adStarted (err: $adError), Dis: $disStarted (err: $disError)');

      if (!adStarted && !disStarted) {
        await Nearby().stopAdvertising();
        await Nearby().stopDiscovery();
        isMeshActiveNotifier.value = false;
        final errText = adError ?? disError ?? "Radios unavailable";
        lastEventNotifier.value = "⚠️ P2P Failed: Turn ON Wi-Fi toggle & Bluetooth ($errText)";
        _isStarting = false;
        return false;
      }

      isMeshActiveNotifier.value = true;
      if (adStarted && disStarted) {
        lastEventNotifier.value = "Searching for nearby peers. Keep Wi-Fi toggle & Bluetooth ON.";
      } else if (adStarted) {
        lastEventNotifier.value = "Broadcasting presence. Keep Wi-Fi toggle & Bluetooth ON.";
      } else {
        lastEventNotifier.value = "Listening for nearby peers. Keep Wi-Fi toggle & Bluetooth ON.";
      }
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
      try {
        await Nearby().acceptConnection(
          endpointId,
          onPayLoadRecieved: (id, payload) {
            _handlePayloadReceived(id, payload);
          },
        );
      } catch (e) {
        debugPrint('[NearbyMesh] Error accepting connection from $endpointId: $e');
      }
    }
  }

  static void _handleConnectionResult(String endpointId, Status status) {
    _connectingEndpoints.remove(endpointId);
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
      lastEventNotifier.value = _connectedEndpoints.isEmpty
          ? "Peer connection status: ${status.name}. Searching for peers…"
          : "${_connectedEndpoints.length} phone(s) connected";
      debugPrint('[NearbyMesh] Connection to $endpointId failed with status: $status');
    }
  }

  static void _handleDisconnected(String endpointId) {
    _connectingEndpoints.remove(endpointId);
    _connectedEndpoints.remove(endpointId);
    peerCountNotifier.value = _connectedEndpoints.length;
    lastEventNotifier.value = _connectedEndpoints.isEmpty && isMeshActiveNotifier.value
        ? "Phone disconnected. Searching for nearby peers."
        : "Phone disconnected ($endpointId)";
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

    lastEventNotifier.value = "Relayed to $transmitted peer(s) over Bluetooth/Wi-Fi Direct";
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
      _connectingEndpoints.clear();
      _connectedEndpoints.clear();
      peerCountNotifier.value = 0;
      isMeshActiveNotifier.value = false;
      lastEventNotifier.value = "Mesh Radios Stopped";
    } catch (e) {
      debugPrint('[NearbyMesh] Error stopping mesh: $e');
    }
  }
}
