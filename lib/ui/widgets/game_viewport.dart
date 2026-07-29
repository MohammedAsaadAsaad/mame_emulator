import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../emulator/emulator_controller.dart';
import '../../models/image_enhancement_mode.dart';
import '../../utils/platform_info.dart';
import '../theme/arcade_text.dart';
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

class AttractMenu extends StatefulWidget {
  const AttractMenu({super.key, required this.controller});

  final EmulatorController controller;

  @override
  State<AttractMenu> createState() => _AttractMenuState();
}

class _AttractMenuState extends State<AttractMenu> {
  final _scroll = ScrollController();

  EmulatorController get controller => widget.controller;

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

  void _ensureVisible() {
    if (!_scroll.hasClients || controller.games.isEmpty) return;
    const itemExtent = 40.0;
    final target = controller.menuIndex * itemExtent;
    final view = _scroll.position;
    if (target < view.pixels || target > view.pixels + view.viewportDimension - itemExtent) {
      _scroll.animateTo(
        target.clamp(0.0, view.maxScrollExtent),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 12),
          Expanded(
            child: games.isEmpty
                ? Center(
                    child: Text(
                      'NO GAMES\n\nImport · Drop .zip',
                      textAlign: TextAlign.center,
                      style: ArcadeText.dim(size: 8),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    itemCount: games.length,
                    itemExtent: 40,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemBuilder: (context, i) {
                      final g = games[i];
                      final selected = i == controller.menuIndex;
                      return GestureDetector(
                        onTap: () async {
                          controller.highlightMenu(i);
                          await controller.confirmMenuSelection();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 80),
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFE8C84A)
                                : Colors.transparent,
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
                                  color: selected
                                      ? Colors.black
                                      : const Color(0xFFE8C84A),
                                  size: 9,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  g.title.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ArcadeText.body(
                                    color: selected
                                        ? Colors.black
                                        : const Color(0xFFDDDDDD),
                                    size: 9,
                                  ),
                                ),
                              ),
                              if (g.favorite)
                                Text(
                                  '*',
                                  style: ArcadeText.body(
                                    color: selected
                                        ? Colors.black
                                        : const Color(0xFFE8C84A),
                                    size: 9,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
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
    );
  }
}

