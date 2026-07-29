import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../emulator/emulator_controller.dart';
import '../../models/image_enhancement_mode.dart';
import '../../models/library_models.dart';
import '../../utils/platform_info.dart';
import '../theme/arcade_text.dart';
import 'app_logo.dart';
import 'enhance_shader.dart';

/// CRT viewport — live frames when a ROM is running, else arcade game list.
class GameViewport extends StatelessWidget {
  const GameViewport({
    super.key,
    required this.controller,
    this.expand = false,
  });

  final EmulatorController controller;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final host = controller.host;
    final frame = host.frame;
    final toast = controller.toast;

    final screen = Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          child: frame != null
              ? _LiveFrame(controller: controller, image: frame)
              : AttractMenu(controller: controller),
        ),
        if (toast.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 18,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xCC000000),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0x88FFCC33)),
                ),
                child: Text(
                  toast,
                  style: ArcadeText.body(color: const Color(0xFFFFE08A), size: 9),
                ),
              ),
            ),
          ),
      ],
    );

    if (expand) {
      return ClipRect(child: screen);
    }

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: screen,
      ),
    );
  }
}

class _LiveFrame extends StatelessWidget {
  const _LiveFrame({required this.controller, required this.image});

  final EmulatorController controller;
  final ui.Image image;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final enhance = controller.shadersEnabled;
        final mode = controller.enhancementMode;

        if (!enhance) {
          return FittedBox(
            fit: BoxFit.contain,
            child: RawImage(
              image: image,
              filterQuality: FilterQuality.none,
            ),
          );
        }

        if (mode == ImageEnhancementMode.integerSharp) {
          return IntegerSharpFrame(
            image: image,
            maxWidth: maxW,
            maxHeight: maxH,
          );
        }

        final fitted = fitContain(
          Size(image.width.toDouble(), image.height.toDouble()),
          Size(maxW, maxH),
        );

        return Center(
          child: SizedBox(
            width: fitted.width,
            height: fitted.height,
            child: CustomPaint(
              size: fitted,
              painter: EnhancedFramePainter(
                image: image,
                outputSize: fitted,
                mode: mode,
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _AttractViewMode { tiles, cards }

class AttractMenu extends StatefulWidget {
  const AttractMenu({super.key, required this.controller});

  final EmulatorController controller;

  @override
  State<AttractMenu> createState() => _AttractMenuState();
}

class _AttractMenuState extends State<AttractMenu> {
  static const _viewModePrefsKey = 'attract_view_mode_v1';

  final _scroll = ScrollController();
  _AttractViewMode _viewMode = _AttractViewMode.tiles;
  LibraryGame? _previewGame;

  EmulatorController get controller => widget.controller;

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
      setState(() => _viewMode = _AttractViewMode.cards);
    }
  }

  Future<void> _setViewMode(_AttractViewMode mode) async {
    setState(() {
      _viewMode = mode;
      _previewGame = null;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _viewModePrefsKey,
      mode == _AttractViewMode.cards ? 'cards' : 'tiles',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible());
  }

  @override
  void didUpdateWidget(covariant AttractMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  double get _tileExtent => 48.0;

  void _ensureVisible() {
    if (!_scroll.hasClients || controller.games.isEmpty) return;
    final index = controller.menuIndex;

    if (_viewMode == _AttractViewMode.tiles) {
      final target = index * _tileExtent;
      final view = _scroll.position;
      if (target < view.pixels ||
          target > view.pixels + view.viewportDimension - _tileExtent) {
        _scroll.animateTo(
          target.clamp(0.0, view.maxScrollExtent),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      }
      return;
    }

    // Cards: approximate 2-column row height (~118) + spacing.
    const rowExtent = 128.0;
    final row = index ~/ 2;
    final target = row * rowExtent;
    final view = _scroll.position;
    if (target < view.pixels ||
        target > view.pixels + view.viewportDimension - rowExtent) {
      _scroll.animateTo(
        target.clamp(0.0, view.maxScrollExtent),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _playAt(int index) async {
    controller.highlightMenu(index);
    await controller.confirmMenuSelection();
  }

  void _showPreview(LibraryGame game) {
    setState(() => _previewGame = game);
  }

  void _hidePreview() {
    if (_previewGame == null) return;
    setState(() => _previewGame = null);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final games = controller.games;
        final booting = controller.booting;

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF142014), Color(0xFF050805), Color(0xFF000000)],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppLogo(size: 56)),
                  const SizedBox(height: 8),
                  Text(
                    'ARCADE CABINET',
                    textAlign: TextAlign.center,
                    style: ArcadeText.title(size: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    booting ? 'LOADING…' : 'SELECT GAME',
                    textAlign: TextAlign.center,
                    style: ArcadeText.body(color: const Color(0xFFFFEE88), size: 9),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    controller.status,
                    textAlign: TextAlign.center,
                    style: ArcadeText.dim(size: 7),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Spacer(),
                      _AttractViewToggle(
                        mode: _viewMode,
                        onChanged: _setViewMode,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: games.isEmpty
                        ? Center(
                            child: Text(
                              'NO GAMES\n\nImport · Drop .zip',
                              textAlign: TextAlign.center,
                              style: ArcadeText.dim(size: 8),
                            ),
                          )
                        : _viewMode == _AttractViewMode.tiles
                            ? _AttractTilesList(
                                scroll: _scroll,
                                games: games,
                                selectedIndex: controller.menuIndex,
                                itemExtent: _tileExtent,
                                onSelect: (i) => controller.highlightMenu(i),
                                onPlay: _playAt,
                                onPreview: _showPreview,
                              )
                            : _AttractCardsGrid(
                                scroll: _scroll,
                                games: games,
                                selectedIndex: controller.menuIndex,
                                onSelect: (i) => controller.highlightMenu(i),
                                onPlay: _playAt,
                              ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isDesktopPlatform
                        ? '↑↓ MOVE   A / START ENTER'
                        : '↑↓ MOVE   A / START',
                    textAlign: TextAlign.center,
                    style: ArcadeText.dim(size: 7),
                  ),
                ],
              ),
              if (_previewGame != null)
                _ArtPreviewOverlay(
                  game: _previewGame!,
                  onClose: _hidePreview,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AttractViewToggle extends StatelessWidget {
  const _AttractViewToggle({
    required this.mode,
    required this.onChanged,
  });

  final _AttractViewMode mode;
  final ValueChanged<_AttractViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A1A),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleBtn(
            icon: Icons.view_list,
            selected: mode == _AttractViewMode.tiles,
            onTap: () => onChanged(_AttractViewMode.tiles),
          ),
          _ToggleBtn(
            icon: Icons.grid_view,
            selected: mode == _AttractViewMode.cards,
            onTap: () => onChanged(_AttractViewMode.cards),
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ColoredBox(
        color: selected ? const Color(0xFFE8C84A) : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 14,
            color: selected ? Colors.black : const Color(0xFFE8C84A),
          ),
        ),
      ),
    );
  }
}

class _AttractTilesList extends StatelessWidget {
  const _AttractTilesList({
    required this.scroll,
    required this.games,
    required this.selectedIndex,
    required this.itemExtent,
    required this.onSelect,
    required this.onPlay,
    required this.onPreview,
  });

  final ScrollController scroll;
  final List<LibraryGame> games;
  final int selectedIndex;
  final double itemExtent;
  final ValueChanged<int> onSelect;
  final Future<void> Function(int index) onPlay;
  final ValueChanged<LibraryGame> onPreview;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scroll,
      itemCount: games.length,
      itemExtent: itemExtent,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, i) {
        final g = games[i];
        final selected = i == selectedIndex;
        return GestureDetector(
          onTap: () async {
            onSelect(i);
            await onPlay(i);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFE8C84A) : Colors.transparent,
              border: Border.all(
                color: selected
                    ? const Color(0xFFE8C84A)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Text(
                  selected ? '>' : ' ',
                  style: ArcadeText.body(
                    color: selected ? Colors.black : const Color(0xFFE8C84A),
                    size: 9,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    onSelect(i);
                    onPreview(g);
                  },
                  child: _BoxArtThumb(
                    game: g,
                    size: 36,
                    selected: selected,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    g.title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ArcadeText.body(
                      color: selected ? Colors.black : const Color(0xFFDDDDDD),
                      size: 9,
                    ),
                  ),
                ),
                if (g.favorite)
                  Text(
                    '*',
                    style: ArcadeText.body(
                      color: selected ? Colors.black : const Color(0xFFE8C84A),
                      size: 9,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AttractCardsGrid extends StatelessWidget {
  const _AttractCardsGrid({
    required this.scroll,
    required this.games,
    required this.selectedIndex,
    required this.onSelect,
    required this.onPlay,
  });

  final ScrollController scroll;
  final List<LibraryGame> games;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Future<void> Function(int index) onPlay;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: scroll,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 110,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.72,
      ),
      itemCount: games.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, i) {
        final g = games[i];
        final selected = i == selectedIndex;
        return GestureDetector(
          onTap: () async {
            onSelect(i);
            await onPlay(i);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFE8C84A)
                  : const Color(0xFF121A12),
              border: Border.all(
                color: selected
                    ? const Color(0xFFE8C84A)
                    : Colors.white.withValues(alpha: 0.1),
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _BoxArtThumb(
                    game: g,
                    size: double.infinity,
                    selected: selected,
                    fill: true,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
                  child: Row(
                    children: [
                      if (selected)
                        Text(
                          '>',
                          style: ArcadeText.body(color: Colors.black, size: 6),
                        ),
                      if (selected) const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          g.title.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ArcadeText.body(
                            color: selected ? Colors.black : const Color(0xFFDDDDDD),
                            size: 6,
                          ),
                        ),
                      ),
                      if (g.favorite)
                        Text(
                          '*',
                          style: ArcadeText.body(
                            color: selected ? Colors.black : const Color(0xFFE8C84A),
                            size: 6,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BoxArtThumb extends StatelessWidget {
  const _BoxArtThumb({
    required this.game,
    required this.size,
    required this.selected,
    this.fill = false,
  });

  final LibraryGame game;
  final double size;
  final bool selected;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final path = game.artPath;
    final hasArt = path != null && File(path).existsSync();
    final placeholder = ColoredBox(
      color: selected ? const Color(0xFF2A2208) : const Color(0xFF1A241A),
      child: Icon(
        Icons.videogame_asset,
        size: fill ? 28 : 18,
        color: selected ? Colors.black54 : const Color(0xFFE8C84A),
      ),
    );

    final image = hasArt
        ? Image.file(
            File(path),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
            errorBuilder: (_, _, _) => placeholder,
          )
        : placeholder;

    if (fill) {
      return image;
    }

    return SizedBox(
      width: size,
      height: size,
      child: image,
    );
  }
}

class _ArtPreviewOverlay extends StatelessWidget {
  const _ArtPreviewOverlay({
    required this.game,
    required this.onClose,
  });

  final LibraryGame game;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final path = game.artPath;
    final hasArt = path != null && File(path).existsSync();

    return Positioned.fill(
      child: GestureDetector(
        onTap: onClose,
        behavior: HitTestBehavior.opaque,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.88),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: hasArt
                          ? Image.file(
                              File(path),
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.none,
                              errorBuilder: (_, _, _) => _placeholder(),
                            )
                          : _placeholder(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  game.title.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ArcadeText.body(color: const Color(0xFFFFEE88), size: 9),
                ),
                const SizedBox(height: 6),
                Text(
                  'TAP TO CLOSE',
                  style: ArcadeText.dim(size: 7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return const ColoredBox(
      color: Color(0xFF1A241A),
      child: Icon(Icons.videogame_asset, color: Color(0xFFE8C84A), size: 48),
    );
  }
}
