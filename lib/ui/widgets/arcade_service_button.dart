import 'package:flutter/material.dart';

/// Classic arcade COIN / START button — metal bezel, domed face, simple press.
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
    final face = Color.lerp(
      widget.faceColor,
      const Color(0xFF888888),
      _down ? 0.35 : 0,
    )!;
    final d = widget.diameter;
    final border = (d * 0.067).clamp(2.0, 3.5);

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
          AnimatedContainer(
            duration: const Duration(milliseconds: 55),
            width: d,
            height: d,
            transform: Matrix4.translationValues(0, _down ? 1.5 : 0, 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.45),
                radius: 0.95,
                colors: _down
                    ? [
                        Color.lerp(face, Colors.black, 0.25)!,
                        face,
                        Color.lerp(face, Colors.black, 0.4)!,
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.55),
                        face,
                        Color.lerp(face, Colors.black, 0.28)!,
                      ],
                stops: const [0.0, 0.45, 1.0],
              ),
              border: Border.all(
                color: const Color(0xFF2A2A2A),
                width: border,
              ),
              boxShadow: _down
                  ? const [
                      BoxShadow(
                        color: Color(0x88000000),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.65),
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.12),
                        blurRadius: 1,
                        offset: const Offset(0, -1),
                      ),
                    ],
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
