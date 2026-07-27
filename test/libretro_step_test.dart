import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mame_cabinet/libretro/libretro_bindings.dart';
import 'package:mame_cabinet/libretro/libretro_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('core exports retro_api_version', () {
    final path = CoreLocator.mame2003Plus();
    expect(path, isNotNull);
    final lib = DynamicLibrary.open(path!);
    final api = lib.lookupFunction<Uint32 Function(), int Function()>('retro_api_version');
    expect(api(), greaterThanOrEqualTo(1));
  });

  test('loads gridlee via MAME2003+ and renders frames', () async {
    final host = LibretroHost();
    addTearDown(() async {
      try {
        await host.unload();
      } catch (_) {}
    });

    await host.loadCore(CoreLocator.mame2003Plus()!);
    expect(host.coreName, contains('MAME'));

    final rom = File('${CoreLocator.projectRoot}/roms/gridlee.zip');
    expect(rom.existsSync(), isTrue);
    await host.loadGame(rom.path);
    expect(host.isGameLoaded, isTrue);

    host.pause(); // drive frames manually for determinism
    for (var i = 0; i < 30; i++) {
      host.runFrame();
    }
    // Allow decodeImageFromPixels futures to complete.
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(host.videoCallbacks, greaterThan(0));
    expect(host.frameWidth, greaterThan(0));
    expect(host.frame, isNotNull);

    host.setButton(RETRO_DEVICE_ID_JOYPAD_START, true);
    host.runFrame();
    host.setButton(RETRO_DEVICE_ID_JOYPAD_START, false);
  }, timeout: const Timeout(Duration(seconds: 90)));
}
