import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/lora_locator_service.dart';
import '../../../core/theme/app_color.dart';
import '../../../core/theme/bevel.dart';

class LoraRadarPage extends StatefulWidget {
  const LoraRadarPage({super.key});

  @override
  State<LoraRadarPage> createState() => _LoraRadarPageState();
}

class _LoraRadarPageState extends State<LoraRadarPage> with SingleTickerProviderStateMixin {
  late final AnimationController _sweepAnim;
  StreamSubscription<Position>? _positionStreamSub;

  double _userLat = 12.9171; // Medavakkam default
  double _userLng = 80.1921;
  bool _hasGpsLock = false;
  String _gpsStatus = "Searching for GPS satellites...";

  List<NearbyLoraStation> _stations = [];
  NearbyLoraStation? _selectedStation;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _sweepAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _initLocatorAndGps();
  }

  @override
  void dispose() {
    _sweepAnim.dispose();
    _positionStreamSub?.cancel();
    super.dispose();
  }

  Future<void> _initLocatorAndGps() async {
    await LoraLocatorService.init();
    _refreshStationData();

    // Opportunistically sync from backend if network is available
    LoraLocatorService.syncStationsFromCloud().then((_) {
      if (mounted) _refreshStationData();
    });

    // Acquire GPS position
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );
      if (!mounted) return;
      setState(() {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
        _hasGpsLock = true;
        _gpsStatus = "GPS Lock: ${_userLat.toStringAsFixed(4)}°N, ${_userLng.toStringAsFixed(4)}°E";
      });
      _refreshStationData();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gpsStatus = "Offline GPS fallback (Medavakkam Sector: 12.9171°N, 80.1921°E)";
      });
      _refreshStationData();
    }

    // Subscribe to live GPS position updates for real-time walking navigation
    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters moved
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
        _hasGpsLock = true;
        _gpsStatus = "Live GPS: ${_userLat.toStringAsFixed(4)}°N, ${_userLng.toStringAsFixed(4)}°E";
      });
      _refreshStationData();
    }, onError: (_) {});
  }

  void _refreshStationData() {
    final list = LoraLocatorService.getNearbyStations(_userLat, _userLng);
    setState(() {
      _stations = list;
      if (_stations.isNotEmpty) {
        if (_selectedStation == null) {
          _selectedStation = _stations.first;
        } else {
          // Keep same station selected with updated metrics
          _selectedStation = _stations.firstWhere(
            (s) => s.code == _selectedStation!.code,
            orElse: () => _stations.first,
          );
        }
      }
    });
  }

  Future<void> _triggerManualSync() async {
    HapticFeedback.selectionClick();
    setState(() => _isSyncing = true);
    await LoraLocatorService.syncStationsFromCloud();
    _refreshStationData();
    if (!mounted) return;
    setState(() => _isSyncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.panel,
        content: Text(
          LoraLocatorService.syncStatusNotifier.value,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.bold),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = _selectedStation;
    final inRangeCount = _stations.where((s) => s.isInTwoKmRadius).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(inRangeCount),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
                child: Column(
                  children: [
                    // Radar HUD Widget
                    _buildRadarHud(),
                    const SizedBox(height: 16),

                    // Target Station Card with Compass & Distance Guidance
                    if (target != null) _buildTargetNavigationCard(target),
                    const SizedBox(height: 16),

                    // List of All Regional LoRa Repeaters
                    _buildTowersListSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(int inRangeCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Bevel(
              radius: 8,
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Bevel(
              inset: true,
              fill: AppColors.panel,
              radius: 8,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "LORA RADAR // 2KM RANGEFINDER",
                        style: TextStyle(
                          color: AppColors.amber,
                          fontSize: 10,
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      Text(
                        "$inRangeCount IN 2KM RANGE",
                        style: TextStyle(
                          color: inRangeCount > 0 ? AppColors.ledOn : AppColors.amber,
                          fontSize: 9,
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _hasGpsLock ? AppColors.ledOn : AppColors.amber,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _gpsStatus,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 8.5,
                            fontFamily: 'Courier',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isSyncing ? null : _triggerManualSync,
            child: Bevel(
              radius: 8,
              padding: const EdgeInsets.all(10),
              child: Icon(
                Icons.sync,
                color: _isSyncing ? AppColors.amber : AppColors.olive,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarHud() {
    return Bevel(
      radius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.ledOn,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Text(
                    "TACTICAL 2KM RF RADAR SWEEP",
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      fontFamily: 'Courier',
                    ),
                  ),
                ],
              ),
              const Text(
                "SCALE: 2.5 KM",
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9,
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Custom Painted Circular Radar
          SizedBox(
            height: 240,
            width: 240,
            child: AnimatedBuilder(
              animation: _sweepAnim,
              builder: (context, _) {
                return CustomPaint(
                  painter: _RadarPainter(
                    sweepAngle: _sweepAnim.value * 2 * math.pi,
                    stations: _stations,
                    selectedCode: _selectedStation?.code,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendPill("CENTER: YOU", AppColors.textPrimary),
              _buildLegendPill("DASHED RING: 2KM LIMIT", AppColors.olive),
              _buildLegendPill("DOTS: LORA TOWERS", AppColors.amber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendPill(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 8.5,
            fontWeight: FontWeight.bold,
            fontFamily: 'Courier',
          ),
        ),
      ],
    );
  }

  Widget _buildTargetNavigationCard(NearbyLoraStation target) {
    final distKm = (target.distanceMeters / 1000).toStringAsFixed(2);
    final isWithin2Km = target.isInTwoKmRadius;

    return Bevel(
      radius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Range Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isWithin2Km
                  ? AppColors.olive.withValues(alpha: 0.15)
                  : AppColors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isWithin2Km ? AppColors.olive : AppColors.amber,
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isWithin2Km ? Icons.check_circle_outline : Icons.near_me_outlined,
                  color: isWithin2Km ? AppColors.olive : AppColors.amber,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isWithin2Km
                        ? "WITHIN 2KM TRANSMISSION RADIUS — LORA READY"
                        : "OUT OF RANGE — WALK ${(target.distanceMeters - 2000).toInt()}M ${target.cardinalDirection.split(' ').last} TO REACH 2KM LIMIT",
                    style: TextStyle(
                      color: isWithin2Km ? AppColors.olive : AppColors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Courier',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Tower Name & Code
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "CODE: ${target.code} • ${target.status}",
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9.5,
                        fontFamily: 'Courier',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.panelRaised,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Text(
                  "${target.loraFrequencyMhz} MHz",
                  style: const TextStyle(
                    color: AppColors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Courier',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Big Nav Distance & Compass Bearing Meter
          Row(
            children: [
              // Distance Box
              Expanded(
                child: Bevel(
                  inset: true,
                  fill: AppColors.panel,
                  radius: 8,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "DISTANCE TO TOWER",
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            target.distanceMeters < 1000
                                ? "${target.distanceMeters.toInt()}"
                                : distKm,
                            style: TextStyle(
                              color: isWithin2Km ? AppColors.textPrimary : AppColors.amber,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Courier',
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            target.distanceMeters < 1000 ? "METERS" : "KM",
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Bearing Box with Rotating Compass Needle
              Expanded(
                child: Bevel(
                  inset: true,
                  fill: AppColors.panel,
                  radius: 8,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Transform.rotate(
                        angle: target.bearingDegrees * (math.pi / 180.0),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.panelRaised,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.olive, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.navigation,
                            color: AppColors.olive,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "COMPASS BEARING",
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${target.bearingDegrees.toInt()}°",
                              style: const TextStyle(
                                color: AppColors.olive,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Courier',
                              ),
                            ),
                            Text(
                              target.cardinalDirection,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Telemetry Specs Strip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSpecItem("SOLAR BATTERY", "${target.solarBatteryPct}%", Icons.battery_charging_full),
              _buildSpecItem("SOLAR CHARGE", "${target.solarChargingWatts}W", Icons.wb_sunny_outlined),
              _buildSpecItem("ALTITUDE", "${target.altitude.toInt()}m", Icons.landscape_outlined),
              _buildSpecItem("BACKHAUL", target.backhaulType, Icons.satellite_alt_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 7.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(icon, size: 11, color: AppColors.olive),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 10,
                fontFamily: 'Courier',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTowersListSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "CACHED REGIONAL LORA REPEATERS",
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                "${_stations.length} TOTAL TOWERS",
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9,
                  fontFamily: 'Courier',
                ),
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _stations.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final st = _stations[index];
            final isSelected = _selectedStation?.code == st.code;
            final isWithin2Km = st.isInTwoKmRadius;

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedStation = st);
              },
              child: Bevel(
                inset: isSelected,
                fill: isSelected ? AppColors.panelRaised : AppColors.panel,
                radius: 10,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isWithin2Km
                            ? AppColors.olive.withValues(alpha: 0.2)
                            : AppColors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isWithin2Km ? AppColors.olive : AppColors.amber,
                        ),
                      ),
                      child: Icon(
                        Icons.settings_input_antenna,
                        color: isWithin2Km ? AppColors.olive : AppColors.amber,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            st.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${st.code} • ${st.loraFrequencyMhz} MHz • ${st.cardinalDirection}",
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 9,
                              fontFamily: 'Courier',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          st.distanceMeters < 1000
                              ? "${st.distanceMeters.toInt()}m"
                              : "${(st.distanceMeters / 1000).toStringAsFixed(1)}km",
                          style: TextStyle(
                            color: isWithin2Km ? AppColors.olive : AppColors.amber,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Courier',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isWithin2Km ? AppColors.oliveDim : AppColors.panelRaised,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            isWithin2Km ? "IN 2KM" : "OUT",
                            style: TextStyle(
                              color: isWithin2Km ? AppColors.textPrimary : AppColors.textMuted,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Custom radar canvas drawing range rings (500m, 1km, 2km limit) and station blips
class _RadarPainter extends CustomPainter {
  final double sweepAngle;
  final List<NearbyLoraStation> stations;
  final String? selectedCode;

  _RadarPainter({
    required this.sweepAngle,
    required this.stations,
    this.selectedCode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = const Color(0xFF101317)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxRadius, bgPaint);

    // Concentric range circles: 500m, 1000m, 2000m (out of 2500m max scale)
    const maxScaleMeters = 2500.0;

    void drawRangeRing(double meters, Color color, bool isDashed, double strokeWidth) {
      final r = (meters / maxScaleMeters) * maxRadius;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      if (!isDashed) {
        canvas.drawCircle(center, r, paint);
      } else {
        // Draw dashed ring for the 2km emergency threshold
        const dashCount = 36;
        const sweepStep = 2 * math.pi / dashCount;
        for (int i = 0; i < dashCount; i += 2) {
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: r),
            i * sweepStep,
            sweepStep,
            false,
            paint,
          );
        }
      }
    }

    drawRangeRing(600, const Color(0xFF222832), false, 1.0);
    drawRangeRing(1200, const Color(0xFF222832), false, 1.0);
    // 2KM Threshold Ring (Dashed Olive)
    drawRangeRing(2000, AppColors.olive, true, 1.8);

    // Crosshairs
    final gridPaint = Paint()
      ..color = const Color(0xFF222832)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), gridPaint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), gridPaint);

    // Rotating Sweep Arc
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          AppColors.olive.withValues(alpha: 0.35),
          AppColors.olive.withValues(alpha: 0.0),
        ],
        transform: GradientRotation(sweepAngle - math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.drawCircle(center, maxRadius, sweepPaint);

    // User center point
    final userPaint = Paint()..color = AppColors.textPrimary;
    canvas.drawCircle(center, 4, userPaint);
    canvas.drawCircle(center, 8, Paint()..color = AppColors.olive.withValues(alpha: 0.3)..style = PaintingStyle.stroke);

    // Draw Stations as blips on the radar
    for (final st in stations) {
      final isSelected = st.code == selectedCode;
      final distRatio = math.min(1.0, st.distanceMeters / maxScaleMeters);
      final r = distRatio * maxRadius;

      // Bearing angle in radians (-90 deg offset because 0 deg is North/Up)
      final rad = (st.bearingDegrees - 90) * (math.pi / 180.0);
      final blipX = center.dx + r * math.cos(rad);
      final blipY = center.dy + r * math.sin(rad);
      final blipOffset = Offset(blipX, blipY);

      final blipColor = isSelected
          ? (st.isInTwoKmRadius ? AppColors.ledOn : AppColors.amber)
          : (st.isInTwoKmRadius ? AppColors.olive : const Color(0xFF7A828E));

      if (isSelected) {
        // Draw vector line to selected tower
        final linePaint = Paint()
          ..color = blipColor.withValues(alpha: 0.6)
          ..strokeWidth = 1.4;
        canvas.drawLine(center, blipOffset, linePaint);

        // Highlight ring around selected target
        canvas.drawCircle(
          blipOffset,
          8,
          Paint()
            ..color = blipColor.withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      // Blip point
      canvas.drawCircle(blipOffset, isSelected ? 4.5 : 3.5, Paint()..color = blipColor);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}
