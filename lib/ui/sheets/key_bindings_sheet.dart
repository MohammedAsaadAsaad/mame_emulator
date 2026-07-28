import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/input_mapper.dart';
import '../../emulator/emulator_controller.dart';
import '../../utils/emulation_pause_guard.dart';
import '../../utils/platform_info.dart';

class KeyBindingsSheet {
  static Future<void> show(BuildContext context, EmulatorController emu) {
    return EmulationPauseGuard.run(
      emu,
      () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF1A1A1A),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        builder: (ctx) => _KeysBody(emu: emu),
      ),
    );
  }
}

class _KeysBody extends StatefulWidget {
  const _KeysBody({required this.emu});

  final EmulatorController emu;

  @override
  State<_KeysBody> createState() => _KeysBodyState();
}

class _KeysBodyState extends State<_KeysBody> {
  ControlAction? _listening;

  @override
  Widget build(BuildContext context) {
    final kb = widget.emu.keyBindings;
    return SafeArea(
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (_listening == null) return KeyEventResult.ignored;
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            setState(() => _listening = null);
            return KeyEventResult.handled;
          }
          // Ignore pure modifiers.
          if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
              event.logicalKey == LogicalKeyboardKey.shiftRight ||
              event.logicalKey == LogicalKeyboardKey.controlLeft ||
              event.logicalKey == LogicalKeyboardKey.controlRight ||
              event.logicalKey == LogicalKeyboardKey.altLeft ||
              event.logicalKey == LogicalKeyboardKey.altRight) {
            return KeyEventResult.handled;
          }
          final action = _listening!;
          kb.setBinding(action, event.logicalKey).then((_) {
            if (mounted) setState(() => _listening = null);
          });
          return KeyEventResult.handled;
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'KEYBOARD BINDINGS',
                style: TextStyle(
                  color: Color(0xFFE8C84A),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _listening == null
                    ? (isDesktopPlatform
                        ? 'Tap a row, then press a key'
                        : 'Tap a row, then press a key on a keyboard')
                    : (isDesktopPlatform
                        ? 'Listening for ${_listening!.shortLabel}… (Esc cancel)'
                        : 'Listening for ${_listening!.shortLabel}…'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    await kb.resetToDefaults();
                    setState(() {});
                  },
                  child: const Text('Reset defaults'),
                ),
              ),
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.55,
                child: ListView(
                  children: [
                    for (final action in kMappableActions)
                      ListTile(
                        title: Text(action.description, style: const TextStyle(color: Colors.white)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _listening == action
                                ? const Color(0xFFE8C84A)
                                : const Color(0xFF333333),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            kb.labelFor(action),
                            style: TextStyle(
                              color: _listening == action ? Colors.black : Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        onTap: () => setState(() => _listening = action),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
