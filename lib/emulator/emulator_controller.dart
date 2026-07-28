import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../audio/arcade_audio.dart';
import '../controllers/input_mapper.dart';
import '../controllers/key_binding_controller.dart';
import '../libretro/libretro_bindings.dart';
import '../libretro/libretro_host.dart';
import '../models/image_enhancement_mode.dart';
import '../models/library_models.dart';
import '../services/game_metadata_service.dart';
import '../services/rom_library_service.dart';
import '../services/system_bios_service.dart';
import '../ui/widgets/enhance_shader.dart';
import '../utils/platform_info.dart';

enum PadButton { a, b, c, d }

/// Comprehensive arcade cabinet controller (NES frontend patterns + libretro).
class EmulatorController extends ChangeNotifier {
  EmulatorController() {
    _host.addListener(_onHost);
    _host.audio = audio;
  }

  final LibretroHost _host = LibretroHost();
  final KeyBindingController keyBindings = KeyBindingController();
  final RomLibraryService library = RomLibraryService();
  final GameMetadataService metadata = GameMetadataService();
  final ArcadeAudio audio = ArcadeAudio();

  String toast = '';
  int saveSlot = 1;
  static const int maxSlots = 10;
  static const List<double> speedPresets = [0.5, 0.75, 1.0, 1.25, 1.5];

  bool booting = false;
  bool dropHover = false;
  bool showOnScreenPad = true;
  bool isFullscreen = false;
  double emulationSpeed = 1.0;

  /// Display shaders (NES-style CRT / upscale). Off by default.
  bool shadersEnabled = false;
  ImageEnhancementMode enhancementMode = ImageEnhancementMode.crtArcade;

  /// Sound on/off and master volume (0–1).
  bool soundEnabled = true;
  double soundVolume = 0.85;

  final Set<int> _keyDirs = {};
  double _stickX = 0;
  double _stickY = 0;
  Timer? _toastTimer;
  List<SaveSlotInfo> saveSlots = const [];
  List<LibraryGame> games = const [];

  /// Highlighted game on the attract menu (D-pad / stick).
  int menuIndex = 0;
  int _menuStickLatch = 0; // -1 up, 1 down, 0 neutral
  DateTime? _menuNavAt;

  LibretroHost get host => _host;
  bool get hasGame => _host.isGameLoaded;
  bool get isRunning => _host.isRunning;
  String get status => _host.status;
  bool get inGameMenu => !_host.isGameLoaded;

  void _onHost() => notifyListeners();

  Future<void> init() async {
    await CoreLocator.init();
    final biosCount = await SystemBiosService.installBundledAssets();
    if (biosCount > 0) {
      debugPrint('Installed $biosCount BIOS archive(s) from assets/bios/');
    }
    await keyBindings.load();
    await _loadSpeed();
    await _loadShaderPrefs();
    await _loadSoundPrefs();
    await audio.initialize();
    audio.setEnabled(soundEnabled);
    audio.setVolume(soundVolume);
    unawaited(EnhanceShader.warmUp());
    games = await library.loadAll();
    _clampMenuIndex();
    unawaited(_enrichLibraryMetadata());
    // Do not block UI on opening a 40–70MB .so — load core when a ROM is chosen.
    final core = CoreLocator.bestArcadeCore();
    if (core == null || !CoreLocator.libraryExists(CoreLocator.helpersName)) {
      _host.status = 'Setup needed — see status below';
      _flash('CORE PATH ISSUE');
      debugPrint(CoreLocator.diagnose());
    } else {
      _host.status = games.isEmpty
          ? 'Import or drop a .zip'
          : '↑↓ select · A / START play';
    }
    notifyListeners();
  }

  Future<void> _loadSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    emulationSpeed = prefs.getDouble('emulation_speed') ?? 1.0;
  }

  Future<void> _loadSoundPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    soundEnabled = prefs.getBool('sound_enabled') ?? true;
    soundVolume = (prefs.getDouble('sound_volume') ?? 0.85).clamp(0.0, 1.0);
  }

  Future<void> setSoundEnabled(bool enabled) async {
    soundEnabled = enabled;
    audio.setEnabled(enabled);
    if (enabled && _host.isRunning) audio.resume();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', enabled);
    _flash(enabled ? 'SOUND ON' : 'SOUND OFF');
    notifyListeners();
  }

  void toggleSound() => setSoundEnabled(!soundEnabled);

  Future<void> setSoundVolume(double volume) async {
    soundVolume = volume.clamp(0.0, 1.0);
    audio.setVolume(soundVolume);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('sound_volume', soundVolume);
    _flash('VOL ${(soundVolume * 100).round()}%');
    notifyListeners();
  }

  void volumeUp() => setSoundVolume(soundVolume + 0.1);

  void volumeDown() => setSoundVolume(soundVolume - 0.1);

  Future<void> _loadShaderPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    shadersEnabled = prefs.getBool('shaders_enabled') ?? false;
    enhancementMode = ImageEnhancementMode.fromId(
          prefs.getString('enhancement_mode'),
        ) ??
        ImageEnhancementMode.crtArcade;
  }

  Future<void> setShadersEnabled(bool enabled) async {
    shadersEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shaders_enabled', enabled);
    _flash(enabled ? 'SHADERS ON' : 'SHADERS OFF');
    notifyListeners();
  }

  void toggleShaders() => setShadersEnabled(!shadersEnabled);

  Future<void> setEnhancementMode(ImageEnhancementMode mode) async {
    enhancementMode = mode;
    shadersEnabled = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('enhancement_mode', mode.id);
    await prefs.setBool('shaders_enabled', true);
    _flash(mode.shortLabel);
    notifyListeners();
  }

  void cycleEnhancementMode() {
    final modes = ImageEnhancementMode.values;
    final next = modes[(modes.indexOf(enhancementMode) + 1) % modes.length];
    unawaited(setEnhancementMode(next));
  }

  Future<void> setEmulationSpeed(double speed) async {
    emulationSpeed = speed.clamp(0.25, 2.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('emulation_speed', emulationSpeed);
    if (_host.isGameLoaded && _host.isRunning) {
      _host.start(speed: emulationSpeed);
    }
    _flash('SPEED ${emulationSpeed.toStringAsFixed(2)}×');
    notifyListeners();
  }

  Future<void> ensureCore({String? romPath}) async {
    final basename = romPath != null ? p.basename(romPath) : null;
    final core = CoreLocator.bestArcadeCore(romBasename: basename);
    if (core == null) {
      final msg = 'No core found.\n${CoreLocator.diagnose()}';
      _host.status = msg;
      _flash('NO CORE FOUND');
      notifyListeners();
      throw StateError(msg);
    }
    if (!CoreLocator.libraryExists(CoreLocator.helpersName)) {
      final msg = Platform.isAndroid
          ? 'Missing libhost_helpers.so in APK (rebuild with NDK)'
          : Platform.isWindows
              ? 'Missing host_helpers.dll — run scripts/fetch_windows_cores.ps1'
              : 'Missing libhost_helpers.so — run ./scripts/build_helpers.sh';
      _host.status = msg;
      _flash('HELPERS MISSING');
      notifyListeners();
      throw StateError(msg);
    }

    final wantFbneo = CoreLocator.prefersFbneo(basename);
    final haveFbneo = (_host.coreName ?? '').toLowerCase().contains('neo');
    if (_host.coreName != null && wantFbneo == haveFbneo) return;

    booting = true;
    notifyListeners();
    try {
      await _host.loadCore(core);
      _flash('CORE: ${_host.coreName}');
    } catch (e) {
      _host.status = 'Core load failed: $e';
      _flash('CORE LOAD FAILED');
      rethrow;
    } finally {
      booting = false;
      notifyListeners();
    }
  }

  Future<void> loadRom(String path) async {
    final lower = path.toLowerCase();
    if (!lower.endsWith('.zip') && !lower.endsWith('.7z')) {
      _flash('NEED A .ZIP ROM');
      notifyListeners();
      return;
    }
    if (!File(path).existsSync()) {
      _flash('ROM NOT FOUND');
      notifyListeners();
      return;
    }

    if (SystemBiosService.isBiosArchive(path)) {
      await SystemBiosService.installBiosArchive(path);
      _host.status =
          'Installed ${p.basename(path)} → ${CoreLocator.supportDir}';
      _flash('BIOS INSTALLED');
      notifyListeners();
      return;
    }

    booting = true;
    notifyListeners();
    try {
      final game = await library.importPath(path);
      final libraryDirs = (await library.loadAll())
          .map((g) => p.dirname(g.path))
          .toSet();
      // Install personal assets/bios/ silently (Neo Geo, CPS keys, …).
      // Player never picks BIOS — only chooses a game.
      await SystemBiosService.installBundledAssets();
      final bios = await SystemBiosService.ensureForRom(
        game.path,
        extraDirs: libraryDirs,
      );
      if (bios.needsNeogeo && !bios.hasNeogeo) {
        // Bundled BIOS missing from this build — do not open a file picker.
        _host.status = SystemBiosService.missingNeogeoMessage(bios);
        _flash('CANNOT START');
        notifyListeners();
        return;
      }
      if (bios.biosArchivesInstalled > 0) {
        _flash('BIOS READY');
      }
      // CPS-2 etc.: place `{game}.key` beside the ROM from system dir / assets/bios/.
      final hadKey = await SystemBiosService.ensureKeyBesideRom(game.path);
      if (!hadKey) {
        final stem = CoreLocator.romStem(p.basename(game.path));
        debugPrint(
          'No $stem.key beside ROM or in assets/bios/ — '
          'CPS-2 sets need this file (FBNeo will error if required).',
        );
      }
      await ensureCore(romPath: game.path);
      try {
        await _host.loadGame(game.path);
      } catch (first) {
        final alt = CoreLocator.alternateArcadeCore(
          romBasename: p.basename(game.path),
        );
        if (alt == null) rethrow;
        debugPrint('Primary core failed ($first); retrying alternate…');
        _flash('RETRY OTHER CORE');
        notifyListeners();
        await _host.loadCore(alt);
        await _host.loadGame(game.path);
        _flash('CORE: ${_host.coreName}');
      }
      _host.start(speed: emulationSpeed);
      await library.markPlayed(game);
      games = await library.loadAll();
      await refreshSaveSlots();
      _flash('LOADED ${game.title}');
    } catch (e) {
      debugPrint('loadRom failed: $e\n${CoreLocator.diagnose()}');
      _flash('LOAD FAILED');
      if (_host.status.startsWith('No core') || _host.status.startsWith('Ready')) {
        _host.status = 'Load failed: $e';
      }
    } finally {
      booting = false;
      notifyListeners();
    }
  }

  Future<void> loadLibraryGame(LibraryGame game) => loadRom(game.path);

  Future<void> refreshLibrary() async {
    games = await library.loadAll();
    _clampMenuIndex();
    notifyListeners();
    unawaited(_enrichLibraryMetadata());
  }

  Future<void> _enrichLibraryMetadata() async {
    if (games.isEmpty) return;
    await metadata.enrichGames(
      games,
      persist: library.saveAll,
      onChanged: notifyListeners,
    );
  }

  void _clampMenuIndex() {
    if (games.isEmpty) {
      menuIndex = 0;
      return;
    }
    menuIndex = menuIndex.clamp(0, games.length - 1);
  }

  void moveMenu(int delta) {
    if (!inGameMenu || games.isEmpty) return;
    final now = DateTime.now();
    if (_menuNavAt != null &&
        now.difference(_menuNavAt!) < const Duration(milliseconds: 140)) {
      return;
    }
    _menuNavAt = now;
    menuIndex = (menuIndex + delta).clamp(0, games.length - 1);
    notifyListeners();
  }

  void highlightMenu(int index) {
    if (games.isEmpty) return;
    menuIndex = index.clamp(0, games.length - 1);
    notifyListeners();
  }

  Future<void> confirmMenuSelection() async {
    if (!inGameMenu || games.isEmpty) return;
    await loadRom(games[menuIndex].path);
  }

  Future<void> importRomsWithPicker() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['zip', '7z'],
    );
    if (result == null || result.files.isEmpty) return;
    String? first;
    for (final f in result.files) {
      final path = f.path;
      if (path == null) continue;
      // Index original path only — never copy the ROM into app storage.
      await library.importPath(path);
      first ??= path;
    }
    games = await library.loadAll();
    notifyListeners();
    if (first != null) await loadRom(first);
  }

  /// Scan a folder and index all .zip/.7z ROMs in place (no copy).
  Future<void> scanFolderWithPicker() async {
    final path = await FilePicker.getDirectoryPath(dialogTitle: 'Select ROM folder');
    if (path == null) return;
    final added = await library.scanFolder(path);
    final bios = await SystemBiosService.provisionFromDirs([path]);
    games = await library.loadAll();
    if (bios > 0 && added > 0) {
      _flash('INDEXED $added + BIOS');
    } else if (bios > 0) {
      _flash('BIOS INSTALLED');
    } else {
      _flash(added > 0 ? 'INDEXED $added ROMS' : 'NO NEW ROMS');
    }
    notifyListeners();
  }

  Future<void> loadRomFromRomsFolder() async {
    games = await library.loadAll();
    if (games.isEmpty) {
      _flash('LIBRARY EMPTY — IMPORT OR DROP');
      notifyListeners();
      return;
    }
    final preferred = games.cast<LibraryGame?>().firstWhere(
          (g) => g!.title.toLowerCase().startsWith('dino'),
          orElse: () => null,
        ) ??
        games.first;
    await loadRom(preferred.path);
  }

  void setDropHover(bool hovering) {
    if (dropHover == hovering) return;
    dropHover = hovering;
    notifyListeners();
  }

  void showToast(String text) => _flash(text);

  void toggleOnScreenPad() {
    showOnScreenPad = !showOnScreenPad;
    notifyListeners();
  }

  bool get _isDesktop => isDesktopPlatform;

  Future<void> toggleFullscreen() async {
    try {
      if (_isDesktop) {
        final next = !await windowManager.isFullScreen();
        await windowManager.setFullScreen(next);
        isFullscreen = next;
      } else {
        isFullscreen = !isFullscreen;
      }
      if (isFullscreen) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        _flash(_isDesktop ? 'FULLSCREEN — F11 / ESC' : 'FULLSCREEN');
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        _flash('WINDOWED');
      }
    } catch (e) {
      // Fallback: UI-only fullscreen layout if window_manager fails.
      isFullscreen = !isFullscreen;
      _flash(isFullscreen ? 'FULLSCREEN (UI)' : 'WINDOWED');
    }
    notifyListeners();
  }

  Future<void> exitFullscreen() async {
    if (!isFullscreen) return;
    try {
      if (_isDesktop && await windowManager.isFullScreen()) {
        await windowManager.setFullScreen(false);
      }
    } catch (_) {}
    isFullscreen = false;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    notifyListeners();
  }

  // —— Emulation control (NES-style) ——

  void pauseEmulation() {
    _host.pause();
    _flash('PAUSED');
    notifyListeners();
  }

  void resumeEmulation() {
    if (!_host.isGameLoaded) return;
    _host.start(speed: emulationSpeed);
    _flash('RESUMED');
    notifyListeners();
  }

  void togglePause() {
    if (!_host.isGameLoaded) return;
    if (_host.isRunning) {
      pauseEmulation();
    } else {
      resumeEmulation();
    }
  }

  void resetEmulation() {
    if (!_host.isGameLoaded) return;
    _host.reset();
    if (!_host.isRunning) {
      _host.start(speed: emulationSpeed);
    }
    _flash('RESET');
    notifyListeners();
  }

  void insertCoin() {
    audio.resume(); // unlock audio on mobile after a user gesture
    _tap(RETRO_DEVICE_ID_JOYPAD_SELECT);
    _flash('COIN');
  }

  void pressStart() {
    audio.resume();
    if (inGameMenu) {
      unawaited(confirmMenuSelection());
      return;
    }
    _tap(RETRO_DEVICE_ID_JOYPAD_START);
    _flash('START');
  }

  void exitToAttract() {
    unawaited(_host.unload().then((_) async {
      games = await library.loadAll();
      _clampMenuIndex();
      _flash('SELECT A GAME');
      notifyListeners();
    }));
  }

  void openOptions() {
    unawaited(loadRomFromRomsFolder());
  }

  void cycleSlot([int delta = 1]) {
    saveSlot = ((saveSlot - 1 + delta) % maxSlots) + 1;
    _flash('SAVE SLOT $saveSlot');
    notifyListeners();
  }

  Future<void> refreshSaveSlots() async {
    final rom = _host.romPath;
    if (rom == null) {
      saveSlots = List.generate(
        maxSlots,
        (i) => SaveSlotInfo(slot: i + 1, occupied: false),
      );
      notifyListeners();
      return;
    }
    final dir = await library.saveStatesDir();
    final thumbs = await library.thumbnailsDir();
    final id = RomLibraryService.idForPath(rom);
    final slots = <SaveSlotInfo>[];
    for (var i = 1; i <= maxSlots; i++) {
      final file = File(p.join(dir.path, '${id}_slot_$i.state'));
      final meta = File(p.join(dir.path, '${id}_slot_$i.json'));
      final thumb = File(p.join(thumbs.path, '${id}_slot_$i.png'));
      DateTime? at;
      String? name;
      if (await meta.exists()) {
        try {
          final m = jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
          at = DateTime.tryParse(m['savedAt'] as String? ?? '');
          name = m['romName'] as String?;
        } catch (_) {}
      }
      slots.add(SaveSlotInfo(
        slot: i,
        occupied: await file.exists(),
        savedAt: at,
        romName: name,
        thumbnailPath: await thumb.exists() ? thumb.path : null,
        thumbnailRevision: await thumb.exists()
            ? (await thumb.lastModified()).millisecondsSinceEpoch
            : at?.millisecondsSinceEpoch,
      ));
    }
    saveSlots = slots;
    notifyListeners();
  }

  Future<void> saveState({int? slot}) async {
    final s = slot ?? saveSlot;
    if (!_host.isGameLoaded) {
      _flash('NO GAME LOADED');
      notifyListeners();
      return;
    }
    try {
      final data = await _host.serialize();
      if (data == null) {
        _flash('CORE HAS NO STATE');
        notifyListeners();
        return;
      }
      final dir = await library.saveStatesDir();
      final thumbs = await library.thumbnailsDir();
      final id = RomLibraryService.idForPath(_host.romPath!);
      await File(p.join(dir.path, '${id}_slot_$s.state')).writeAsBytes(data, flush: true);
      await File(p.join(dir.path, '${id}_slot_$s.json')).writeAsString(jsonEncode({
        'savedAt': DateTime.now().toIso8601String(),
        'romName': p.basename(_host.romPath!),
        'romPath': _host.romPath,
      }));
      final thumbFile = File(p.join(thumbs.path, '${id}_slot_$s.png'));
      // Drop Flutter's Image.file decode cache before overwrite.
      await FileImage(thumbFile).evict();
      await _captureThumbnail(thumbFile);
      await FileImage(thumbFile).evict();
      saveSlot = s;
      await refreshSaveSlots();
      _flash('STATE SAVED → SLOT $s');
    } catch (_) {
      _flash('SAVE FAILED');
    }
    notifyListeners();
  }

  Future<void> loadState({int? slot}) async {
    final s = slot ?? saveSlot;
    if (!_host.isGameLoaded) {
      _flash('NO GAME LOADED');
      notifyListeners();
      return;
    }
    try {
      final dir = await library.saveStatesDir();
      final id = RomLibraryService.idForPath(_host.romPath!);
      final file = File(p.join(dir.path, '${id}_slot_$s.state'));
      if (!await file.exists()) {
        _flash('SLOT $s EMPTY');
        notifyListeners();
        return;
      }
      final ok = await _host.unserialize(await file.readAsBytes());
      saveSlot = s;
      _flash(ok ? 'STATE LOADED ← SLOT $s' : 'LOAD FAILED');
    } catch (_) {
      _flash('LOAD FAILED');
    }
    notifyListeners();
  }

  Future<void> deleteSaveSlot(int slot) async {
    final rom = _host.romPath;
    if (rom == null) return;
    final dir = await library.saveStatesDir();
    final thumbs = await library.thumbnailsDir();
    final id = RomLibraryService.idForPath(rom);
    final state = File(p.join(dir.path, '${id}_slot_$slot.state'));
    final meta = File(p.join(dir.path, '${id}_slot_$slot.json'));
    final thumb = File(p.join(thumbs.path, '${id}_slot_$slot.png'));
    if (await state.exists()) await state.delete();
    if (await meta.exists()) await meta.delete();
    if (await thumb.exists()) await thumb.delete();
    await refreshSaveSlots();
    _flash('SLOT $slot CLEARED');
  }

  Future<void> _captureThumbnail(File dest) async {
    final image = _host.frame;
    if (image == null) return;
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      await dest.parent.create(recursive: true);
      await dest.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    } catch (_) {}
  }

  void setStick(double x, double y) {
    _stickX = x;
    _stickY = y;
    if (inGameMenu) {
      _menuFromStick(y);
      return;
    }
    _applyDirections();
  }

  void _menuFromStick(double y) {
    final dir = y < -0.45 ? -1 : (y > 0.45 ? 1 : 0);
    if (dir == 0) {
      _menuStickLatch = 0;
      return;
    }
    if (dir == _menuStickLatch) return;
    _menuStickLatch = dir;
    moveMenu(dir);
  }

  void buttonDown(PadButton button) {
    if (inGameMenu) {
      if (button == PadButton.a) unawaited(confirmMenuSelection());
      return;
    }
    _host.setButton(_map(button), true);
  }

  void buttonUp(PadButton button) {
    if (inGameMenu) return;
    _host.setButton(_map(button), false);
  }

  /// Keyboard via remappable bindings (NES KeyBindingController pattern).
  bool handleKey(KeyEvent event) {
    final key = event.logicalKey;

    // Host hotkeys (not remappable)
    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.f11 ||
          (key == LogicalKeyboardKey.enter &&
              HardwareKeyboard.instance.isAltPressed)) {
        unawaited(toggleFullscreen());
        return true;
      }
      if (key == LogicalKeyboardKey.escape) {
        if (isFullscreen) {
          unawaited(exitFullscreen());
          return true;
        }
        exitToAttract();
        return true;
      }
    }

    final action = keyBindings.actionForKey(key);
    if (action == null) return false;

    final down = event is KeyDownEvent || event is KeyRepeatEvent;
    final up = event is KeyUpEvent;

    switch (action) {
      case ControlAction.up:
      case ControlAction.down:
      case ControlAction.left:
      case ControlAction.right:
        if (inGameMenu) {
          if (event is KeyDownEvent || event is KeyRepeatEvent) {
            if (action == ControlAction.up) moveMenu(-1);
            if (action == ControlAction.down) moveMenu(1);
          }
          return true;
        }
        final id = _dirId(action)!;
        if (down) {
          _keyDirs.add(id);
        } else if (up) {
          _keyDirs.remove(id);
        }
        _applyDirections();
        return true;
      case ControlAction.a:
      case ControlAction.b:
      case ControlAction.c:
      case ControlAction.d:
        final pad = switch (action) {
          ControlAction.a => PadButton.a,
          ControlAction.b => PadButton.b,
          ControlAction.c => PadButton.c,
          _ => PadButton.d,
        };
        if (down && event is! KeyRepeatEvent) buttonDown(pad);
        if (up) buttonUp(pad);
        return true;
      case ControlAction.coin:
        if (event is KeyDownEvent) insertCoin();
        return true;
      case ControlAction.start:
        if (event is KeyDownEvent) pressStart();
        return true;
      case ControlAction.saveState:
        if (event is KeyDownEvent) unawaited(saveState());
        return true;
      case ControlAction.loadState:
        if (event is KeyDownEvent) unawaited(loadState());
        return true;
      case ControlAction.pause:
        if (event is KeyDownEvent) togglePause();
        return true;
      case ControlAction.reset:
        if (event is KeyDownEvent) resetEmulation();
        return true;
      case ControlAction.slotPrev:
        if (event is KeyDownEvent) cycleSlot(-1);
        return true;
      case ControlAction.slotNext:
        if (event is KeyDownEvent) cycleSlot(1);
        return true;
    }
  }

  int? _dirId(ControlAction a) => switch (a) {
        ControlAction.up => RETRO_DEVICE_ID_JOYPAD_UP,
        ControlAction.down => RETRO_DEVICE_ID_JOYPAD_DOWN,
        ControlAction.left => RETRO_DEVICE_ID_JOYPAD_LEFT,
        ControlAction.right => RETRO_DEVICE_ID_JOYPAD_RIGHT,
        _ => null,
      };

  void _applyDirections() {
    _host.setButton(
      RETRO_DEVICE_ID_JOYPAD_LEFT,
      _stickX < -0.22 || _keyDirs.contains(RETRO_DEVICE_ID_JOYPAD_LEFT),
    );
    _host.setButton(
      RETRO_DEVICE_ID_JOYPAD_RIGHT,
      _stickX > 0.22 || _keyDirs.contains(RETRO_DEVICE_ID_JOYPAD_RIGHT),
    );
    _host.setButton(
      RETRO_DEVICE_ID_JOYPAD_UP,
      _stickY < -0.22 || _keyDirs.contains(RETRO_DEVICE_ID_JOYPAD_UP),
    );
    _host.setButton(
      RETRO_DEVICE_ID_JOYPAD_DOWN,
      _stickY > 0.22 || _keyDirs.contains(RETRO_DEVICE_ID_JOYPAD_DOWN),
    );
  }

  int _map(PadButton button) => switch (button) {
        PadButton.a => RETRO_DEVICE_ID_JOYPAD_B,
        PadButton.b => RETRO_DEVICE_ID_JOYPAD_A,
        PadButton.c => RETRO_DEVICE_ID_JOYPAD_Y,
        PadButton.d => RETRO_DEVICE_ID_JOYPAD_X,
      };

  void _tap(int id) {
    _host.setButton(id, true);
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      _host.setButton(id, false);
    });
  }

  void _flash(String text) {
    toast = text;
    notifyListeners();
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 1400), () {
      if (toast == text) {
        toast = '';
        notifyListeners();
      }
    });
  }

  @override
  @override
  void dispose() {
    _toastTimer?.cancel();
    _host.removeListener(_onHost);
    _host.dispose();
    unawaited(audio.dispose());
    super.dispose();
  }
}
