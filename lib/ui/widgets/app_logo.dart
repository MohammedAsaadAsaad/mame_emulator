import 'package:flutter/material.dart';

/// Bundled arcade cabinet mark used as the app logo.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 48});

  static const assetPath = 'assets/icon/arcade.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => Icon(
        Icons.sports_esports,
        size: size * 0.75,
        color: const Color(0xFFE8C84A),
      ),
    );
  }
}
