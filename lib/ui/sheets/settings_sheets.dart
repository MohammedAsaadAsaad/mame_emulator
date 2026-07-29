import 'package:flutter/material.dart';

import '../../emulator/emulator_controller.dart';
import '../../models/image_enhancement_mode.dart';
import '../../utils/emulation_pause_guard.dart';
import '../../utils/platform_info.dart';

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

/// Single Sound control: enable checkbox + volume slider.
class SoundSheet {
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: AnimatedBuilder(
              animation: emu,
              builder: (context, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'SOUND',
                      style: TextStyle(
                        color: Color(0xFFE8C84A),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: emu.soundEnabled,
                      onChanged: (v) {
                        if (v != null) emu.setSoundEnabled(v);
                      },
                      activeColor: const Color(0xFFE8C84A),
                      checkColor: const Color(0xFF1A1A1A),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Enable sound',
                        style: TextStyle(color: Colors.white),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.volume_down,
                          color: emu.soundEnabled
                              ? const Color(0xFFE8DCC8)
                              : Colors.white24,
                        ),
                        Expanded(
                          child: Slider(
                            value: emu.soundVolume,
                            onChanged: emu.soundEnabled
                                ? (v) => emu.setSoundVolume(v)
                                : null,
                            activeColor: const Color(0xFFE8C84A),
                            inactiveColor: const Color(0xFF444444),
                          ),
                        ),
                        Icon(
                          Icons.volume_up,
                          color: emu.soundEnabled
                              ? const Color(0xFFE8DCC8)
                              : Colors.white24,
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${(emu.soundVolume * 100).round()}%',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              color: emu.soundEnabled
                                  ? Colors.white70
                                  : Colors.white24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
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
    VoidCallback? onCheats,
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
                leading: Icon(
                  Icons.auto_fix_high,
                  color: emu.hasGame
                      ? const Color(0xFFE8DCC8)
                      : const Color(0xFF666666),
                ),
                title: Text(
                  'Cheats',
                  style: TextStyle(
                    color: emu.hasGame ? Colors.white : const Color(0xFF666666),
                  ),
                ),
                subtitle: Text(
                  emu.hasGame
                      ? (emu.hasCheats
                          ? '${emu.host.cheatOptions.length} available'
                          : 'None for this game')
                      : 'Load a game first',
                  style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
                ),
                onTap: !emu.hasGame || onCheats == null
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        onCheats();
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
                  isDesktopPlatform
                      ? 'F11 or Alt+Enter · Esc to leave'
                      : 'Tap Full above or this switch',
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
