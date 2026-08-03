import 'package:flutter/material.dart';
import 'app_color.dart';

/// A panel that reads as physically raised (light bevel top/left, dark
/// bevel bottom/right) or pressed-in / inset (bevel reversed) -- the
/// hardware-chassis look used across every screen instead of glass
/// cards with glow shadows.
class Bevel extends StatelessWidget {
  final Widget child;
  final bool inset;
  final Color fill;
  final double radius;
  final EdgeInsetsGeometry padding;

  const Bevel({
    super.key,
    required this.child,
    this.inset = false,
    this.fill = AppColors.panel,
    this.radius = 12,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    final top = inset ? AppColors.bevelDark : AppColors.bevelLight;
    final bottom = inset ? AppColors.bevelLight : AppColors.bevelDark;
    return CustomPaint(
      painter: _BevelPainter(fill: fill, lightColor: top, darkColor: bottom, radius: radius),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Paints the fill + two-tone bevel edge by hand. `BoxDecoration` cannot
/// combine a `borderRadius` with a non-uniform `Border` (it throws "A
/// borderRadius can only be given for a uniform Border" at paint time,
/// silently leaving the widget blank) -- this sidesteps that by drawing
/// the rounded-rect fill, then stroking a light top/left edge and a dark
/// bottom/right edge as two separately clipped passes over the same
/// rounded rect, split along the diagonal from the top-right corner to
/// the bottom-left corner.
class _BevelPainter extends CustomPainter {
  final Color fill;
  final Color lightColor;
  final Color darkColor;
  final double radius;
  static const double _strokeWidth = 1.4;

  _BevelPainter({
    required this.fill,
    required this.lightColor,
    required this.darkColor,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    canvas.drawRRect(rrect, Paint()..color = fill);

    final strokeRRect = rrect.deflate(_strokeWidth / 2);
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;

    canvas.save();
    canvas.clipPath(Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.left, rect.bottom)
      ..close());
    canvas.drawRRect(strokeRRect, strokePaint..color = lightColor);
    canvas.restore();

    canvas.save();
    canvas.clipPath(Path()
      ..moveTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close());
    canvas.drawRRect(strokeRRect, strokePaint..color = darkColor);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BevelPainter oldDelegate) =>
      oldDelegate.fill != fill ||
          oldDelegate.lightColor != lightColor ||
          oldDelegate.darkColor != darkColor ||
          oldDelegate.radius != radius;
}