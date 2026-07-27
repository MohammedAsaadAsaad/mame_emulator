import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../emulator/emulator_controller.dart';
import 'control_panel.dart';
import 'sheets/game_library_sheet.dart';
import 'sheets/key_bindings_sheet.dart';
import 'sheets/save_slots_sheet.dart';
import 'sheets/settings_sheets.dart';
import 'toolbar/emulator_toolbar.dart';
import 'widgets/game_viewport.dart';

class ArcadeCabinetPage extends StatefulWidget {
  const ArcadeCabinetPage({super.key});

  @override
  State<ArcadeCabinetPage> createState() => _ArcadeCabinetPageState();
}

class _ArcadeCabinetPageState extends State<ArcadeCabinetPage> {
  late final EmulatorController _emu;
  final FocusNode _focus = FocusNode();
  bool _fsChromeVisible = true;

  @override
  void initState() {
    super.initState();
    _emu = EmulatorController();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _emu.init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _emu.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    return _emu.handleKey(event) ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  Future<void> _onDrop(DropDoneDetails details) async {
    _emu.setDropHover(false);
    for (final file in details.files) {
      final path = file.path;
      if (path.isEmpty) continue;
      final lower = path.toLowerCase();
      if (lower.endsWith('.zip') || lower.endsWith('.7z')) {
        try {
          await _emu.loadRom(path);
        } catch (_) {}
        _focus.requestFocus();
        return;
      }
    }
    _emu.showToast('DROP A .ZIP ROM');
  }

  void _openLibrary() => GameLibrarySheet.show(context, _emu).then((_) => _focus.requestFocus());
  void _openSlots() => SaveSlotsSheet.show(context, _emu).then((_) => _focus.requestFocus());
  void _openKeys() => KeyBindingsSheet.show(context, _emu).then((_) => _focus.requestFocus());
  void _openSpeed() => SpeedSheet.show(context, _emu).then((_) => _focus.requestFocus());
  void _openSettings() => SettingsSheet.show(
        context,
        _emu,
        onLibrary: _openLibrary,
        onKeys: _openKeys,
        onSlots: _openSlots,
        onSpeed: _openSpeed,
      ).then((_) => _focus.requestFocus());

  Future<void> _import() async {
    await _emu.importRomsWithPicker();
    _focus.requestFocus();
  }

  Widget _viewport({required bool expand}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(expand ? 0 : 4),
        border: expand
            ? null
            : Border.all(
                color: _emu.dropHover
                    ? const Color(0xFFE8C84A)
                    : const Color(0xFF333333),
                width: _emu.dropHover ? 3 : 2,
              ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GameViewport(controller: _emu, expand: expand),
          if (_emu.hasGame && !_emu.isRunning)
            Positioned.fill(
              child: GestureDetector(
                onTap: _emu.resumeEmulation,
                child: ColoredBox(
                  color: const Color(0x88000000),
                  child: Center(
                    child: Text(
                      'PAUSED — TAP OR SPACE',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _focus.requestFocus();
          if (_emu.isFullscreen || isCompactLandscape(context)) {
            setState(() => _fsChromeVisible = !_fsChromeVisible);
          }
        },
        child: DropTarget(
          onDragEntered: (_) => _emu.setDropHover(true),
          onDragExited: (_) => _emu.setDropHover(false),
          onDragDone: _onDrop,
          child: Scaffold(
            backgroundColor: const Color(0xFF0D0D0D),
            body: AnimatedBuilder(
              animation: _emu,
              builder: (context, _) {
                final fs = _emu.isFullscreen;
                final landscape =
                    MediaQuery.orientationOf(context) == Orientation.landscape;
                final compactLand = isCompactLandscape(context);
                final showPad = _emu.showOnScreenPad && (!fs || _fsChromeVisible);
                // Small landscape: game fills screen; chrome/toolbar stay overlays.
                final immersiveLand = landscape && compactLand;
                final showTopBar = !fs && !immersiveLand;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Column(
                      children: [
                        if (showTopBar) SizedBox(height: MediaQuery.paddingOf(context).top),
                        if (showTopBar)
                          EmulatorToolbar(
                            controller: _emu,
                            onLibrary: _openLibrary,
                            onImport: _import,
                            onSlots: _openSlots,
                            onKeys: _openKeys,
                            onSpeed: _openSpeed,
                            onSettings: _openSettings,
                          ),
                        Expanded(
                          child: immersiveLand
                              ? _CompactLandscapePlayfield(
                                  showPad: showPad,
                                  viewport: _viewport(expand: true),
                                  controller: _emu,
                                )
                              : landscape && showPad
                                  ? Row(
                                      children: [
                                        LandscapeLeftControls(controller: _emu),
                                        Expanded(
                                          child: ColoredBox(
                                            color: const Color(0xFF050505),
                                            child: Padding(
                                              padding: EdgeInsets.all(fs ? 0 : 6),
                                              child: _viewport(expand: true),
                                            ),
                                          ),
                                        ),
                                        LandscapeRightControls(controller: _emu),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            width: double.infinity,
                                            color: const Color(0xFF050505),
                                            padding: EdgeInsets.fromLTRB(
                                              fs ? 0 : 6,
                                              fs ? 0 : 6,
                                              fs ? 0 : 6,
                                              fs ? 0 : 4,
                                            ),
                                            child: _viewport(expand: fs || landscape),
                                          ),
                                        ),
                                        if (showPad) ControlPanel(controller: _emu),
                                      ],
                                    ),
                        ),
                      ],
                    ),
                    if ((fs || immersiveLand) && _fsChromeVisible)
                      Positioned(
                        top: MediaQuery.paddingOf(context).top,
                        left: 0,
                        right: 0,
                        child: EmulatorToolbar(
                          controller: _emu,
                          compact: true,
                          onLibrary: _openLibrary,
                          onImport: _import,
                          onSlots: _openSlots,
                          onKeys: _openKeys,
                          onSpeed: _openSpeed,
                          onSettings: _openSettings,
                        ),
                      ),
                    if (fs)
                      Positioned(
                        top: 10 + MediaQuery.paddingOf(context).top,
                        right: 10,
                        child: Material(
                          color: const Color(0xCC222222),
                          borderRadius: BorderRadius.circular(8),
                          child: IconButton(
                            tooltip: 'Exit fullscreen (F11 / Esc)',
                            onPressed: _emu.exitFullscreen,
                            icon: const Icon(Icons.fullscreen_exit, color: Color(0xFFE8C84A)),
                          ),
                        ),
                      ),
                    if (_emu.dropHover)
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(
                            color: Color(0x88000000),
                            child: Center(
                              child: Text(
                                'DROP ROM .ZIP TO LOAD',
                                style: TextStyle(
                                  color: Color(0xFFE8C84A),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
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

/// Small-screen landscape: game edge-to-edge with translucent control overlays.
class _CompactLandscapePlayfield extends StatelessWidget {
  const _CompactLandscapePlayfield({
    required this.showPad,
    required this.viewport,
    required this.controller,
  });

  final bool showPad;
  final Widget viewport;
  final EmulatorController controller;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: viewport),
          if (showPad) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: LandscapeLeftControls(
                controller: controller,
                overlay: true,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: LandscapeRightControls(
                controller: controller,
                overlay: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
