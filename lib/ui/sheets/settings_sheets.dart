import 'package:flutter/material.dart';

import '../../emulator/emulator_controller.dart';
import '../../models/image_enhancement_mode.dart';
import '../../utils/emulation_pause_guard.dart';

class SpeedSheet {
  static Future<void> show(BuildContext context, EmulatorController emu) {
    return EmulationPauseGuard.run(
      emu,
      () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF1A1A1A),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'EMULATION SPEED',
                  style: TextStyle(
                    color: Color(0xFFE8C84A),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in EmulatorController.speedPresets)
                      ChoiceChip(
                        label: Text('$s×'),
                        selected: (emu.emulationSpeed - s).abs() < 0.01,
                        onSelected: (_) async {
                          await emu.setEmulationSpeed(s);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsSheet {
  static Future<void> show(BuildContext context, EmulatorController emu, {
    required VoidCallback onLibrary,
    required VoidCallback onKeys,
    required VoidCallback onSlots,
    required VoidCallback onSpeed,
  }) {
    return EmulationPauseGuard.run(
      emu,
      () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF1A1A1A),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        builder: (ctx) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'SETTINGS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFE8C84A),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 16,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.sports_esports, color: Color(0xFFE8DCC8)),
                title: const Text('Game library', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  onLibrary();
                },
              ),
              ListTile(
                leading: const Icon(Icons.keyboard, color: Color(0xFFE8DCC8)),
                title: const Text('Keyboard bindings', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  onKeys();
                },
              ),
              ListTile(
                leading: const Icon(Icons.save, color: Color(0xFFE8DCC8)),
                title: const Text('Save slots', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  onSlots();
                },
              ),
              ListTile(
                leading: const Icon(Icons.speed, color: Color(0xFFE8DCC8)),
                title: const Text('Emulation speed', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  onSpeed();
                },
              ),
              SwitchListTile(
                secondary: Icon(
                  emu.soundEnabled ? Icons.volume_up : Icons.volume_off,
                  color: const Color(0xFFE8DCC8),
                ),
                title: const Text('Sound', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  '${(emu.soundVolume * 100).round()}%',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                ),
                value: emu.soundEnabled,
                onChanged: (v) {
                  emu.setSoundEnabled(v);
                  (ctx as Element).markNeedsBuild();
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        emu.volumeDown();
                        (ctx as Element).markNeedsBuild();
                      },
                      icon: const Icon(Icons.volume_down, color: Color(0xFFE8DCC8)),
                    ),
                    Expanded(
                      child: Slider(
                        value: emu.soundVolume,
                        onChanged: (v) {
                          emu.setSoundVolume(v);
                          (ctx as Element).markNeedsBuild();
                        },
                        activeColor: const Color(0xFFE8C84A),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        emu.volumeUp();
                        (ctx as Element).markNeedsBuild();
                      },
                      icon: const Icon(Icons.volume_up, color: Color(0xFFE8DCC8)),
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.fullscreen, color: Color(0xFFE8DCC8)),
                title: const Text('Fullscreen', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  'F11 or Alt+Enter · Esc to leave',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                ),
                value: emu.isFullscreen,
                onChanged: (_) {
                  emu.toggleFullscreen();
                  (ctx as Element).markNeedsBuild();
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.gamepad, color: Color(0xFFE8DCC8)),
                title: const Text('On-screen pad', style: TextStyle(color: Colors.white)),
                value: emu.showOnScreenPad,
                onChanged: (_) {
                  emu.toggleOnScreenPad();
                  (ctx as Element).markNeedsBuild();
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.auto_awesome, color: Color(0xFFE8DCC8)),
                title: const Text('Shaders', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  emu.enhancementMode.label,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                ),
                value: emu.shadersEnabled,
                onChanged: (v) {
                  emu.setShadersEnabled(v);
                  (ctx as Element).markNeedsBuild();
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: DropdownButtonFormField<ImageEnhancementMode>(
                  initialValue: emu.enhancementMode,
                  dropdownColor: const Color(0xFF2A2A2A),
                  decoration: const InputDecoration(
                    labelText: 'Shader mode',
                    labelStyle: TextStyle(color: Colors.white54),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  items: [
                    for (final mode in ImageEnhancementMode.values)
                      DropdownMenuItem(value: mode, child: Text(mode.label)),
                  ],
                  onChanged: (mode) {
                    if (mode == null) return;
                    emu.setEnhancementMode(mode);
                    (ctx as Element).markNeedsBuild();
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Color(0xFFE8DCC8)),
                title: Text(
                  emu.host.coreName ?? 'No core',
                  style: const TextStyle(color: Colors.white70),
                ),
                subtitle: Text(
                  'Slot ${emu.saveSlot} · ${emu.emulationSpeed}×',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
