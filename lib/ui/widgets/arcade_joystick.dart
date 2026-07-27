import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ball-top arcade joystick on a screwed metal plate.
class ArcadeJoystick extends StatefulWidget {
  const ArcadeJoystick({
    super.key,
    required this.onChanged,
    this.size = 150,
  });

  final ValueChanged<Offset> onChanged;
  final double size;

  @override
  State<ArcadeJoystick> createState() => _ArcadeJoystickState();
}

class _ArcadeJoystickState extends State<ArcadeJoystick> {
  Offset _knob = Offset.zero;

  double get _radius => widget.size * 0.28;

  void _update(Offset local) {
    final center = Offset(widget.size / 2, widget.size / 2);
    var delta = local - center;
    final max = widget.size * 0.22;
    if (delta.distance > max) {
      delta = Offset.fromDirection(delta.direction, max);
    }
    setState(() => _knob = delta);
    widget.onChanged(Offset(delta.dx / max, delta.dy / max));
  }

  void _reset() {
    setState(() => _knob = Offset.zero);
    widget.onChanged(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        onPanStart: (d) => _update(d.localPosition),
        onPanUpdate: (d) => _update(d.localPosition),
        onPanEnd: (_) => _reset(),
        onPanCancel: _reset,
        child: CustomPaint(
          painter: _JoystickPainter(knob: _knob, ballRadius: _radius),
          size: Size.square(size),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter({required this.knob, required this.ballRadius});

  final Offset knob;
  final double ballRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final plate = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: size.width * 0.92, height: size.height * 0.92),
      const Radius.circular(10),
    );

    // Plate shadow
    canvas.drawRRect(
      plate.shift(const Offset(0, 3)),
      Paint()..color = const Color(0x88000000),
    );

    // Brushed metal plate
    final platePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFD8D8D8),
          Color(0xFF9A9A9A),
          Color(0xFFC4C4C4),
          Color(0xFF7E7E7E),
        ],
        stops: [0.0, 0.35, 0.7, 1.0],
      ).createShader(plate.outerRect);
    canvas.drawRRect(plate, platePaint);

    // Plate edge
    canvas.drawRRect(
      plate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF4A4A4A),
    );

    // Screws
    final screwOffsets = [
      Offset(size.width * 0.14, size.height * 0.14),
      Offset(size.width * 0.86, size.height * 0.14),
      Offset(size.width * 0.14, size.height * 0.86),
      Offset(size.width * 0.86, size.height * 0.86),
    ];
    for (final o in screwOffsets) {
      _drawScrew(canvas, o);
    }

    // Direction triangles
    final triPaint = Paint()..color = const Color(0xFF5A5A5A);
    final triR = size.width * 0.28;
    _triangle(canvas, center + Offset(0, -triR), 0, triPaint);
    _triangle(canvas, center + Offset(0, triR), math.pi, triPaint);
    _triangle(canvas, center + Offset(-triR, 0), -math.pi / 2, triPaint);
    _triangle(canvas, center + Offset(triR, 0), math.pi / 2, triPaint);

    // Shaft
    final ballCenter = center + knob;
    final shaft = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF666666), Color(0xFF222222)],
      ).createShader(Rect.fromCircle(center: center, radius: 10));
    canvas.drawLine(
      center,
      ballCenter,
      shaft
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Red ball top
    final ballRect = Rect.fromCircle(center: ballCenter, radius: ballRadius);
    canvas.drawCircle(
      ballCenter.translate(2, 4),
      ballRadius,
      Paint()..color = const Color(0x66000000),
    );
    canvas.drawCircle(
      ballCenter,
      ballRadius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.45, -0.55),
          radius: 1.05,
          colors: const [
            Color(0xFFFF6B5C),
            Color(0xFFE01010),
            Color(0xFF8B0A0A),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(ballRect),
    );
    // Specular highlight
    canvas.drawOval(
      Rect.fromCenter(
        center: ballCenter + Offset(-ballRadius * 0.35, -ballRadius * 0.4),
        width: ballRadius * 0.55,
        height: ballRadius * 0.35,
      ),
      Paint()..color = const Color(0xAAFFFFFF),
    );
  }

  void _drawScrew(Canvas canvas, Offset c) {
    canvas.drawCircle(
      c,
      5.5,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFEEEEEE), Color(0xFF777777)],
        ).createShader(Rect.fromCircle(center: c, radius: 5.5)),
    );
    canvas.drawCircle(c, 5.5, Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF444444)
      ..strokeWidth = 0.8);
    final slot = Paint()
      ..color = const Color(0xFF333333)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c + const Offset(-3, 0), c + const Offset(3, 0), slot);
    canvas.drawLine(c + const Offset(0, -3), c + const Offset(0, 3), slot);
  }

  void _triangle(Canvas canvas, Offset tip, double rot, Paint paint) {
    final path = Path();
    path.moveTo(0, -6);
    path.lineTo(5, 4);
    path.lineTo(-5, 4);
    path.close();
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(rot);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) =>
      oldDelegate.knob != knob;
}
