import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mame_cabinet/libretro/libretro_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads mame2003+ and runs free gridlee ROM', () async {
    final core = CoreLocator.mame2003Plus();
    expect(core, isNotNull, reason: 'Place cores in native/cores/');
    expect(File('native/libhost_helpers.so').existsSync(), isTrue);

    final rom = File('${CoreLocator.projectRoot}/roms/gridlee.zip');
    expect(rom.existsSync(), isTrue);

    final host = LibretroHost();
    addTearDown(() async {
      await host.unload();
    });

    await host.loadCore(core!);
    expect(host.coreName, isNotNull);

    await host.loadGame(rom.path);
    expect(host.isGameLoaded, isTrue);
    expect(host.frameWidth, greaterThan(0));
    expect(host.frameHeight, greaterThan(0));

    for (var i = 0; i < 60; i++) {
      host.runFrame();
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(host.videoCallbacks, greaterThan(0));
    // gridlee is flagged GAME_DOESNT_SERIALIZE — save states work on other sets (e.g. dino).
  }, timeout: const Timeout(Duration(seconds: 90)));
}
