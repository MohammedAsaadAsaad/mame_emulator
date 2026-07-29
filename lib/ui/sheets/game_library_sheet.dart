import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../emulator/emulator_controller.dart';
import '../../models/library_models.dart';
import '../../utils/emulation_pause_guard.dart';

enum _LibraryViewMode { tiles, cards }

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
  static const _viewModePrefsKey = 'library_view_mode_v1';

  String _query = '';
  bool _favoritesOnly = false;
  _LibraryViewMode _viewMode = _LibraryViewMode.tiles;

  @override
  void initState() {
    super.initState();
    _loadViewMode();
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_viewModePrefsKey);
    if (!mounted) return;
    if (raw == 'cards') {
      setState(() => _viewMode = _LibraryViewMode.cards);
    }
  }

  Future<void> _setViewMode(_LibraryViewMode mode) async {
    setState(() => _viewMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _viewModePrefsKey,
      mode == _LibraryViewMode.cards ? 'cards' : 'tiles',
    );
  }

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

  Future<void> _playGame(BuildContext context, LibraryGame game) async {
    Navigator.pop(context);
    await widget.emu.loadLibraryGame(game);
  }

  void _showArtPreview(BuildContext context, LibraryGame game) {
    final artPath = game.artPath;
    final artFile = artPath != null ? File(artPath) : null;
    final hasArt = artFile != null && artFile.existsSync();

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.85,
                      maxHeight: MediaQuery.sizeOf(context).height * 0.65,
                    ),
                    child: hasArt
                        ? Image.file(
                            artFile,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => _previewPlaceholder(),
                          )
                        : _previewPlaceholder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  game.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap to close',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _previewPlaceholder() {
    return const SizedBox(
      width: 220,
      height: 220,
      child: ColoredBox(
        color: Color(0xFF2A2A2A),
        child: Icon(Icons.videogame_asset, color: Color(0xFFE8C84A), size: 72),
      ),
    );
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
                    const SizedBox(width: 8),
                    _ViewModeToggle(
                      mode: _viewMode,
                      onChanged: _setViewMode,
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
                      : _viewMode == _LibraryViewMode.tiles
                          ? _TilesList(
                              games: games,
                              onPlay: (g) => _playGame(context, g),
                              onPreviewArt: (g) => _showArtPreview(context, g),
                              onToggleFavorite: (g) async {
                                await widget.emu.library.toggleFavorite(g);
                                await widget.emu.refreshLibrary();
                              },
                              onRemove: (g) => _confirmRemove(context, g),
                            )
                          : _CardsGrid(
                              games: games,
                              onPlay: (g) => _playGame(context, g),
                              onToggleFavorite: (g) async {
                                await widget.emu.library.toggleFavorite(g);
                                await widget.emu.refreshLibrary();
                              },
                              onRemove: (g) => _confirmRemove(context, g),
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

class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({
    required this.mode,
    required this.onChanged,
  });

  final _LibraryViewMode mode;
  final ValueChanged<_LibraryViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeButton(
            icon: Icons.view_list,
            tooltip: 'Tiles',
            selected: mode == _LibraryViewMode.tiles,
            onTap: () => onChanged(_LibraryViewMode.tiles),
          ),
          _ModeButton(
            icon: Icons.grid_view,
            tooltip: 'Cards',
            selected: mode == _LibraryViewMode.cards,
            onTap: () => onChanged(_LibraryViewMode.cards),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE8C84A).withValues(alpha: 0.22) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: selected ? const Color(0xFFE8C84A) : Colors.white54,
          ),
        ),
      ),
    );
  }
}

class _TilesList extends StatelessWidget {
  const _TilesList({
    required this.games,
    required this.onPlay,
    required this.onPreviewArt,
    required this.onToggleFavorite,
    required this.onRemove,
  });

  final List<LibraryGame> games;
  final ValueChanged<LibraryGame> onPlay;
  final ValueChanged<LibraryGame> onPreviewArt;
  final ValueChanged<LibraryGame> onToggleFavorite;
  final ValueChanged<LibraryGame> onRemove;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: games.length,
      itemBuilder: (context, i) {
        final g = games[i];
        return ListTile(
          leading: Tooltip(
            message: 'Enlarge preview',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onPreviewArt(g),
                borderRadius: BorderRadius.circular(4),
                child: _GameArtThumb(game: g),
              ),
            ),
          ),
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
                onPressed: () => onToggleFavorite(g),
              ),
              IconButton(
                tooltip: 'Remove from library',
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                onPressed: () => onRemove(g),
              ),
            ],
          ),
          onTap: () => onPlay(g),
        );
      },
    );
  }
}

class _CardsGrid extends StatelessWidget {
  const _CardsGrid({
    required this.games,
    required this.onPlay,
    required this.onToggleFavorite,
    required this.onRemove,
  });

  final List<LibraryGame> games;
  final ValueChanged<LibraryGame> onPlay;
  final ValueChanged<LibraryGame> onToggleFavorite;
  final ValueChanged<LibraryGame> onRemove;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.7,
      ),
      itemCount: games.length,
      itemBuilder: (context, i) {
        final g = games[i];
        return _GameCard(
          game: g,
          onPlay: () => onPlay(g),
          onToggleFavorite: () => onToggleFavorite(g),
          onRemove: () => onRemove(g),
        );
      },
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.game,
    required this.onPlay,
    required this.onToggleFavorite,
    required this.onRemove,
  });

  final LibraryGame game;
  final VoidCallback onPlay;
  final VoidCallback onToggleFavorite;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF242424),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPlay,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _GameArtThumb(
                game: game,
                width: double.infinity,
                height: double.infinity,
                borderRadius: 0,
                iconSize: 36,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 2, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          game.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          p.basename(game.path),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Favorite',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: Icon(
                      game.favorite ? Icons.star : Icons.star_border,
                      color: const Color(0xFFE8C84A),
                      size: 18,
                    ),
                    onPressed: onToggleFavorite,
                  ),
                  IconButton(
                    tooltip: 'Remove from library',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    onPressed: onRemove,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameArtThumb extends StatelessWidget {
  const _GameArtThumb({
    required this.game,
    this.width = 48,
    this.height = 48,
    this.borderRadius = 4,
    this.iconSize = 28,
  });

  final LibraryGame game;
  final double width;
  final double height;
  final double borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final path = game.artPath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
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
    return ColoredBox(
      color: const Color(0xFF2A2A2A),
      child: Icon(Icons.videogame_asset, color: const Color(0xFFE8C84A), size: iconSize),
    );
  }
}
