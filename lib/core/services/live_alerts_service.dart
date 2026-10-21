import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'mesh_api_service.dart';

class LiveAreaAlert {
  const LiveAreaAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final int id;
  final String title;
  final String message;
  final String severity;
  final double latitude;
  final double longitude;
  final int radiusMeters;

  factory LiveAreaAlert.fromJson(Map<String, dynamic> json) {
    double readDouble(Object? value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    int readInt(Object? value) => value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 0;

    return LiveAreaAlert(
      id: readInt(json['id']),
      title: (json['title'] ?? json['alert_title'] ?? 'Emergency area alert').toString(),
      message: (json['message'] ?? '').toString(),
      severity: (json['severity'] ?? 'WARNING').toString(),
      latitude: readDouble(json['lat'] ?? json['center_latitude']),
      longitude: readDouble(json['lng'] ?? json['center_longitude']),
      radiusMeters: readInt(json['radius_m'] ?? json['radius_meters']),
    );
  }
}

/// Receives alerts while the app is in the foreground. Offline/background
/// delivery requires a push notification service and is intentionally separate.
class LiveAlertsService with WidgetsBindingObserver {
  LiveAlertsService._();

  static final LiveAlertsService instance = LiveAlertsService._();

  final StreamController<LiveAreaAlert> _alerts =
      StreamController<LiveAreaAlert>.broadcast();
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _reconnectTimer;
  Duration _retryDelay = const Duration(seconds: 3);
  bool _isRunning = false;
  bool _isConnecting = false;
  bool _isPaused = false;

  Stream<LiveAreaAlert> get alerts => _alerts.stream;

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    WidgetsBinding.instance.addObserver(this);
    await _connect();
  }

  Future<void> stop() async {
    _isRunning = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    await _closeSocket();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isPaused = false;
      unawaited(_connect());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _isPaused = true;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      unawaited(_closeSocket());
    }
  }

  Uri _webSocketUri() {
    final rawBase = MeshApiService.getBaseUrl().trim().replaceFirst(
      RegExp(r'/+$'),
      '',
    );
    final base = Uri.parse(rawBase);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/live',
      query: null,
      fragment: null,
    );
  }

  Future<void> _connect() async {
    if (!_isRunning || _isPaused || _isConnecting || _channel != null) return;
    _isConnecting = true;
    try {
      final channel = WebSocketChannel.connect(_webSocketUri());
      _channel = channel;
      await channel.ready.timeout(const Duration(seconds: 12));
      if (!_isRunning || _isPaused || !identical(_channel, channel)) {
        await channel.sink.close();
        return;
      }

      _retryDelay = const Duration(seconds: 3);
      isConnected.value = true;
      _socketSubscription = channel.stream.listen(
        _handleMessage,
        onDone: _handleDisconnect,
        onError: (_) => _handleDisconnect(),
        cancelOnError: true,
      );
    } catch (error) {
      debugPrint('[MeshReQ alerts] WebSocket connection failed: $error');
      await _closeSocket();
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void _handleMessage(dynamic rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage.toString());
      if (decoded is! Map<String, dynamic> ||
          decoded['type'] != 'BROADCAST_ALERT' ||
          decoded['data'] is! Map<String, dynamic>) {
        return;
      }
      _alerts.add(LiveAreaAlert.fromJson(decoded['data'] as Map<String, dynamic>));
    } catch (error) {
      debugPrint('[MeshReQ alerts] Ignoring invalid live event: $error');
    }
  }

  void _handleDisconnect() {
    isConnected.value = false;
    _channel = null;
    _socketSubscription = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_isRunning || _isPaused || _reconnectTimer != null) return;
    final delay = _retryDelay;
    _retryDelay = Duration(
      seconds: (_retryDelay.inSeconds * 2).clamp(3, 30),
    );
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      unawaited(_connect());
    });
  }

  Future<void> _closeSocket() async {
    final subscription = _socketSubscription;
    final channel = _channel;
    _socketSubscription = null;
    _channel = null;
    isConnected.value = false;
    await subscription?.cancel();
    await channel?.sink.close();
  }
}
