import 'dart:io';

import 'package:flutter/material.dart';

import '../../emulator/emulator_controller.dart';
import '../../models/library_models.dart';
import '../../utils/emulation_pause_guard.dart';

class SaveSlotsSheet {
  static Future<void> show(BuildContext context, EmulatorController emu) {
    return EmulationPauseGuard.run(emu, () async {
      await emu.refreshSaveSlots();
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF1A1A1A),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        builder: (ctx) => _SaveSlotsBody(emu: emu),
      );
    });
  }
}

class _SaveSlotsBody extends StatelessWidget {
  const _SaveSlotsBody({required this.emu});

  final EmulatorController emu;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: emu,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'MEMORY PACK',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFE8C84A),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  emu.host.romPath != null
                      ? emu.host.romPath!.split('/').last
                      : 'No ROM loaded',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.5,
                  child: ListView.builder(
                    itemCount: EmulatorController.maxSlots,
                    itemBuilder: (context, i) {
                      final slot = i + 1;
                      final info = emu.saveSlots.length >= slot
                          ? emu.saveSlots[i]
                          : SaveSlotInfo(slot: slot, occupied: false);
                      final active = emu.saveSlot == slot;
                      return ListTile(
                        leading: SizedBox(
                          width: 56,
                          height: 42,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: info.thumbnailPath != null
                                ? Image.file(
                                    File(info.thumbnailPath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => _slotBadge(slot, active),
                                  )
                                : _slotBadge(slot, active),
                          ),
                        ),
                        title: Text(
                          info.occupied
                              ? (info.romName ?? 'Occupied')
                              : 'Empty',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          info.savedAt?.toLocal().toString().substring(0, 19) ??
                              '—',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Save',
                              onPressed: () async {
                                await emu.saveState(slot: slot);
                              },
                              icon: const Icon(Icons.save_alt, color: Color(0xFFE8DCC8)),
                            ),
                            IconButton(
                              tooltip: 'Load',
                              onPressed: info.occupied
                                  ? () async {
                                      await emu.loadState(slot: slot);
                                      if (context.mounted) Navigator.pop(context);
                                    }
                                  : null,
                              icon: const Icon(Icons.play_arrow),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: info.occupied
                                  ? () => emu.deleteSaveSlot(slot)
                                  : null,
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            ),
                          ],
                        ),
                        onTap: () => emu.cycleSlot(slot - emu.saveSlot),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _slotBadge(int slot, bool active) {
    return ColoredBox(
      color: active ? const Color(0xFFE8C84A) : const Color(0xFF333333),
      child: Center(
        child: Text(
          '$slot',
          style: TextStyle(
            color: active ? Colors.black : Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
