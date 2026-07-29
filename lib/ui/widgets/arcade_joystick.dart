import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ball-top arcade joystick on a screwed metal plate.
///
/// [ghost] draws a translucent pad (fullscreen / overlay). Any press inside
/// the hit area maps immediately to a direction — no drag required.
class ArcadeJoystick extends StatefulWidget {
  const ArcadeJoystick({
    super.key,
    required this.onChanged,
    this.size = 150,
    this.ghost = false,
    this.externalNormalized = Offset.zero,
  });

  final ValueChanged<Offset> onChanged;
  final double size;

  /// Soft / transparent plate for overlays and fullscreen.
  final bool ghost;

  /// Keyboard-driven stick (−1..1). Used when the user is not touching.
  final Offset externalNormalized;

  @override
  State<ArcadeJoystick> createState() => _ArcadeJoystickState();
}

class _ArcadeJoystickState extends State<ArcadeJoystick> {
  Offset _knob = Offset.zero;
  int? _activePointer;

  double get _radius => widget.size * 0.28;

  /// Visual pad size; hit target is slightly larger around it.
  double get _hit => widget.size * 1.28;

  double get _maxThrow => widget.size * 0.38;

  Offset get _displayKnob {
    if (_activePointer != null) return _knob;
    final ext = widget.externalNormalized;
    if (ext == Offset.zero) return Offset.zero;
    return Offset(ext.dx * _maxThrow, ext.dy * _maxThrow);
  }

  void _updateFromLocal(Offset local) {
    final center = Offset(_hit / 2, _hit / 2);
    var delta = local - center;
    // Generous throw: edges of the pad reach full deflection quickly.
    final max = _maxThrow;
    if (delta.distance > max) {
      delta = Offset.fromDirection(delta.direction, max);
    }
    // Small deadzone so accidental center taps don't twitch.
    final dead = max * 0.12;
    final out = delta.distance < dead
        ? Offset.zero
        : Offset(delta.dx / max, delta.dy / max);
    setState(() => _knob = out == Offset.zero ? Offset.zero : delta);
    widget.onChanged(out);
  }

  void _reset() {
    _activePointer = null;
    setState(() => _knob = Offset.zero);
    widget.onChanged(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final hit = _hit;
    final padOffset = (hit - size) / 2;

    return SizedBox(
      width: hit,
      height: hit,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          if (_activePointer != null) return;
          _activePointer = e.pointer;
          _updateFromLocal(e.localPosition);
        },
        onPointerMove: (e) {
          if (e.pointer != _activePointer) return;
          _updateFromLocal(e.localPosition);
        },
        onPointerUp: (e) {
          if (e.pointer != _activePointer) return;
          _reset();
        },
        onPointerCancel: (e) {
          if (e.pointer != _activePointer) return;
          _reset();
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: padOffset,
              top: padOffset,
              width: size,
              height: size,
              child: CustomPaint(
                painter: _JoystickPainter(
                  knob: _displayKnob,
                  ballRadius: _radius,
                  ghost: widget.ghost,
                ),
                size: Size.square(size),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter({
    required this.knob,
    required this.ballRadius,
    required this.ghost,
  });

  final Offset knob;
  final double ballRadius;
  final bool ghost;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final plate = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.92,
        height: size.height * 0.92,
      ),
      const Radius.circular(10),
    );

    if (ghost) {
      // Soft ring only — no metal plate.
      canvas.drawRRect(
        plate,
        Paint()..color = Colors.white.withValues(alpha: 0.06),
      );
      canvas.drawRRect(
        plate,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Colors.white.withValues(alpha: 0.22),
      );
      canvas.drawCircle(
        center,
        size.width * 0.18,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.16),
      );
    } else {
      canvas.drawRRect(
        plate.shift(const Offset(0, 3)),
        Paint()..color = const Color(0x88000000),
      );

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

      canvas.drawRRect(
        plate,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFF4A4A4A),
      );

      final screwOffsets = [
        Offset(size.width * 0.14, size.height * 0.14),
        Offset(size.width * 0.86, size.height * 0.14),
        Offset(size.width * 0.14, size.height * 0.86),
        Offset(size.width * 0.86, size.height * 0.86),
      ];
      for (final o in screwOffsets) {
        _drawScrew(canvas, o);
      }
    }

    final triPaint = Paint()
      ..color = ghost
          ? Colors.white.withValues(alpha: 0.45)
          : const Color(0xFF5A5A5A);
    final triR = size.width * 0.28;
    _triangle(canvas, center + Offset(0, -triR), 0, triPaint);
    _triangle(canvas, center + Offset(0, triR), math.pi, triPaint);
    _triangle(canvas, center + Offset(-triR, 0), -math.pi / 2, triPaint);
    _triangle(canvas, center + Offset(triR, 0), math.pi / 2, triPaint);

    final ballCenter = center + knob;
    if (!ghost) {
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
    } else {
      canvas.drawLine(
        center,
        ballCenter,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }

    final ballRect = Rect.fromCircle(center: ballCenter, radius: ballRadius);
    final ballAlpha = ghost ? 0.72 : 1.0;
    canvas.drawCircle(
      ballCenter.translate(2, 4),
      ballRadius,
      Paint()..color = Color.fromRGBO(0, 0, 0, ghost ? 0.25 : 0.4),
    );
    canvas.drawCircle(
      ballCenter,
      ballRadius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.45, -0.55),
          radius: 1.05,
          colors: [
            Color.fromRGBO(255, 107, 92, ballAlpha),
            Color.fromRGBO(224, 16, 16, ballAlpha),
            Color.fromRGBO(139, 10, 10, ballAlpha),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(ballRect),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: ballCenter + Offset(-ballRadius * 0.35, -ballRadius * 0.4),
        width: ballRadius * 0.55,
        height: ballRadius * 0.35,
      ),
      Paint()..color = Color.fromRGBO(255, 255, 255, ghost ? 0.45 : 0.67),
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
    canvas.drawCircle(
      c,
      5.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF444444)
        ..strokeWidth = 0.8,
    );
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
      oldDelegate.knob != knob || oldDelegate.ghost != ghost;
}
