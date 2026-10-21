import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../core/services/mesh_api_service.dart';
import '../../../core/theme/app_color.dart';
import '../../../core/theme/bevel.dart';

class _BroadcastNotice {
  const _BroadcastNotice({
    required this.title,
    required this.message,
    required this.severity,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.channels,
    required this.createdAt,
  });

  final String title;
  final String message;
  final String severity;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final List<String> channels;
  final DateTime? createdAt;

  factory _BroadcastNotice.fromJson(Map<String, dynamic> json) {
    double asDouble(Object? value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    int asInt(Object? value) => value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 0;

    final rawChannels = json['target_channels'];
    return _BroadcastNotice(
      title: (json['alert_title'] ?? json['title'] ?? 'Area alert').toString(),
      message: (json['message'] ?? '').toString(),
      severity: (json['severity'] ?? 'WARNING').toString(),
      latitude: asDouble(json['center_latitude'] ?? json['lat']),
      longitude: asDouble(json['center_longitude'] ?? json['lng']),
      radiusMeters: asInt(json['radius_meters'] ?? json['radius_m']),
      channels: rawChannels is List
          ? rawChannels.map((channel) => channel.toString()).toList()
          : const [],
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }
}

class _BroadcastsResult {
  const _BroadcastsResult(this.notices, {this.isOffline = false});

  final List<_BroadcastNotice> notices;
  final bool isOffline;
}

class BroadcastsPage extends StatefulWidget {
  const BroadcastsPage({super.key});

  @override
  State<BroadcastsPage> createState() => _BroadcastsPageState();
}

class _BroadcastsPageState extends State<BroadcastsPage> {
  static const String _cacheBoxName = 'broadcasts_cache_box';
  static const String _cacheKey = 'cached_broadcasts_json';

  late Future<_BroadcastsResult> _notices;

  @override
  void initState() {
    super.initState();
    _notices = _loadNotices();
  }

  Future<_BroadcastsResult> _loadNotices() async {
    Box cacheBox;
    if (Hive.isBoxOpen(_cacheBoxName)) {
      cacheBox = Hive.box(_cacheBoxName);
    } else {
      cacheBox = await Hive.openBox(_cacheBoxName);
    }

    try {
      final uri = Uri.parse('${MeshApiService.getBaseUrl()}/api/v1/broadcasts');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          await cacheBox.put(_cacheKey, response.body);
          final notices = decoded
              .whereType<Map<String, dynamic>>()
              .map(_BroadcastNotice.fromJson)
              .toList();
          return _BroadcastsResult(notices, isOffline: false);
        }
      }
      throw Exception('Server returned ${response.statusCode}');
    } catch (e) {
      final cachedJson = cacheBox.get(_cacheKey) as String?;
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedJson);
          if (decoded is List) {
            final notices = decoded
                .whereType<Map<String, dynamic>>()
                .map(_BroadcastNotice.fromJson)
                .toList();
            return _BroadcastsResult(notices, isOffline: true);
          }
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> _refresh() async {
    final next = _loadNotices();
    setState(() => _notices = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'AREA BROADCASTS',
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 1,
            fontWeight: FontWeight.w700,
            fontFamily: 'Courier',
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh broadcasts',
            onPressed: () => _refresh(),
            icon: const Icon(Icons.refresh, color: AppColors.olive),
          ),
        ],
      ),
      body: FutureBuilder<_BroadcastsResult>(
        future: _notices,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.olive),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      color: AppColors.amber,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Could not load broadcasts',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.olive,
                        foregroundColor: AppColors.bg,
                      ),
                      onPressed: () =>
                          setState(() => _notices = _loadNotices()),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('TRY AGAIN'),
                    ),
                  ],
                ),
              ),
            );
          }

          final result = snapshot.data ?? const _BroadcastsResult([]);
          final notices = result.notices;

          if (notices.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none,
                      color: AppColors.textMuted,
                      size: 38,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No broadcasts yet',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Published emergency area alerts will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.olive,
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: notices.length + (result.isOffline ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (result.isOffline && index == 0) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.amber.withValues(alpha: 0.45)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.wifi_off_rounded, color: AppColors.amber, size: 15),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'OFFLINE ARCHIVE: Showing cached broadcasts from local storage.',
                            style: TextStyle(
                              color: AppColors.amber,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Courier',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final noticeIndex = result.isOffline ? index - 1 : index;
                return _buildNotice(notices[noticeIndex]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotice(_BroadcastNotice notice) {
    final urgent = notice.severity.toUpperCase() == 'FLASH_URGENT';
    final color = urgent ? AppColors.distress : AppColors.amber;
    final date = notice.createdAt?.toLocal();
    final dateText = date == null
        ? 'DATE UNAVAILABLE'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return Bevel(
      radius: 10,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.campaign_outlined, color: color, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  notice.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  border: Border.all(color: color.withValues(alpha: 0.55)),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  notice.severity.replaceAll('_', ' '),
                  style: TextStyle(
                    color: color,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            notice.message,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.hairline),
          const SizedBox(height: 9),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _meta(
                Icons.radar,
                '${(notice.radiusMeters / 1000).toStringAsFixed(1)} KM RADIUS',
              ),
              _meta(
                Icons.place_outlined,
                '${notice.latitude.toStringAsFixed(4)}, ${notice.longitude.toStringAsFixed(4)}',
              ),
            ],
          ),
          if (notice.channels.isNotEmpty) ...[
            const SizedBox(height: 8),
            _meta(Icons.cell_tower, notice.channels.join(' · ')),
          ],
          const SizedBox(height: 8),
          Text(
            dateText,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 9,
              fontFamily: 'Courier',
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: AppColors.olive),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          text,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
      ),
    ],
  );
}
