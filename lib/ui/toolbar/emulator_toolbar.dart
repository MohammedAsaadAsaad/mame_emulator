import 'package:flutter/material.dart';

import '../../emulator/emulator_controller.dart';
import '../../models/image_enhancement_mode.dart';
import '../sheets/settings_sheets.dart';

/// Thin NES-style horizontal emulator toolbar above the CRT.
class EmulatorToolbar extends StatelessWidget {
  const EmulatorToolbar({
    super.key,
    required this.controller,
    required this.onLibrary,
    required this.onSlots,
    required this.onKeys,
    required this.onSpeed,
    required this.onSettings,
    this.onCheats,
    this.compact = false,
  });

  final EmulatorController controller;
  final VoidCallback onLibrary;
  final VoidCallback onSlots;
  final VoidCallback onKeys;
  final VoidCallback onSpeed;
  final VoidCallback onSettings;
  final VoidCallback? onCheats;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final running = controller.isRunning;
    final loaded = controller.hasGame;
    final fs = controller.isFullscreen;

    return Material(
      color: compact ? const Color(0xCC1A1A1A) : const Color(0xFF2A2A2A),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: const Color(0xFF111111),
              width: compact ? 1 : 1.5,
            ),
          ),
        ),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          children: [
            _Tool(
              icon: Icons.sports_esports,
              label: 'Games',
              onTap: onLibrary,
            ),
            _Tool(icon: Icons.save, label: 'Slots', onTap: onSlots),
            _Tool(
              icon: running ? Icons.pause : Icons.play_arrow,
              label: running ? 'Pause' : 'Play',
              onTap: loaded ? controller.togglePause : null,
            ),
            _Tool(
              icon: Icons.restart_alt,
              label: 'Reset',
              onTap: loaded ? controller.resetEmulation : null,
            ),
            _Tool(
              icon: Icons.auto_fix_high,
              label: 'Cheats',
              onTap: loaded ? onCheats : null,
            ),
            _Tool(
              icon: controller.soundEnabled
                  ? Icons.volume_up
                  : Icons.volume_off,
              label: 'Sound',
              onTap: () => SoundSheet.show(context, controller),
            ),
            _Tool(
              icon: Icons.speed,
              label: '${controller.emulationSpeed.toStringAsFixed(2)}×',
              onTap: onSpeed,
            ),
            _Tool(icon: Icons.keyboard, label: 'Keys', onTap: onKeys),
            _Tool(
              icon: controller.showOnScreenPad
                  ? Icons.gamepad
                  : Icons.gamepad_outlined,
              label: 'Pad',
              onTap: controller.toggleOnScreenPad,
            ),
            Builder(
              builder: (ctx) => _Tool(
                icon: controller.shadersEnabled
                    ? Icons.auto_awesome
                    : Icons.auto_awesome_outlined,
                label: controller.shadersEnabled
                    ? controller.enhancementMode.shortLabel
                    : 'FX Off',
                onTap: () => _pickShader(ctx, controller),
              ),
            ),
            _Tool(
              icon: fs ? Icons.fullscreen_exit : Icons.fullscreen,
              label: fs ? 'Exit FS' : 'Full',
              onTap: () => controller.toggleFullscreen(),
            ),
            _Tool(icon: Icons.settings, label: 'Menu', onTap: onSettings),
          ],
        ),
      ),
    );
  }

  void _pickShader(BuildContext context, EmulatorController emu) {
    final box = context.findRenderObject() as RenderBox?;
    final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    showMenu<Object>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy + 44, pos.dx + 200, 0),
      color: const Color(0xFF222222),
      items: [
        PopupMenuItem(
          value: 'toggle',
          child: Text(
            emu.shadersEnabled ? 'Disable FX' : 'Enable FX',
            style: const TextStyle(
              color: Color(0xFFE8C84A),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const PopupMenuDivider(),
        for (final mode in ImageEnhancementMode.values)
          PopupMenuItem(
            value: mode,
            child: Text(
              mode.label,
              style: TextStyle(
                color: emu.shadersEnabled && mode == emu.enhancementMode
                    ? const Color(0xFFE8C84A)
                    : Colors.white,
                fontWeight: emu.shadersEnabled && mode == emu.enhancementMode
                    ? FontWeight.w800
                    : FontWeight.w500,
              ),
            ),
          ),
      ],
    ).then((value) {
      if (value == null) return;
      if (value == 'toggle') {
        emu.toggleShaders();
      } else if (value is ImageEnhancementMode) {
        emu.setEnhancementMode(value);
      }
    });
  }
}

class _Tool extends StatelessWidget {
  const _Tool({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          constraints: const BoxConstraints(minWidth: 56),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF3A3A3A),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF111111)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: enabled ? const Color(0xFFE8DCC8) : Colors.white24,
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: enabled ? const Color(0xFFB8B8B8) : Colors.white24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
