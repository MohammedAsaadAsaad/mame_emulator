import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mame_cabinet/libretro/libretro_host.dart';
import 'package:mame_cabinet/services/system_bios_service.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CPS key is injected into ROM zip without dropping other files', () async {
    await CoreLocator.init();

    final tmp = await Directory.systemTemp.createTemp('cps_key_');
    addTearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {}
    });

    // Tiny fake romset zip
    final romPath = p.join(tmp.path, 'armwar.zip');
    final built = Archive()
      ..add(ArchiveFile('pwg.01', 4, [1, 2, 3, 4]))
      ..add(ArchiveFile('pwg.02', 4, [5, 6, 7, 8]));
    final encoded = ZipEncoder().encode(built)!;
    await File(romPath).writeAsBytes(encoded);

    // Plant key in system dir (simulates assets/bios install)
    final keyBytes = Uint8List.fromList(List<int>.generate(20, (i) => i));
    await SystemBiosService.installSupportFile('armwar.key', keyBytes, force: true);

    final ok = await SystemBiosService.ensureKeyBesideRom(romPath);
    expect(ok, isTrue);
    expect(File(p.join(tmp.path, 'armwar.key')).existsSync(), isTrue);

    final after = ZipDecoder().decodeBytes(await File(romPath).readAsBytes());
    final names = {
      for (final f in after)
        if (f.isFile) p.basename(f.name).toLowerCase(),
    };
    expect(names.contains('pwg.01'), isTrue);
    expect(names.contains('pwg.02'), isTrue);
    expect(names.contains('armwar.key'), isTrue);
  });
}
