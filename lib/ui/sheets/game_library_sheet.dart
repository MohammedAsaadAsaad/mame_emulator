import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../emulator/emulator_controller.dart';
import '../../models/library_models.dart';
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

  Future<void> _confirmRemove(BuildContext context, LibraryGame game) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Remove from library?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '"${game.title}" will be removed from the library.\n'
          'The ROM file on disk is not deleted.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await widget.emu.library.remove(game);
    await widget.emu.refreshLibrary();
  }

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
                    g.path.toLowerCase().contains(q) ||
                    p.basename(g.path).toLowerCase().contains(q))
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
                  'Real titles + box art cache silently · ROMs stay on disk',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                ),
                const SizedBox(height: 10),
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search title or filename…',
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
                            'No games — Import a .zip or drop one here',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                          ),
                        )
                      : ListView.builder(
                          itemCount: games.length,
                          itemBuilder: (context, i) {
                            final g = games[i];
                            return ListTile(
                              leading: _GameArtThumb(game: g),
                              title: Text(
                                g.title,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                p.basename(g.path),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 11,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Favorite',
                                    icon: Icon(
                                      g.favorite ? Icons.star : Icons.star_border,
                                      color: const Color(0xFFE8C84A),
                                    ),
                                    onPressed: () async {
                                      await widget.emu.library.toggleFavorite(g);
                                      await widget.emu.refreshLibrary();
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Remove from library',
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () => _confirmRemove(context, g),
                                  ),
                                ],
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                await widget.emu.loadLibraryGame(g);
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

class _GameArtThumb extends StatelessWidget {
  const _GameArtThumb({required this.game});

  final LibraryGame game;

  @override
  Widget build(BuildContext context) {
    final path = game.artPath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 48,
        height: 48,
        child: path != null && File(path).existsSync()
            ? Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return const ColoredBox(
      color: Color(0xFF2A2A2A),
      child: Icon(Icons.videogame_asset, color: Color(0xFFE8C84A), size: 28),
    );
  }
}
