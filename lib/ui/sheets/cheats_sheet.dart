import 'package:flutter/material.dart';

import '../../emulator/emulator_controller.dart';
import '../../services/cheat_service.dart';
import '../../utils/emulation_pause_guard.dart';

class CheatsSheet {
  static Future<void> show(BuildContext context, EmulatorController emu) {
    return EmulationPauseGuard.run(
      emu,
      () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF1A1A1A),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        builder: (ctx) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (ctx, scroll) => _CheatsBody(emu: emu, scroll: scroll),
        ),
      ),
    );
  }
}

class _CheatsBody extends StatelessWidget {
  const _CheatsBody({required this.emu, required this.scroll});

  final EmulatorController emu;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([emu, emu.host]),
      builder: (context, _) {
        final cheats = emu.host.cheatOptions;
        final rom = emu.host.romPath;
        final hasOptions =
            cheats.any((c) => c.label.trim().isNotEmpty);

        return SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text(
                  'CHEATS',
                  style: TextStyle(
                    color: Color(0xFFE8C84A),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              if (rom != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    rom.split('/').last,
                    style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
                  ),
                ),
              if (emu.hasGame && hasOptions)
                SwitchListTile(
                  title: const Text(
                    'Enable cheats',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    emu.cheatsMasterEnabled
                        ? 'Active cheats below are applied in-game'
                        : 'Toggles below are saved but not applied',
                    style: const TextStyle(
                      color: Color(0xFFAAAAAA),
                      fontSize: 12,
                    ),
                  ),
                  value: emu.cheatsMasterEnabled,
                  activeThumbColor: const Color(0xFFE8C84A),
                  onChanged: (on) => emu.setCheatsMasterEnabled(on),
                ),
              if (emu.hasGame && hasOptions)
                const Divider(color: Color(0xFF333333), height: 1),
              Expanded(
                child: !emu.hasGame
                    ? const Center(
                        child: Text(
                          'Load a game first',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : cheats.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No cheats for this game.\n'
                                'FBNeo needs {romset}.ini in the cheats pack.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white54),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scroll,
                            itemCount: cheats.length,
                            itemBuilder: (context, i) {
                              final c = cheats[i];
                              if (c.label.trim().isEmpty) {
                                return const Divider(color: Color(0xFF333333));
                              }
                              final multi = c.values.length > 2;
                              final display = emu.cheatDisplayValue(c);
                              if (multi) {
                                return ListTile(
                                  title: Text(
                                    c.label,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    display,
                                    style: const TextStyle(
                                      color: Color(0xFFAAAAAA),
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    color: Color(0xFFE8C84A),
                                  ),
                                  onTap: () => _pickValue(
                                    context,
                                    emu,
                                    c,
                                    display,
                                  ),
                                );
                              }
                              return SwitchListTile(
                                title: Text(
                                  c.label,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                value: emu.isCheatDesiredOn(c),
                                activeThumbColor: const Color(0xFFE8C84A),
                                onChanged: (on) {
                                  emu.setCheat(
                                    c.key,
                                    on ? c.enabledValue : c.disabledValue,
                                  );
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickValue(
    BuildContext context,
    EmulatorController emu,
    CheatOption cheat,
    String current,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF222222),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final v in cheat.values)
              ListTile(
                title: Text(v, style: const TextStyle(color: Colors.white)),
                trailing: v == current
                    ? const Icon(Icons.check, color: Color(0xFFE8C84A))
                    : null,
                onTap: () => Navigator.pop(ctx, v),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await emu.setCheat(cheat.key, picked);
  }
}
