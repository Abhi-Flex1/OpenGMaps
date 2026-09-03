import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/google_maps_theme.dart';

/// Pixel-perfect vector render of the official Google 4-color 'G' logo
class GoogleGLogo extends StatelessWidget {
  const GoogleGLogo({super.key, this.size = 24.0});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleGLogoPainter(),
      ),
    );
  }
}

class _GoogleGLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;
    final strokeWidth = radius * 0.42;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    // Blue arc (top-right and horizontal bar)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -math.pi / 4, math.pi / 4 + 0.1, false, paint);

    // Draw the horizontal bar
    final barPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF4285F4);
    final barRect = Rect.fromLTRB(
      center.dx,
      center.dy - strokeWidth / 2,
      center.dx + radius,
      center.dy + strokeWidth / 2,
    );
    canvas.drawRect(barRect, barPaint);

    // Red arc (top and top-left)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -math.pi * 3 / 4 - 0.1, math.pi / 2 + 0.2, false, paint);

    // Yellow arc (bottom-left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -math.pi * 5 / 4 - 0.1, math.pi / 2 + 0.1, false, paint);

    // Green arc (bottom and bottom-right)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, -math.pi * 7 / 4 - 0.1, math.pi / 2 + 0.1, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official Google Maps Red Pin with circular inner icon
class GooglePinMarker extends StatelessWidget {
  const GooglePinMarker({
    super.key,
    required this.title,
    this.snippet,
    this.category = 'Place',
    this.rating,
    this.isSelected = false,
    this.onTap,
  });

  final String title;
  final String? snippet;
  final String category;
  final double? rating;
  final bool isSelected;
  final VoidCallback? onTap;

  IconData get _categoryIcon {
    switch (category.toLowerCase()) {
      case 'food':
      case 'restaurant':
        return Icons.restaurant;
      case 'hotel':
      case 'hotels':
        return Icons.hotel;
      case 'coffee':
      case 'cafe':
        return Icons.coffee;
      case 'shopping':
        return Icons.shopping_bag;
      case 'culture':
      case 'sights':
      case 'sight':
        return Icons.photo_camera;
      case 'nature':
      case 'park':
        return Icons.park;
      default:
        return Icons.place;
    }
  }

  Color get _pinColor {
    switch (category.toLowerCase()) {
      case 'food':
      case 'restaurant':
        return const Color(0xFFFF7043); // Food orange
      case 'hotel':
      case 'hotels':
        return const Color(0xFF7986CB); // Hotel purple
      case 'coffee':
      case 'cafe':
        return const Color(0xFF8D6E63); // Coffee brown
      case 'shopping':
        return const Color(0xFF26A69A); // Shopping teal
      case 'culture':
      case 'sights':
        return const Color(0xFF42A5F5); // Culture cyan
      case 'nature':
      case 'park':
        return const Color(0xFF66BB6A); // Nature green
      default:
        return GoogleMapsColors.googleRed; // Default pin red
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bubble label when selected or highlighted
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              constraints: const BoxConstraints(maxWidth: 220),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Google Sans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: GoogleMapsColors.textPrimary,
                      ),
                    ),
                  ),
                  if (rating != null) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.star, size: 12, color: Color(0xFFFBBC05)),
                    Text(
                      rating!.toStringAsFixed(1),
                      style: const TextStyle(
                        fontFamily: 'Google Sans',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: GoogleMapsColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          // Google Pin Body
          Container(
            width: isSelected ? 38 : 32,
            height: isSelected ? 38 : 32,
            decoration: BoxDecoration(
              color: _pinColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _pinColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(_categoryIcon, size: isSelected ? 20 : 16, color: Colors.white),
          ),
          // Downward pointer
          CustomPaint(
            size: const Size(10, 6),
            painter: _TrianglePointerPainter(color: _pinColor),
          ),
          if (!isSelected)
            Container(
              margin: const EdgeInsets.only(top: 2),
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Google Sans',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF202124),
                  shadows: [
                    Shadow(color: Colors.white, blurRadius: 4),
                    Shadow(color: Colors.white, blurRadius: 8),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrianglePointerPainter extends CustomPainter {
  const _TrianglePointerPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pulsing blue dot for live GPS location with bearing direction cone
class GoogleGpsDot extends StatefulWidget {
  const GoogleGpsDot({super.key, this.bearing = 0.0});

  final double bearing;

  @override
  State<GoogleGpsDot> createState() => _GoogleGpsDotState();
}

class _GoogleGpsDotState extends State<GoogleGpsDot> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final scale = 1.0 + _pulseCtrl.value * 0.8;
        final alpha = (1.0 - _pulseCtrl.value) * 0.35;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Accuracy Ring
            Transform.scale(
              scale: scale,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: GoogleMapsColors.locationBlue.withValues(alpha: alpha),
                ),
              ),
            ),
            // Heading Cone (pointing in bearing direction)
            Transform.rotate(
              angle: widget.bearing * math.pi / 180,
              child: CustomPaint(
                size: const Size(48, 48),
                painter: _HeadingConePainter(),
              ),
            ),
            // Solid Center Blue Dot with white border
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: GoogleMapsColors.locationBlue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeadingConePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          GoogleMapsColors.locationBlue.withValues(alpha: 0.35),
          GoogleMapsColors.locationBlue.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width / 2))
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: size.width / 2),
        -math.pi / 2 - 0.45,
        0.9,
        false,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
