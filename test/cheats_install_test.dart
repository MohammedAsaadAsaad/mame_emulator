import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mame_cabinet/libretro/libretro_host.dart';
import 'package:mame_cabinet/services/cheat_service.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('installs FBNeo cheat ini files into system/fbneo/cheats', () async {
    await CoreLocator.init();

    final src = Directory('/home/mohammed/Downloads/FBNeo-cheats-master/cheats');
    expect(src.existsSync(), isTrue, reason: 'local FBNeo-cheats checkout required');

    final n = await CheatService.installFromDirectory(src.path);
    expect(n, greaterThan(1000));
    expect(CheatService.hasCheatsForRom('mslug3.zip'), isTrue);
    expect(
      File(p.join(CheatService.cheatsDir, 'mslug3.ini')).existsSync(),
      isTrue,
    );
  });
}
