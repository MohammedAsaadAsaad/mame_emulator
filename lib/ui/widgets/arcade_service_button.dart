import 'package:flutter/material.dart';

/// Classic arcade COIN / START — metal bezel with a slightly **concave** face.
class ArcadeServiceButton extends StatefulWidget {
  const ArcadeServiceButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.faceColor = const Color(0xFFE8E0D0),
    this.diameter = 52,
  });

  final String label;
  final VoidCallback onPressed;
  final Color faceColor;
  final double diameter;

  @override
  State<ArcadeServiceButton> createState() => _ArcadeServiceButtonState();
}

class _ArcadeServiceButtonState extends State<ArcadeServiceButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.diameter;

    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _down = false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: d,
            height: d,
            child: CustomPaint(
              painter: _ConcaveServicePainter(
                faceColor: widget.faceColor,
                pressed: _down,
              ),
            ),
          ),
          SizedBox(height: d < 40 ? 4 : 6),
          Text(
            widget.label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: d < 40 ? 8 : 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConcaveServicePainter extends CustomPainter {
  _ConcaveServicePainter({
    required this.faceColor,
    required this.pressed,
  });

  final Color faceColor;
  final bool pressed;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final depth = pressed ? 1.8 : 0.0;
    final border = (r * 0.13).clamp(2.0, 3.5);

    canvas.drawCircle(
      c.translate(0, pressed ? 1.5 : 3.5),
      r * 0.9,
      Paint()..color = const Color(0x88000000),
    );

    // Dark metal housing ring.
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF2A2A2A));

    final faceC = c.translate(0, depth);
    final faceR = r - border;
    final face = faceColor;
    final well = Color.lerp(face, Colors.black, pressed ? 0.42 : 0.28)!;
    final rim = Color.lerp(face, Colors.white, 0.35)!;

    // Concave dish.
    canvas.drawCircle(
      faceC,
      faceR,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(0.0, pressed ? 0.08 : -0.02),
          radius: 0.92,
          colors: [
            well,
            Color.lerp(face, Colors.black, 0.12)!,
            face,
            rim,
          ],
          stops: const [0.0, 0.4, 0.75, 1.0],
        ).createShader(Rect.fromCircle(center: faceC, radius: faceR)),
    );

    // Top inner shadow (recess).
    canvas.drawOval(
      Rect.fromCenter(
        center: faceC + Offset(0, -faceR * 0.4),
        width: faceR * 1.5,
        height: faceR * 0.7,
      ),
      Paint()
        ..shader = RadialGradient(
          center: Alignment.topCenter,
          radius: 1.0,
          colors: [
            Colors.black.withValues(alpha: pressed ? 0.4 : 0.28),
            Colors.black.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(
            center: faceC + Offset(0, -faceR * 0.3),
            radius: faceR,
          ),
        ),
    );

    // Rim catch-light.
    canvas.drawCircle(
      faceC,
      faceR * 0.96,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = faceR * 0.07
        ..shader = SweepGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.4),
            Colors.white.withValues(alpha: 0.05),
            Colors.black.withValues(alpha: 0.2),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: faceC, radius: faceR)),
    );
  }

  @override
  bool shouldRepaint(covariant _ConcaveServicePainter oldDelegate) =>
      oldDelegate.pressed != pressed || oldDelegate.faceColor != faceColor;
}
