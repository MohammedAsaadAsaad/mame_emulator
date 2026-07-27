import 'package:flutter/material.dart';

/// Pixel arcade typeface (Press Start 2P).
abstract final class ArcadeText {
  static const family = 'PressStart2P';

  static TextStyle title({Color color = const Color(0xFFE8C84A), double size = 14}) =>
      TextStyle(
        fontFamily: family,
        color: color,
        fontSize: size,
        height: 1.4,
        letterSpacing: 1,
      );

  static TextStyle body({Color color = const Color(0xFFCCCCCC), double size = 9}) =>
      TextStyle(
        fontFamily: family,
        color: color,
        fontSize: size,
        height: 1.5,
        letterSpacing: 0.5,
      );

  static TextStyle dim({double size = 8}) => body(
        color: Colors.white.withValues(alpha: 0.4),
        size: size,
      );
}
