import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Arcade action button with chrome bezel and a slightly **concave** face
/// (recessed plunger), matching real cabinet buttons.
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
              scale: _down ? 0.96 : 1.0,
              child: SizedBox(
                width: d,
                height: d,
                child: CustomPaint(
                  painter: _ConcaveButtonPainter(
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

class _ConcaveButtonPainter extends CustomPainter {
  _ConcaveButtonPainter({
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
    final depth = pressed ? 2.5 : 0.0;

    // Drop shadow under bezel.
    canvas.drawCircle(
      c.translate(0, pressed ? 2 : 5),
      r * 0.92,
      Paint()..color = const Color(0x77000000),
    );

    // Chrome metal bezel (unchanged convex ring).
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

    final faceC = c.translate(0, depth);
    final faceR = r * 0.74;
    final hsl = HSLColor.fromColor(color);
    final light =
        hsl.withLightness((hsl.lightness + 0.16).clamp(0.0, 1.0)).toColor();
    final mid = color;
    final dark =
        hsl.withLightness((hsl.lightness - 0.22).clamp(0.0, 1.0)).toColor();
    final well =
        hsl.withLightness((hsl.lightness - 0.32).clamp(0.0, 1.0)).toColor();

    // Concave dish: darker well in the center, lighter toward the rim.
    canvas.drawCircle(
      faceC,
      faceR,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(0.0, pressed ? 0.05 : -0.05),
          radius: 0.95,
          colors: [
            Color.lerp(well, Colors.black, pressed ? 0.2 : 0.0)!,
            dark,
            mid,
            light,
          ],
          stops: const [0.0, 0.35, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: faceC, radius: faceR)),
    );

    // Soft inner shadow along the top lip (recess cue).
    canvas.drawOval(
      Rect.fromCenter(
        center: faceC + Offset(0, -faceR * 0.42),
        width: faceR * 1.55,
        height: faceR * 0.72,
      ),
      Paint()
        ..shader = RadialGradient(
          center: Alignment.topCenter,
          radius: 1.0,
          colors: [
            Colors.black.withValues(alpha: pressed ? 0.45 : 0.32),
            Colors.black.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(
            center: faceC + Offset(0, -faceR * 0.35),
            radius: faceR,
          ),
        ),
    );

    // Thin rim catch-light (edge of the bowl).
    canvas.drawCircle(
      faceC,
      faceR * 0.97,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = faceR * 0.06
        ..shader = SweepGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.08),
            Colors.black.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.18, 0.45, 0.72, 1.0],
        ).createShader(Rect.fromCircle(center: faceC, radius: faceR)),
    );

    // Subtle bottom rim reflection (concave bounce).
    canvas.drawOval(
      Rect.fromCenter(
        center: faceC + Offset(0, faceR * 0.38),
        width: faceR * 1.05,
        height: faceR * 0.38,
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: pressed ? 0.08 : 0.14),
          ],
        ).createShader(Rect.fromCircle(center: faceC, radius: faceR)),
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
              color: Color(0x99000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, faceC - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ConcaveButtonPainter oldDelegate) =>
      oldDelegate.pressed != pressed ||
      oldDelegate.color != color ||
      oldDelegate.label != label;
}
