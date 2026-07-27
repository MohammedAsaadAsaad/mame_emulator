import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'libretro_bindings.dart';

/// Hosts a libretro arcade core (FBNeo / MAME2003+) and exposes frames + input.
class LibretroHost extends ChangeNotifier {
  LibretroHost();

  LibretroBindings? _b;
  DynamicLibrary? _lib;

  NativeCallable<RetroEnvironmentNative>? _envCb;
  NativeCallable<RetroVideoRefreshNative>? _videoCb;
  NativeCallable<RetroAudioSampleNative>? _audioCb;
  NativeCallable<RetroAudioSampleBatchNative>? _audioBatchCb;
  NativeCallable<RetroInputPollNative>? _pollCb;
  NativeCallable<RetroInputStateNative>? _stateCb;

  Pointer<Utf8>? _systemDir;
  Pointer<Utf8>? _saveDir;
  Pointer<Utf8>? _gamePath; // must stay alive while game is loaded
  Pointer<Void>? _logFn;
  DynamicLibrary? _helpers;

  int _pixelFormat = RETRO_PIXEL_FORMAT_RGB565;
  final Map<int, bool> _buttons = {};
  bool _running = false;
  bool _gameLoaded = false;
  Timer? _ticker;
  String? coreName;
  String? romPath;
  String status = 'No core loaded';

  ui.Image? frame;
  int frameWidth = 0;
  int frameHeight = 0;
  double fps = 60;
  int videoCallbacks = 0;
  bool _frameDirty = false;
  Uint8List? _rgba;
  bool _buildingImage = false;

  bool get isGameLoaded => _gameLoaded;
  bool get isRunning => _running;

  Future<void> loadCore(String corePath) async {
    await unload();
    final resolved = CoreLocator.resolveLibraryPath(corePath);
    if (resolved == null) {
      status = 'Core not found: $corePath';
      notifyListeners();
      throw StateError(status);
    }

    status = 'Opening ${p.basename(resolved)}…';
    notifyListeners();

    try {
      _lib = DynamicLibrary.open(resolved);
    } catch (e) {
      status = 'Failed to open core: $e';
      notifyListeners();
      rethrow;
    }
    _b = LibretroBindings(_lib!);

    final version = _b!.retro_api_version();
    if (version < 1) {
      throw StateError('Unsupported libretro API $version');
    }

    final support = Directory(CoreLocator.supportDir);
    final saves = Directory(CoreLocator.savesDir);
    support.createSync(recursive: true);
    saves.createSync(recursive: true);
    Directory(p.join(saves.path, 'nvram')).createSync(recursive: true);
    Directory(p.join(saves.path, 'cfg')).createSync(recursive: true);
    _systemDir = support.absolute.path.toNativeUtf8();
    _saveDir = saves.absolute.path.toNativeUtf8();

    final helperPath = CoreLocator.resolveLibraryPath(CoreLocator.helpersName);
    if (helperPath == null) {
      status = 'Missing helpers — run ./scripts/build_helpers.sh (desktop) or rebuild APK';
      notifyListeners();
      throw StateError(status);
    }
    try {
      _helpers = DynamicLibrary.open(helperPath);
      _logFn = _helpers!.lookup('mame_cabinet_log').cast<Void>();
    } catch (e) {
      status = 'Failed to open helpers: $e';
      notifyListeners();
      rethrow;
    }

    status = 'Initializing core…';
    notifyListeners();

    // isolateLocal: libretro callbacks are synchronous on the retro_run thread.
    _envCb = NativeCallable<RetroEnvironmentNative>.isolateLocal(
      _environment,
      exceptionalReturn: false,
    );
    _videoCb = NativeCallable<RetroVideoRefreshNative>.isolateLocal(_videoRefresh);
    _audioCb = NativeCallable<RetroAudioSampleNative>.isolateLocal(_audioSample);
    _audioBatchCb = NativeCallable<RetroAudioSampleBatchNative>.isolateLocal(
      _audioBatch,
      exceptionalReturn: 0,
    );
    _pollCb = NativeCallable<RetroInputPollNative>.isolateLocal(_inputPoll);
    _stateCb = NativeCallable<RetroInputStateNative>.isolateLocal(
      _inputState,
      exceptionalReturn: 0,
    );

    _b!.retro_set_environment(_envCb!.nativeFunction);
    _b!.retro_set_video_refresh(_videoCb!.nativeFunction);
    _b!.retro_set_audio_sample(_audioCb!.nativeFunction);
    _b!.retro_set_audio_sample_batch(_audioBatchCb!.nativeFunction);
    _b!.retro_set_input_poll(_pollCb!.nativeFunction);
    _b!.retro_set_input_state(_stateCb!.nativeFunction);
    _b!.retro_init();

    final info = calloc<RetroSystemInfo>();
    _b!.retro_get_system_info(info);
    coreName = info.ref.library_name == nullptr
        ? 'unknown'
        : info.ref.library_name.toDartString();
    calloc.free(info);

    status = 'Core ready: $coreName';
    notifyListeners();
  }

  Future<void> loadGame(String path) async {
    final b = _b;
    if (b == null) throw StateError('Load a core first');
    final file = File(path);
    if (!file.existsSync()) throw StateError('ROM not found: $path');

    if (_gameLoaded) {
      b.retro_unload_game();
      _gameLoaded = false;
      _freeGamePath();
    }

    final info = calloc<RetroGameInfo>();
    _gamePath = p.absolute(path).toNativeUtf8();
    info.ref.path = _gamePath!;
    info.ref.data = nullptr;
    info.ref.size = 0;
    info.ref.meta = nullptr;

    final ok = b.retro_load_game(info);
    calloc.free(info);

    if (!ok) {
      _freeGamePath();
      status = 'Failed to load ROM (bad set / missing files?)';
      notifyListeners();
      throw StateError(status);
    }

    final av = calloc<RetroSystemAvInfo>();
    b.retro_get_system_av_info(av);
    fps = av.ref.timing.fps == 0 ? 60 : av.ref.timing.fps;
    frameWidth = av.ref.geometry.base_width;
    frameHeight = av.ref.geometry.base_height;
    calloc.free(av);

    romPath = path;
    _gameLoaded = true;
    status = 'Playing: ${p.basename(path)}';
    notifyListeners();
    // Caller / UI starts the run loop so tests can step frames safely.
  }

  void start({double speed = 1.0}) {
    if (!_gameLoaded) return;
    _running = true;
    final factor = speed <= 0 ? 1.0 : speed;
    final periodMs = (1000 / (fps * factor)).round().clamp(4, 50);
    _ticker?.cancel();
    _ticker = Timer.periodic(Duration(milliseconds: periodMs), (_) => runFrame());
  }

  void reset() {
    if (!_gameLoaded) return;
    _b?.retro_reset();
  }

  /// Advance one emulation frame (used by the ticker and tests).
  void runFrame() {
    if (!_gameLoaded) return;
    try {
      _b?.retro_run();
    } catch (e) {
      status = 'Core crash: $e';
      pause();
      notifyListeners();
      return;
    }
    if (_frameDirty && !_buildingImage) {
      _frameDirty = false;
      unawaited(_publishFrame());
    }
  }

  void pause() {
    _running = false;
    _ticker?.cancel();
    _ticker = null;
  }

  void setButton(int id, bool down) {
    if (down) {
      _buttons[id] = true;
    } else {
      _buttons.remove(id);
    }
  }

  void clearButtons() => _buttons.clear();

  Future<Uint8List?> serialize() async {
    final b = _b;
    if (b == null || !_gameLoaded) return null;
    final size = b.retro_serialize_size();
    if (size <= 0) return null;
    final ptr = calloc<Uint8>(size);
    final ok = b.retro_serialize(ptr.cast(), size);
    if (!ok) {
      calloc.free(ptr);
      return null;
    }
    final bytes = Uint8List.fromList(ptr.asTypedList(size));
    calloc.free(ptr);
    return bytes;
  }

  Future<bool> unserialize(Uint8List data) async {
    final b = _b;
    if (b == null || !_gameLoaded) return false;
    final ptr = calloc<Uint8>(data.length);
    ptr.asTypedList(data.length).setAll(0, data);
    final ok = b.retro_unserialize(ptr.cast(), data.length);
    calloc.free(ptr);
    return ok;
  }

  Future<void> unload() async {
    pause();
    if (_gameLoaded) {
      _b?.retro_unload_game();
      _gameLoaded = false;
    }
    _freeGamePath();
    if (_b != null) {
      try {
        _b!.retro_deinit();
      } catch (_) {}
    }
    _envCb?.close();
    _videoCb?.close();
    _audioCb?.close();
    _audioBatchCb?.close();
    _pollCb?.close();
    _stateCb?.close();
    _envCb = null;
    _videoCb = null;
    _audioCb = null;
    _audioBatchCb = null;
    _pollCb = null;
    _stateCb = null;
    final sys = _systemDir;
    if (sys != null) {
      calloc.free(sys);
      _systemDir = null;
    }
    final sav = _saveDir;
    if (sav != null) {
      calloc.free(sav);
      _saveDir = null;
    }
    frame?.dispose();
    frame = null;
    _b = null;
    _lib = null;
    _helpers = null;
    _logFn = null;
    coreName = null;
    romPath = null;
    status = 'No core loaded';
    notifyListeners();
  }

  void _freeGamePath() {
    final gp = _gamePath;
    if (gp != null) {
      calloc.free(gp);
      _gamePath = null;
    }
  }

  @override
  void dispose() {
    unawaited(unload());
    super.dispose();
  }

  bool _environment(int cmd, Pointer<Void> data) {
    // Strip experimental/private flag bits for matching.
    final base = cmd & 0xffff;
    switch (base) {
      case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
        if (data != nullptr) {
          _pixelFormat = data.cast<Int32>().value;
        }
        return true;
      case RETRO_ENVIRONMENT_GET_CAN_DUPE:
        if (data != nullptr) {
          data.cast<Uint8>().value = 1;
        }
        return true;
      case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
        if (data != nullptr && _systemDir != null) {
          data.cast<Pointer<Utf8>>().value = _systemDir!;
          return true;
        }
        return false;
      case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
        if (data != nullptr && _saveDir != null) {
          data.cast<Pointer<Utf8>>().value = _saveDir!;
          return true;
        }
        return false;
      case RETRO_ENVIRONMENT_GET_VARIABLE:
        if (data != nullptr) {
          data.cast<RetroVariable>().ref.value = nullptr;
        }
        return true;
      case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
        if (data != nullptr) {
          data.cast<Uint8>().value = 0;
        }
        return true;
      case RETRO_ENVIRONMENT_SET_VARIABLES:
      case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
      case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO:
      case RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL:
      case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME:
      case 42: // SET_SUPPORT_ACHIEVEMENTS (also used with experimental bit)
      case RETRO_ENVIRONMENT_SET_GEOMETRY:
      case 32: // SET_SYSTEM_AV_INFO (correct libretro id)
      case RETRO_ENVIRONMENT_SET_MESSAGE:
      case RETRO_ENVIRONMENT_SET_CORE_OPTIONS:
      case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_INTL:
      case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY:
      case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2:
        return true;
      case RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION:
        if (data != nullptr) {
          data.cast<Uint32>().value = 0;
        }
        return true;
      case RETRO_ENVIRONMENT_GET_LANGUAGE:
        if (data != nullptr) {
          data.cast<Uint32>().value = 0; // English
        }
        return true;
      case 24: // GET_INPUT_DEVICE_CAPABILITIES
        if (data != nullptr) {
          data.cast<Uint64>().value = 1 << 1; // JOYPAD
        }
        return true;
      case RETRO_ENVIRONMENT_GET_LOG_INTERFACE:
        if (data != nullptr && _logFn != null) {
          data.cast<RetroLogCallback>().ref.log = _logFn!;
          return true;
        }
        return false;
      default:
        return false;
    }
  }

  void _videoRefresh(Pointer<Void> data, int width, int height, int pitch) {
    if (data == nullptr || width <= 0 || height <= 0) return;
    if (width > 2048 || height > 2048 || pitch <= 0) return;
    videoCallbacks++;

    frameWidth = width;
    frameHeight = height;
    final out = Uint8List(width * height * 4);

    if (_pixelFormat == RETRO_PIXEL_FORMAT_XRGB8888) {
      final src = data.cast<Uint8>().asTypedList(pitch * height);
      for (var y = 0; y < height; y++) {
        final row = y * pitch;
        final destRow = y * width * 4;
        for (var x = 0; x < width; x++) {
          final i = row + x * 4;
          final o = destRow + x * 4;
          out[o] = src[i + 2];
          out[o + 1] = src[i + 1];
          out[o + 2] = src[i];
          out[o + 3] = 0xFF;
        }
      }
    } else if (_pixelFormat == RETRO_PIXEL_FORMAT_RGB565) {
      final src = data.cast<Uint16>().asTypedList((pitch ~/ 2) * height);
      final stride = pitch ~/ 2;
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final px = src[y * stride + x];
          final r = ((px >> 11) & 0x1F) * 255 ~/ 31;
          final g = ((px >> 5) & 0x3F) * 255 ~/ 63;
          final b = (px & 0x1F) * 255 ~/ 31;
          final o = (y * width + x) * 4;
          out[o] = r;
          out[o + 1] = g;
          out[o + 2] = b;
          out[o + 3] = 0xFF;
        }
      }
    } else {
      final src = data.cast<Uint16>().asTypedList((pitch ~/ 2) * height);
      final stride = pitch ~/ 2;
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final px = src[y * stride + x];
          final r = ((px >> 10) & 0x1F) * 255 ~/ 31;
          final g = ((px >> 5) & 0x1F) * 255 ~/ 31;
          final b = (px & 0x1F) * 255 ~/ 31;
          final o = (y * width + x) * 4;
          out[o] = r;
          out[o + 1] = g;
          out[o + 2] = b;
          out[o + 3] = 0xFF;
        }
      }
    }

    _rgba = out;
    _frameDirty = true;
  }

  void _audioSample(int left, int right) {}

  int _audioBatch(Pointer<Int16> data, int frames) => frames;

  void _inputPoll() {}

  int _inputState(int port, int device, int index, int id) {
    if (port != 0 || device != RETRO_DEVICE_JOYPAD) return 0;
    return _buttons[id] == true ? 1 : 0;
  }

  Future<void> _publishFrame() async {
    final bytes = _rgba;
    if (bytes == null || frameWidth <= 0 || frameHeight <= 0) return;
    _buildingImage = true;
    try {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        bytes,
        frameWidth,
        frameHeight,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      final image = await completer.future;
      frame?.dispose();
      frame = image;
      notifyListeners();
    } finally {
      _buildingImage = false;
    }
  }
}

/// Resolve project root + bundled core / helper paths.
///
/// Desktop: walk for `pubspec.yaml` + `native/cores`.
/// Android: load `.so` from the app `nativeLibraryDir` (jniLibs / CMake).
class CoreLocator {
  static String? _cachedRoot;
  static String? _androidNativeLibDir;
  static String? _supportDirOverride;
  static String? _savesDirOverride;

  static const helpersName = 'libhost_helpers.so';

  /// Call once at startup (sets writable system/save dirs on mobile).
  static Future<void> init() async {
    if (Platform.isAndroid) {
      try {
        const channel = MethodChannel('mame_cabinet/native');
        final dir = await channel.invokeMethod<String>('nativeLibraryDir');
        if (dir != null && dir.isNotEmpty) {
          _androidNativeLibDir = dir;
        }
      } catch (_) {}
    }

    if (Platform.isAndroid || Platform.isIOS) {
      final support = await getApplicationSupportDirectory();
      _supportDirOverride = p.join(support.path, 'libretro_system');
      _savesDirOverride = p.join(support.path, 'libretro_saves');
      Directory(_supportDirOverride!).createSync(recursive: true);
      Directory(_savesDirOverride!).createSync(recursive: true);
    }
  }

  static String get projectRoot {
    _cachedRoot ??= _discoverRoot();
    return _cachedRoot!;
  }

  static String _discoverRoot() {
    final env = Platform.environment['MAME_CABINET_ROOT'];
    if (env != null && env.isNotEmpty && _looksLikeRoot(env)) {
      return p.normalize(env);
    }

    for (final start in [
      Directory.current.path,
      File(Platform.resolvedExecutable).parent.path,
      p.normalize(
        p.join(File(Platform.resolvedExecutable).parent.path, '..', '..', '..', '..', '..'),
      ),
    ]) {
      final found = _walkForRoot(start);
      if (found != null) return found;
    }

    const fallback = '/home/mohammed/Desktop/mame';
    if (_looksLikeRoot(fallback)) return fallback;

    return Directory.current.path;
  }

  static String? _walkForRoot(String start) {
    var dir = Directory(p.normalize(start));
    for (var i = 0; i < 10; i++) {
      if (_looksLikeRoot(dir.path)) return dir.path;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  static bool _looksLikeRoot(String path) {
    final pubspec = File(p.join(path, 'pubspec.yaml'));
    final cores = Directory(p.join(path, 'native', 'cores'));
    return pubspec.existsSync() && cores.existsSync();
  }

  static String get nativeDir => p.join(projectRoot, 'native');
  static String get coresDir => p.join(nativeDir, 'cores');
  static String get supportDir =>
      _supportDirOverride ?? p.join(nativeDir, 'support');
  static String get savesDir => _savesDirOverride ?? p.join(nativeDir, 'saves');

  /// Absolute path or Android soname that [DynamicLibrary.open] can load.
  static String? resolveLibraryPath(String nameOrPath) {
    // Absolute / relative filesystem path.
    if (nameOrPath.contains('/') || nameOrPath.contains('\\')) {
      final abs = p.normalize(p.absolute(nameOrPath));
      if (File(abs).existsSync()) return abs;
    }

    final base = p.basename(nameOrPath);
    final candidates = <String>[
      if (_androidNativeLibDir != null) p.join(_androidNativeLibDir!, base),
      if (_androidNativeLibDir != null && !base.startsWith('lib'))
        p.join(_androidNativeLibDir!, 'lib$base'),
      p.join(coresDir, base),
      p.join(nativeDir, base),
      p.join(File(Platform.resolvedExecutable).parent.path, 'cores', base),
      p.join(Directory.current.path, 'native', 'cores', base),
      p.join(Directory.current.path, 'native', base),
    ];

    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }

    // Android linker can resolve jniLibs by soname alone.
    if (Platform.isAndroid) {
      if (base.startsWith('lib') && base.endsWith('.so')) return base;
      if (base.endsWith('.so')) return 'lib$base';
      return 'lib$base.so';
    }

    return null;
  }

  static bool libraryExists(String nameOrPath) {
    final resolved = resolveLibraryPath(nameOrPath);
    if (resolved == null) return false;
    if (!resolved.contains('/')) {
      // Soname-only: assume packaged in APK (verified at DynamicLibrary.open).
      return Platform.isAndroid;
    }
    return File(resolved).existsSync();
  }

  static String get helpersPath =>
      resolveLibraryPath(helpersName) ?? p.join(nativeDir, helpersName);

  static String? _core(String name) {
    // Prefer Android jniLibs naming (lib*.so) then desktop names.
    final names = <String>[
      if (!name.startsWith('lib')) 'lib$name',
      name,
      if (name.endsWith('.so')) name.replaceAll('.so', '_android.so'),
    ];
    for (final n in names) {
      final path = resolveLibraryPath(n);
      if (path != null && (path.contains('/') ? File(path).existsSync() : Platform.isAndroid)) {
        return path;
      }
    }
    return null;
  }

  static String? fbneo() =>
      _core('fbneo_libretro.so') ??
      _core('fbneo_libretro.dylib') ??
      _core('fbneo_libretro.dll');

  static String? mame2003Plus() =>
      _core('mame2003_plus_libretro.so') ??
      _core('mame2003_plus_libretro.dylib') ??
      _core('mame2003_plus_libretro.dll');

  /// Prefer MAME2003+ (smaller / broader). FBNeo for CPS sets like dino.
  static String? bestArcadeCore({String? romBasename}) {
    final name = (romBasename ?? '').toLowerCase();
    if (name.startsWith('dino') || name.contains('cadillacs')) {
      return fbneo() ?? mame2003Plus();
    }
    return mame2003Plus() ?? fbneo();
  }

  static String diagnose() {
    final buf = StringBuffer();
    buf.writeln('cwd=${Directory.current.path}');
    buf.writeln('exe=${Platform.resolvedExecutable}');
    buf.writeln('root=$projectRoot');
    buf.writeln('androidNativeLib=${_androidNativeLibDir ?? 'n/a'}');
    buf.writeln(
      'helpers=${libraryExists(helpersName) ? 'OK' : 'MISSING'} ($helpersPath)',
    );
    buf.writeln('mame2003+=${mame2003Plus() ?? 'MISSING'}');
    buf.writeln('fbneo=${fbneo() ?? 'MISSING'}');
    buf.writeln('support=$supportDir');
    return buf.toString().trim();
  }
}
