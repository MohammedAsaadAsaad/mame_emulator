import 'dart:io';

import 'package:mame_cabinet/libretro/libretro_host.dart';

Future<void> main() async {
  final host = LibretroHost();
  final core = CoreLocator.mame2003Plus();
  stdout.writeln('core: $core');
  await host.loadCore(core!);
  stdout.writeln('loaded core: ${host.coreName}');
  final rom = '${CoreLocator.projectRoot}/roms/gridlee.zip';
  stdout.writeln('rom exists: ${File(rom).existsSync()}');
  await host.loadGame(rom);
  stdout.writeln('game loaded, ${host.frameWidth}x${host.frameHeight} @ ${host.fps}fps');
  for (var i = 0; i < 45; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  stdout.writeln('frame=${host.frame != null} status=${host.status}');
  final state = await host.serialize();
  stdout.writeln('serialize bytes: ${state?.length}');
  await host.unload();
  stdout.writeln('ok');
}
