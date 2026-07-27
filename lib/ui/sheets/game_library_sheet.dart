import 'package:flutter/material.dart';

import '../../emulator/emulator_controller.dart';
import '../../utils/emulation_pause_guard.dart';

class GameLibrarySheet {
  static Future<void> show(BuildContext context, EmulatorController emu) {
    return EmulationPauseGuard.run(emu, () async {
      await emu.refreshLibrary();
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF1A1A1A),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        builder: (ctx) => _LibraryBody(emu: emu),
      );
    });
  }
}

class _LibraryBody extends StatefulWidget {
  const _LibraryBody({required this.emu});

  final EmulatorController emu;

  @override
  State<_LibraryBody> createState() => _LibraryBodyState();
}

class _LibraryBodyState extends State<_LibraryBody> {
  String _query = '';
  bool _favoritesOnly = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: widget.emu,
        builder: (context, _) {
          var games = widget.emu.games;
          if (_favoritesOnly) {
            games = games.where((g) => g.favorite).toList();
          }
          if (_query.isNotEmpty) {
            final q = _query.toLowerCase();
            games = games
                .where((g) =>
                    g.title.toLowerCase().contains(q) ||
                    g.path.toLowerCase().contains(q))
                .toList();
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'GAME LIBRARY',
                  style: TextStyle(
                    color: Color(0xFFE8C84A),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ROMs stay in their original folders · states in app data',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                ),
                const SizedBox(height: 10),
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search title or path…',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Favorites'),
                      selected: _favoritesOnly,
                      onSelected: (v) => setState(() => _favoritesOnly = v),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () async {
                        await widget.emu.scanFolderWithPicker();
                        await widget.emu.refreshLibrary();
                      },
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Scan'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await widget.emu.importRomsWithPicker();
                        if (context.mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.file_open),
                      label: const Text('Import'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.45,
                  child: games.isEmpty
                      ? Center(
                          child: Text(
                            'No games — Import, Scan folder, or drop a .zip',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                          ),
                        )
                      : ListView.builder(
                          itemCount: games.length,
                          itemBuilder: (context, i) {
                            final g = games[i];
                            return ListTile(
                              leading: const Icon(Icons.videogame_asset, color: Color(0xFFE8C84A)),
                              title: Text(g.title, style: const TextStyle(color: Colors.white)),
                              subtitle: Text(
                                g.path,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 11,
                                ),
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                icon: Icon(
                                  g.favorite ? Icons.star : Icons.star_border,
                                  color: const Color(0xFFE8C84A),
                                ),
                                onPressed: () async {
                                  await widget.emu.library.toggleFavorite(g);
                                  await widget.emu.refreshLibrary();
                                },
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                await widget.emu.loadLibraryGame(g);
                              },
                              onLongPress: () async {
                                await widget.emu.library.remove(g);
                                await widget.emu.refreshLibrary();
                              },
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
}
