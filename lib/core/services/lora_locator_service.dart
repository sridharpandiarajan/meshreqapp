import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'mesh_api_service.dart';

class NearbyLoraStation {
  final String code;
  final String name;
  final double latitude;
  final double longitude;
  final double altitude;
  final double coverageRadiusMeters;
  final double loraFrequencyMhz;
  final int solarBatteryPct;
  final double solarChargingWatts;
  final String status;
  final String backhaulType;

  // Real-time computed navigation metrics
  final double distanceMeters;
  final double bearingDegrees;
  final String cardinalDirection;
  final bool isInTwoKmRadius;

  const NearbyLoraStation({
    required this.code,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.coverageRadiusMeters,
    required this.loraFrequencyMhz,
    required this.solarBatteryPct,
    required this.solarChargingWatts,
    required this.status,
    required this.backhaulType,
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.cardinalDirection,
    required this.isInTwoKmRadius,
  });

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'coverage_radius_meters': coverageRadiusMeters,
      'lora_frequency_mhz': loraFrequencyMhz,
      'solar_battery_pct': solarBatteryPct,
      'solar_charging_watts': solarChargingWatts,
      'status': status,
      'backhaul_type': backhaulType,
    };
  }

  factory NearbyLoraStation.fromMap(Map<String, dynamic> map, {double userLat = 12.9171, double userLng = 80.1921}) {
    final lat = (map['latitude'] as num?)?.toDouble() ?? (map['lat'] as num?)?.toDouble() ?? 12.9171;
    final lng = (map['longitude'] as num?)?.toDouble() ?? (map['lng'] as num?)?.toDouble() ?? 80.1921;
    final dist = LoraLocatorService.calculateDistance(userLat, userLng, lat, lng);
    final bearing = LoraLocatorService.calculateBearing(userLat, userLng, lat, lng);

    return NearbyLoraStation(
      code: map['code'] as String? ?? map['station_code'] as String? ?? 'ECP-GENERIC',
      name: map['name'] as String? ?? 'LoRa Solar Repeater',
      latitude: lat,
      longitude: lng,
      altitude: (map['altitude'] as num?)?.toDouble() ?? (map['altitude_m'] as num?)?.toDouble() ?? 20.0,
      coverageRadiusMeters: (map['coverage_radius_meters'] as num?)?.toDouble() ?? (map['radius_m'] as num?)?.toDouble() ?? 3500.0,
      loraFrequencyMhz: (map['lora_frequency_mhz'] as num?)?.toDouble() ?? (map['freq_mhz'] as num?)?.toDouble() ?? 868.1,
      solarBatteryPct: (map['solar_battery_pct'] as num?)?.toInt() ?? 90,
      solarChargingWatts: (map['solar_charging_watts'] as num?)?.toDouble() ?? 45.0,
      status: map['status'] as String? ?? 'OPERATIONAL',
      backhaulType: map['backhaul_type'] as String? ?? 'SATELLITE',
      distanceMeters: dist,
      bearingDegrees: bearing,
      cardinalDirection: LoraLocatorService.getCardinalDirection(bearing),
      isInTwoKmRadius: dist <= 2000.0,
    );
  }
}

class LoraLocatorService {
  static const String boxName = 'lora_stations_box';
  static final ValueNotifier<int> cachedTowersCountNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> towersInTwoKmNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<String> syncStatusNotifier = ValueNotifier<String>("Offline Cache Ready");

  /// Default emergency seed stations centered on Medavakkam, Chennai sector
  /// Guarantees the app works offline from the very first boot without network
  static final List<Map<String, dynamic>> _defaultSeedStations = [
    {
      "code": "ECP-MEDAVAKKAM-01",
      "name": "Medavakkam Junction Solar Relay Tower",
      "latitude": 12.9195,
      "longitude": 80.1935,
      "altitude": 22.0,
      "coverage_radius_meters": 4000.0,
      "lora_frequency_mhz": 868.1,
      "solar_battery_pct": 98,
      "solar_charging_watts": 55.4,
      "backhaul_type": "SATELLITE",
      "status": "OPERATIONAL"
    },
    {
      "code": "ECP-NANMANGALAM-02",
      "name": "Nanmangalam Reserve Forest Outpost Gate",
      "latitude": 12.9280,
      "longitude": 80.1780,
      "altitude": 28.0,
      "coverage_radius_meters": 3500.0,
      "lora_frequency_mhz": 868.3,
      "solar_battery_pct": 88,
      "solar_charging_watts": 42.0,
      "backhaul_type": "CELLULAR_4G",
      "status": "OPERATIONAL"
    },
    {
      "code": "ECP-PERUMBAKKAM-03",
      "name": "Perumbakkam Lake Repeater Node",
      "latitude": 12.9030,
      "longitude": 80.2050,
      "altitude": 18.0,
      "coverage_radius_meters": 3500.0,
      "lora_frequency_mhz": 868.5,
      "solar_battery_pct": 72,
      "solar_charging_watts": 30.2,
      "backhaul_type": "MICROWAVE",
      "status": "OPERATIONAL"
    }
  ];

  static Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }

    final box = Hive.box(boxName);
    if (box.isEmpty) {
      for (final st in _defaultSeedStations) {
        await box.put(st['code'], st);
      }
      debugPrint('[LoraLocator] Seeded ${box.length} offline LoRa stations into Hive.');
    }
    cachedTowersCountNotifier.value = box.length;
  }

  /// Downloads fresh ECP station coordinates and telemetry when internet is active
  static Future<int> syncStationsFromCloud() async {
    await init();
    final candidateUrls = [
      MeshApiService.getBaseUrl(),
      "http://127.0.0.1:8000",
      "http://10.0.2.2:8000",
    ];

    for (final baseUrl in candidateUrls) {
      try {
        final resp = await http.get(
          Uri.parse("$baseUrl/api/v1/ecp/offline-package"),
        ).timeout(const Duration(seconds: 3));

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final stations = data['stations'] as List<dynamic>? ?? [];
          final box = Hive.box(boxName);

          for (final raw in stations) {
            if (raw is Map) {
              final map = Map<String, dynamic>.from(raw);
              final code = map['code'] ?? map['station_code'] ?? 'ECP-${box.length + 1}';
              await box.put(code, map);
            }
          }

          cachedTowersCountNotifier.value = box.length;
          syncStatusNotifier.value = "Updated from Command Cloud (${box.length} Towers)";
          debugPrint('[LoraLocator] Synced ${stations.length} LoRa stations from cloud.');
          return box.length;
        }
      } catch (_) {}
    }

    syncStatusNotifier.value = "Offline Cache Active (${Hive.box(boxName).length} Towers)";
    return Hive.box(boxName).length;
  }

  /// Computes distances and bearings to all cached LoRa repeaters from user coordinates
  static List<NearbyLoraStation> getNearbyStations(double userLat, double userLng) {
    if (!Hive.isBoxOpen(boxName)) return [];
    final box = Hive.box(boxName);

    final List<NearbyLoraStation> list = [];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        list.add(NearbyLoraStation.fromMap(map, userLat: userLat, userLng: userLng));
      }
    }

    // Sort by proximity: closest towers first
    list.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    // Update in-2km count notifier
    final inTwoKm = list.where((s) => s.isInTwoKmRadius).length;
    towersInTwoKmNotifier.value = inTwoKm;

    return list;
  }

  /// Haversine formula for exact distance in meters over spherical Earth
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusMeters = 6371000.0;
    final double dLat = _degToRad(lat2 - lat1);
    final double dLon = _degToRad(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// Calculates initial compass bearing in degrees (0° - 360°)
  static double calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final double phi1 = _degToRad(lat1);
    final double phi2 = _degToRad(lat2);
    final double deltaLambda = _degToRad(lon2 - lon1);

    final double y = math.sin(deltaLambda) * math.cos(phi2);
    final double x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);

    final double theta = math.atan2(y, x);
    final double bearingDegrees = (_radToDeg(theta) + 360.0) % 360.0;
    return bearingDegrees;
  }

  /// Converts bearing angle to 16-point cardinal compass text
  static String getCardinalDirection(double bearingDegrees) {
    const directions = [
      "North (N)", "North-Northeast (NNE)", "Northeast (NE)", "East-Northeast (ENE)",
      "East (E)", "East-Southeast (ESE)", "Southeast (SE)", "South-Southeast (SSE)",
      "South (S)", "South-Southwest (SSW)", "Southwest (SW)", "West-Southwest (WSW)",
      "West (W)", "West-Northwest (WNW)", "Northwest (NW)", "North-Northwest (NNW)"
    ];
    final index = ((bearingDegrees + 11.25) % 360 / 22.5).floor();
    return directions[index % 16];
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
  static double _radToDeg(double rad) => rad * (180.0 / math.pi);
}
