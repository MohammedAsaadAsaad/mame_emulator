import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Glossy plastic arcade action button with chrome bezel.
///
/// Uses [Listener] so presses register immediately (no gesture-arena delay).
class GlossyActionButton extends StatefulWidget {
  const GlossyActionButton({
    super.key,
    required this.label,
    required this.color,
    required this.onDown,
    required this.onUp,
    this.diameter = 64,
    this.ghost = false,
  });

  final String label;
  final Color color;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final double diameter;

  /// Slightly translucent face for fullscreen / overlay pads.
  final bool ghost;

  @override
  State<GlossyActionButton> createState() => _GlossyActionButtonState();
}

class _GlossyActionButtonState extends State<GlossyActionButton> {
  bool _down = false;
  int? _activePointer;

  void _press(bool down) {
    if (_down == down) return;
    setState(() => _down = down);
    if (down) {
      HapticFeedback.selectionClick();
      widget.onDown();
    } else {
      widget.onUp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.diameter;
    // Extra hit padding so nearby taps still catch the button.
    final hit = d * 1.18;
    final opacity = widget.ghost ? 0.78 : 1.0;

    return SizedBox(
      width: hit,
      height: hit,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          if (_activePointer != null) return;
          _activePointer = e.pointer;
          _press(true);
        },
        onPointerUp: (e) {
          if (e.pointer != _activePointer) return;
          _activePointer = null;
          _press(false);
        },
        onPointerCancel: (e) {
          if (e.pointer != _activePointer) return;
          _activePointer = null;
          _press(false);
        },
        child: Center(
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: _down ? 0.94 : 1.0,
              child: SizedBox(
                width: d,
                height: d,
                child: CustomPaint(
                  painter: _ButtonPainter(
                    color: widget.color,
                    label: widget.label,
                    pressed: _down,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonPainter extends CustomPainter {
  _ButtonPainter({
    required this.color,
    required this.label,
    required this.pressed,
  });

  final Color color;
  final String label;
  final bool pressed;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    canvas.drawCircle(
      c.translate(0, pressed ? 2 : 5),
      r * 0.92,
      Paint()..color = const Color(0x77000000),
    );

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = SweepGradient(
          colors: const [
            Color(0xFFF5F5F5),
            Color(0xFF8A8A8A),
            Color(0xFFE8E8E8),
            Color(0xFF6A6A6A),
            Color(0xFFF5F5F5),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    canvas.drawCircle(c, r * 0.82, Paint()..color = const Color(0xFF2A2A2A));

    final faceR = r * 0.74;
    final hsl = HSLColor.fromColor(color);
    final light =
        hsl.withLightness((hsl.lightness + 0.22).clamp(0.0, 1.0)).toColor();
    final dark =
        hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor();

    canvas.drawCircle(
      c.translate(0, pressed ? 1.5 : 0),
      faceR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.55),
          radius: 1.1,
          colors: [light, color, dark],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: faceR)),
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(0, -faceR * 0.35),
        width: faceR * 1.15,
        height: faceR * 0.55,
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: faceR)),
    );

    canvas.drawCircle(
      c + Offset(-faceR * 0.28, -faceR * 0.32),
      faceR * 0.12,
      Paint()..color = const Color(0xCCFFFFFF),
    );

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: faceR * 0.72,
          fontWeight: FontWeight.w800,
          shadows: const [
            Shadow(
              color: Color(0x88000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      c.translate(0, pressed ? 1.5 : 0) - Offset(tp.width / 2, tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _ButtonPainter oldDelegate) =>
      oldDelegate.pressed != pressed ||
      oldDelegate.color != color ||
      oldDelegate.label != label;
}
