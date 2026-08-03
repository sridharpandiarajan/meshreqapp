import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/services/device_identity_service.dart';
import '../../../core/theme/app_color.dart';
import '../../../core/theme/bevel.dart';
import '../../permissions/presentation/permission_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _statusLine = "Starting up";
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    _updateStatus("Establishing secure identity", 0.18);
    await DeviceIdentityService.init();
    await Future.delayed(const Duration(milliseconds: 900));

    _updateStatus("Scanning for nearby mesh nodes", 0.48);
    await Future.delayed(const Duration(milliseconds: 1100));

    _updateStatus("Preparing offline relay", 0.78);
    await Future.delayed(const Duration(milliseconds: 900));

    _updateStatus("Ready", 1.0);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: const PermissionPage(),
        ),
      ),
    );
  }

  void _updateStatus(String status, double progress) {
    if (mounted) {
      setState(() {
        _statusLine = status;
        _progress = progress;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fixed-width branding, not reflowable content -- at a large system
    // text-scale setting, single-line uppercase tracking text has
    // nowhere to wrap and just runs off both edges instead. Clamp
    // rather than disable scaling entirely.
    final clampedScaler = MediaQuery.textScalerOf(context).clamp(
      minScaleFactor: 0.9,
      maxScaleFactor: 1.15,
    );

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: clampedScaler),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(
          children: [
            // Quiet dot-grid texture -- flat, no gradient backdrop.
            Positioned.fill(
              child: CustomPaint(painter: _DotGridPainter()),
            ),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        // The whole logo block sits inside an inset bevel,
                        // like a display recessed into a device's chassis
                        // rather than floating text over an ambient glow.
                        child: Bevel(
                          inset: true,
                          fill: AppColors.panel,
                          radius: 20,
                          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 200,
                                width: 200,
                                child: AnimatedBuilder(
                                  animation: _controller,
                                  builder: (context, child) {
                                    return CustomPaint(
                                      painter: _MeshFormationPainter(
                                        pulse: _controller.value,
                                        reveal: _progress,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 40),
                              RichText(
                                text: const TextSpan(
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                    height: 1.0,
                                  ),
                                  children: [
                                    TextSpan(text: "Mesh", style: TextStyle(color: AppColors.textPrimary)),
                                    TextSpan(text: "ResQ", style: TextStyle(color: AppColors.amber)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "OFFLINE EMERGENCY MESH NETWORK",
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                softWrap: false,
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                  fontFamily: 'Courier',
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2.4,
                                ),
                              ),
                              const SizedBox(height: 56),
                              _buildProgressLine(),
                              const SizedBox(height: 14),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 320),
                                // Old text fully fades out before the new
                                // one fades in, so single-line text never
                                // double-exposes mid-transition.
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.15),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                layoutBuilder: (currentChild, previousChildren) {
                                  return Stack(
                                    alignment: Alignment.topCenter,
                                    children: [
                                      ...previousChildren,
                                      if (currentChild != null) currentChild,
                                    ],
                                  );
                                },
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                child: Text(
                                  _statusLine,
                                  key: ValueKey(_statusLine),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                    fontFamily: 'Courier',
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      "v0.1 \u00b7 BUILDING THE MESH, NODE BY NODE",
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        color: AppColors.textMuted.withValues(alpha: 0.5),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressLine() {
    return SizedBox(
      width: 160,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Container(
          height: 4,
          color: AppColors.bevelDark,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: _progress.clamp(0.0, 1.0),
            // Flat fill, no glow shadow -- a status LED strip, not a
            // neon bar.
            child: Container(color: AppColors.amber),
          ),
        ),
      ),
    );
  }
}

/// A satellite node in the mesh signature: its polar position relative
/// to the home node, and the boot-progress fraction at which its
/// connection line finishes drawing in.
class _NodeSpec {
  final double angleDeg;
  final double radius;
  final double revealAt;
  const _NodeSpec(this.angleDeg, this.radius, this.revealAt);
}

const List<_NodeSpec> _nodes = [
  _NodeSpec(-96, 58, 0.15),
  _NodeSpec(-22, 80, 0.32),
  _NodeSpec(48, 54, 0.5),
  _NodeSpec(122, 74, 0.68),
  _NodeSpec(196, 60, 0.85),
];

class _MeshFormationPainter extends CustomPainter {
  final double pulse; // 0..1, continuous, drives ambient motion
  final double reveal; // 0..1, boot progress, drives node/line reveal
  _MeshFormationPainter({required this.pulse, required this.reveal});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Ambient pulse ring from the home node -- a single crisp stroke
    // that fades as it expands, no blur.
    final phase = (pulse * 1.4) % 1.0;
    final ringRadius = 15 + phase * 40;
    final alpha = (1 - phase) * 0.35;
    if (alpha > 0) {
      canvas.drawCircle(
        center,
        ringRadius,
        Paint()
          ..color = AppColors.amberDim.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    // Connections + satellite nodes.
    for (final node in _nodes) {
      final localReveal = ((reveal - node.revealAt) / 0.15).clamp(0.0, 1.0);
      if (localReveal <= 0) continue;

      final angle = node.angleDeg * math.pi / 180;
      final target = center + Offset(math.cos(angle), math.sin(angle)) * node.radius;
      final lineEnd = Offset.lerp(center, target, localReveal)!;

      canvas.drawLine(
        center,
        lineEnd,
        Paint()
          ..color = AppColors.olive.withValues(alpha: 0.6 * localReveal)
          ..strokeWidth = 1.2,
      );

      if (localReveal > 0.85) {
        final nodeAlpha = ((localReveal - 0.85) / 0.15).clamp(0.0, 1.0);
        // Flat filled dot with a darker rim -- reads as a rivet/terminal,
        // not a glowing halo.
        canvas.drawCircle(target, 4, Paint()..color = AppColors.olive.withValues(alpha: nodeAlpha));
        canvas.drawCircle(
          target,
          4,
          Paint()
            ..color = AppColors.bevelDark.withValues(alpha: nodeAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }

    // Home node -- solid disc with a rim, always present.
    canvas.drawCircle(center, 7, Paint()..color = AppColors.amber);
    canvas.drawCircle(
      center,
      7,
      Paint()
        ..color = AppColors.bevelDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _MeshFormationPainter oldDelegate) =>
      oldDelegate.pulse != pulse || oldDelegate.reveal != reveal;
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.03);
    const spacing = 28.0;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) => false;
}