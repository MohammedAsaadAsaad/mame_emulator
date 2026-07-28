import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mame_cabinet/libretro/libretro_host.dart';
import 'package:mame_cabinet/services/system_bios_service.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Neo Geo BIOS scores for FBNeo and Metal Slug loads', () async {
    await CoreLocator.init();

    final biosSrc = File(p.join(CoreLocator.projectRoot, 'assets/bios/neogeo.zip'));
    expect(biosSrc.existsSync(), isTrue, reason: 'assets/bios/neogeo.zip required');
    final biosBytes = await biosSrc.readAsBytes();
    final score = SystemBiosService.scoreNeogeoZip(biosBytes);
    expect(score, greaterThanOrEqualTo(300), reason: 'need 3/3 required CRCs');

    await SystemBiosService.installBiosBytes('neogeo.zip', biosBytes, force: true);
    expect(
      SystemBiosService.hasNeogeoBios(),
      isTrue,
      reason: 'BIOS must land in ${CoreLocator.supportDir}',
    );

    final romSrc = File('/home/mohammed/Downloads/mslug3.zip');
    expect(romSrc.existsSync(), isTrue, reason: 'place mslug3.zip in Downloads for local smoke');

    final tmp = await Directory.systemTemp.createTemp('neogeo_flutter_');
    addTearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {}
    });
    final romDir = Directory(p.join(tmp.path, 'roms'))..createSync(recursive: true);
    final romDest = p.join(romDir.path, 'mslug3.zip');
    await romSrc.copy(romDest);
    await File(p.join(CoreLocator.supportDir, 'neogeo.zip'))
        .copy(p.join(romDir.path, 'neogeo.zip'));

    expect(SystemBiosService.hasNeogeoBios(romPath: romDest), isTrue);
    expect(
      await SystemBiosService.ensureNeogeoBesideRom(romDest),
      isTrue,
    );

    // Confirm required inner dumps exist in installed zip.
    final arch = ZipDecoder().decodeBytes(
      await File(p.join(CoreLocator.supportDir, 'neogeo.zip')).readAsBytes(),
      verify: false,
    );
    final names = {
      for (final f in arch.files)
        if (f.isFile) p.basename(f.name).toLowerCase(),
    };
    for (final need in SystemBiosService.fbneoNeogeoRequiredCrcs.keys) {
      expect(names.contains(need), isTrue, reason: 'missing $need in neogeo.zip');
    }

    final core = CoreLocator.fbneo();
    expect(core, isNotNull);
    expect(CoreLocator.libraryExists(CoreLocator.helpersName), isTrue);

    final host = LibretroHost();
    addTearDown(() async {
      await host.unload();
    });

    await host.loadCore(core!);
    await host.loadGame(romDest);
    expect(host.isGameLoaded, isTrue, reason: host.status);
    expect(host.frameWidth, greaterThan(0));
    expect(host.frameHeight, greaterThan(0));

    for (var i = 0; i < 90; i++) {
      host.runFrame();
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(host.videoCallbacks, greaterThan(0));
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('decrypt_bios script round-trips assets/bios/neogeo.zip', () async {
    final pass = 'local-verify-${DateTime.now().millisecondsSinceEpoch}';
    final enc = File('${Directory.systemTemp.path}/neogeo_verify.enc');
    final out = File('${Directory.systemTemp.path}/neogeo_verify_out.zip');
    addTearDown(() {
      if (enc.existsSync()) enc.deleteSync();
      if (out.existsSync()) out.deleteSync();
    });

    final encResult = await Process.run('openssl', [
      'enc',
      '-aes-256-cbc',
      '-pbkdf2',
      '-iter',
      '200000',
      '-salt',
      '-in',
      'assets/bios/neogeo.zip',
      '-out',
      enc.path,
      '-pass',
      'pass:$pass',
    ]);
    expect(encResult.exitCode, 0, reason: encResult.stderr.toString());

    final dec = await Process.run(
      'bash',
      ['scripts/decrypt_bios.sh', enc.path, out.path],
      environment: {
        ...Platform.environment,
        'NEOGEO_BIOS_PASSPHRASE': pass,
      },
    );
    expect(dec.exitCode, 0, reason: '${dec.stdout}\n${dec.stderr}');
    expect(out.readAsBytesSync(), File('assets/bios/neogeo.zip').readAsBytesSync());

    final committed = File('ci/bios/neogeo.zip.enc').readAsBytesSync();
    expect(String.fromCharCodes(committed.take(8)), 'Salted__');
    expect(committed.length, greaterThan(1000000));
  });
}
