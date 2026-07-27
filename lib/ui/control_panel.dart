import 'package:flutter/material.dart';

import '../../emulator/emulator_controller.dart';
import 'widgets/arcade_joystick.dart';
import 'widgets/arcade_service_button.dart';
import 'widgets/glossy_action_button.dart';

/// True for phone / small-tablet landscape where the game should fill the screen.
bool isCompactLandscape(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
  if (!landscape) return false;
  // Phones & small tablets: short side under ~600, or low landscape height.
  return size.shortestSide < 600 || size.height < 520;
}

/// Shared chrome for the metal control deck (portrait / wide desktop rails).
BoxDecoration controlDeckDecoration({bool sideRail = false}) {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: sideRail ? Alignment.centerLeft : Alignment.topCenter,
      end: sideRail ? Alignment.centerRight : Alignment.bottomCenter,
      colors: const [
        Color(0xFF3A3A3A),
        Color(0xFF262626),
        Color(0xFF1A1A1A),
      ],
    ),
    border: sideRail
        ? null
        : const Border(
            top: BorderSide(color: Color(0xFF555555), width: 1.5),
          ),
    boxShadow: sideRail
        ? null
        : const [
            BoxShadow(
              color: Color(0x88000000),
              blurRadius: 12,
              offset: Offset(0, -4),
            ),
          ],
  );
}

class ControlPanel extends StatelessWidget {
  const ControlPanel({
    super.key,
    required this.controller,
  });

  final EmulatorController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: controlDeckDecoration(),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ServiceButtons(controller: controller),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ArcadeJoystick(
                    size: 148,
                    onChanged: (o) => controller.setStick(o.dx, o.dy),
                  ),
                  const Spacer(),
                  ActionCluster(controller: controller),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Landscape left: COIN / START + stick.
/// [overlay] = transparent HUD over a full-bleed game (small screens).
class LandscapeLeftControls extends StatelessWidget {
  const LandscapeLeftControls({
    super.key,
    required this.controller,
    this.overlay = false,
  });

  final EmulatorController controller;
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    final stick = overlay ? 120.0 : 112.0;
    final coin = overlay ? 44.0 : 40.0;

    final column = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        ServiceButtons(
          controller: controller,
          compact: true,
          diameter: coin,
        ),
        SizedBox(height: overlay ? 16 : 12),
        ArcadeJoystick(
          size: stick,
          onChanged: (o) => controller.setStick(o.dx, o.dy),
        ),
      ],
    );

    if (overlay) {
      return SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: _SoftPadChrome(child: column),
        ),
      );
    }

    return Container(
      width: 120,
      decoration: controlDeckDecoration(sideRail: true),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: column,
        ),
      ),
    );
  }
}

/// Landscape right: A–D cluster.
class LandscapeRightControls extends StatelessWidget {
  const LandscapeRightControls({
    super.key,
    required this.controller,
    this.overlay = false,
  });

  final EmulatorController controller;
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    final scale = overlay ? 0.88 : 0.78;
    final cluster = ActionCluster(controller: controller, scale: scale);

    if (overlay) {
      return SafeArea(
        left: false,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _SoftPadChrome(child: cluster),
        ),
      );
    }

    return Container(
      width: 120,
      decoration: controlDeckDecoration(sideRail: true),
      child: SafeArea(
        left: false,
        child: Center(child: cluster),
      ),
    );
  }
}

/// Soft translucent plate behind overlay controls (readable, not opaque rails).
class _SoftPadChrome extends StatelessWidget {
  const _SoftPadChrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }
}

class ServiceButtons extends StatelessWidget {
  const ServiceButtons({
    super.key,
    required this.controller,
    this.compact = false,
    this.diameter,
  });

  final EmulatorController controller;
  final bool compact;
  final double? diameter;

  @override
  Widget build(BuildContext context) {
    final d = diameter ?? (compact ? 40.0 : 52.0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        ArcadeServiceButton(
          label: 'COIN',
          diameter: d,
          faceColor: const Color(0xFFD4AF37),
          onPressed: controller.insertCoin,
        ),
        SizedBox(width: compact ? 12 : 36),
        ArcadeServiceButton(
          label: 'START',
          diameter: d,
          faceColor: const Color(0xFFE8E4DC),
          onPressed: controller.pressStart,
        ),
      ],
    );
  }
}

class ActionCluster extends StatelessWidget {
  const ActionCluster({
    super.key,
    required this.controller,
    this.scale = 1,
  });

  final EmulatorController controller;
  final double scale;

  static const _cyan = Color(0xFF2EC8D8);
  static const _red = Color(0xFFE02020);

  @override
  Widget build(BuildContext context) {
    final d = 62.0 * scale;
    final w = 150.0 * scale;
    final h = 140.0 * scale;
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          Positioned(
            left: 8 * scale,
            top: 8 * scale,
            child: GlossyActionButton(
              label: 'C',
              color: _cyan,
              diameter: d,
              onDown: () => controller.buttonDown(PadButton.c),
              onUp: () => controller.buttonUp(PadButton.c),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: GlossyActionButton(
              label: 'D',
              color: _cyan,
              diameter: d,
              onDown: () => controller.buttonDown(PadButton.d),
              onUp: () => controller.buttonUp(PadButton.d),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 8 * scale,
            child: GlossyActionButton(
              label: 'B',
              color: _red,
              diameter: d,
              onDown: () => controller.buttonDown(PadButton.b),
              onUp: () => controller.buttonUp(PadButton.b),
            ),
          ),
          Positioned(
            right: 8 * scale,
            bottom: 0,
            child: GlossyActionButton(
              label: 'A',
              color: _red,
              diameter: d,
              onDown: () => controller.buttonDown(PadButton.a),
              onUp: () => controller.buttonUp(PadButton.a),
            ),
          ),
        ],
      ),
    );
  }
}
