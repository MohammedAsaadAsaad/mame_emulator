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
    this.ghost = false,
  });

  final EmulatorController controller;

  /// Fullscreen / overlay: translucent pad chrome and ghost stick/buttons.
  final bool ghost;

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(
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
                  ghost: ghost,
                  externalNormalized: controller.stickVisualFromKeys,
                  onChanged: (o) => controller.setStick(o.dx, o.dy),
                ),
                const Spacer(),
                ActionCluster(controller: controller, ghost: ghost),
              ],
            ),
          ],
        ),
      ),
    );

    if (ghost) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Container(
          width: double.infinity,
          color: Colors.black.withValues(alpha: 0.22),
          child: body,
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: controlDeckDecoration(),
      child: body,
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
          ghost: overlay,
          externalNormalized: controller.stickVisualFromKeys,
          onChanged: (o) => controller.setStick(o.dx, o.dy),
        ),
      ],
    );

    if (overlay) {
      return SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          // Absorb taps so fullscreen chrome toggle doesn't steal presses.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: column,
          ),
        ),
      );
    }

    return Container(
      width: 156,
      decoration: controlDeckDecoration(sideRail: true),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
    final cluster = ActionCluster(
      controller: controller,
      scale: scale,
      ghost: overlay,
    );

    if (overlay) {
      return SafeArea(
        left: false,
        child: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: cluster,
          ),
        ),
      );
    }

    return Container(
      width: 156,
      decoration: controlDeckDecoration(sideRail: true),
      child: SafeArea(
        left: false,
        child: Center(child: cluster),
      ),
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
          pressed: controller.coinPressed,
          onPressed: controller.insertCoin,
        ),
        SizedBox(width: compact ? 12 : 36),
        ArcadeServiceButton(
          label: 'START',
          diameter: d,
          faceColor: const Color(0xFFE8E4DC),
          pressed: controller.startPressed,
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
    this.ghost = false,
  });

  final EmulatorController controller;
  final double scale;
  final bool ghost;

  static const _cyan = Color(0xFF2EC8D8);
  static const _red = Color(0xFFE02020);

  @override
  Widget build(BuildContext context) {
    final d = 62.0 * scale;
    // Room for enlarged hit targets on each button.
    final w = 168.0 * scale;
    final h = 158.0 * scale;
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          Positioned(
            left: 4 * scale,
            top: 4 * scale,
            child: GlossyActionButton(
              label: 'C',
              color: _cyan,
              diameter: d,
              ghost: ghost,
              pressed: controller.isPadPressed(PadButton.c),
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
              ghost: ghost,
              pressed: controller.isPadPressed(PadButton.d),
              onDown: () => controller.buttonDown(PadButton.d),
              onUp: () => controller.buttonUp(PadButton.d),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 4 * scale,
            child: GlossyActionButton(
              label: 'B',
              color: _red,
              diameter: d,
              ghost: ghost,
              pressed: controller.isPadPressed(PadButton.b),
              onDown: () => controller.buttonDown(PadButton.b),
              onUp: () => controller.buttonUp(PadButton.b),
            ),
          ),
          Positioned(
            right: 4 * scale,
            bottom: 0,
            child: GlossyActionButton(
              label: 'A',
              color: _red,
              diameter: d,
              ghost: ghost,
              pressed: controller.isPadPressed(PadButton.a),
              onDown: () => controller.buttonDown(PadButton.a),
              onUp: () => controller.buttonUp(PadButton.a),
            ),
          ),
        ],
      ),
    );
  }
}
