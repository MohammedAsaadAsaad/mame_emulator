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

class _CheatsBody extends StatefulWidget {
  const _CheatsBody({required this.emu, required this.scroll});

  final EmulatorController emu;
  final ScrollController scroll;

  @override
  State<_CheatsBody> createState() => _CheatsBodyState();
}

class _CheatsBodyState extends State<_CheatsBody> {
  final Set<String> _selected = {};

  EmulatorController get emu => widget.emu;

  List<CheatOption> get _cheats =>
      emu.host.cheatOptions.where((c) => c.label.trim().isNotEmpty).toList();

  void _toggleSelect(String key) {
    setState(() {
      if (!_selected.add(key)) _selected.remove(key);
    });
  }

  void _selectAll() {
    setState(() {
      _selected
        ..clear()
        ..addAll(_cheats.map((c) => c.key));
    });
  }

  void _clearSelection() => setState(_selected.clear);

  void _setSelected({required bool enable}) {
    final byKey = {for (final c in emu.host.cheatOptions) c.key: c};
    for (final key in _selected) {
      final c = byKey[key];
      if (c == null || c.values.isEmpty) continue;
      final next = enable ? _enabledValue(c) : _disabledValue(c);
      if (next != c.current) emu.setCheat(key, next);
    }
  }

  static String _disabledValue(CheatOption c) {
    for (final v in c.values) {
      if (v.toLowerCase().contains('disabled')) return v;
    }
    return c.values.first;
  }

  static String _enabledValue(CheatOption c) {
    for (final v in c.values) {
      if (!v.toLowerCase().contains('disabled')) return v;
    }
    return c.values.length > 1 ? c.values[1] : c.values.first;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: emu.host,
      builder: (context, _) {
        final cheats = emu.host.cheatOptions;
        final rom = emu.host.romPath;
        final selectable = _cheats;
        final allSelected =
            selectable.isNotEmpty && _selected.length == selectable.length;
        final hasSelection = _selected.isNotEmpty;

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
              if (emu.hasGame && selectable.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: allSelected ? _clearSelection : _selectAll,
                        child: Text(allSelected ? 'Deselect all' : 'Select all'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: hasSelection
                            ? () => _setSelected(enable: true)
                            : null,
                        child: const Text('Activate'),
                      ),
                      TextButton(
                        onPressed: hasSelection
                            ? () => _setSelected(enable: false)
                            : null,
                        child: const Text('Deactivate'),
                      ),
                    ],
                  ),
                ),
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
                            controller: widget.scroll,
                            itemCount: cheats.length,
                            itemBuilder: (context, i) {
                              final c = cheats[i];
                              if (c.label.trim().isEmpty) {
                                return const Divider(color: Color(0xFF333333));
                              }
                              final selected = _selected.contains(c.key);
                              final multi = c.values.length > 2;
                              return ListTile(
                                leading: Checkbox(
                                  value: selected,
                                  activeColor: const Color(0xFFE8C84A),
                                  checkColor: const Color(0xFF1A1A1A),
                                  onChanged: (_) => _toggleSelect(c.key),
                                ),
                                title: Text(
                                  c.label,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: multi
                                    ? Text(
                                        c.current,
                                        style: const TextStyle(
                                          color: Color(0xFFAAAAAA),
                                          fontSize: 12,
                                        ),
                                      )
                                    : null,
                                trailing: multi
                                    ? const Icon(
                                        Icons.chevron_right,
                                        color: Color(0xFFE8C84A),
                                      )
                                    : Switch(
                                        value: c.isEnabled,
                                        activeThumbColor:
                                            const Color(0xFFE8C84A),
                                        onChanged: (on) {
                                          emu.setCheat(
                                            c.key,
                                            on
                                                ? _enabledValue(c)
                                                : _disabledValue(c),
                                          );
                                        },
                                      ),
                                onTap: () {
                                  if (multi) {
                                    _pickValue(
                                      context,
                                      c.key,
                                      c.values,
                                      c.current,
                                    );
                                  } else {
                                    _toggleSelect(c.key);
                                  }
                                },
                                onLongPress: () => _toggleSelect(c.key),
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
    String key,
    List<String> values,
    String current,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF222222),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final v in values)
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
    if (picked != null) emu.setCheat(key, picked);
  }
}
