import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../libretro/libretro_host.dart';

/// FBNeo native cheats (`.ini` under `system/fbneo/cheats/{romset}.ini`).
///
/// Official pack: https://github.com/finalburnneo/FBNeo-cheats
class CheatService {
  CheatService._();

  static const assetCheatsZip = 'assets/cheats/fbneo_cheats.zip';
  static const assetCheatsPrefix = 'assets/cheats/';

  /// Optional developer drop folder (desktop) — synced into the system dir.
  static const desktopSourceHint =
      '/home/mohammed/Downloads/FBNeo-cheats-master/cheats';

  static String get cheatsDir =>
      p.join(CoreLocator.supportDir, 'fbneo', 'cheats');

  static Future<void> ensureCheatsDir() async {
    Directory(cheatsDir).createSync(recursive: true);
  }

  /// How many `.ini` cheat files are currently installed.
  static int installedCount() {
    final dir = Directory(cheatsDir);
    if (!dir.existsSync()) return 0;
    return dir
        .listSync(followLinks: false)
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.ini'))
        .length;
  }

  /// Install cheat pack into FBNeo's expected folder (idempotent).
  ///
  /// Sources (first success wins if already populated with many files):
  /// 1. Existing system dir (skip if already has ≥100 ini)
  /// 2. Bundled `assets/cheats/fbneo_cheats.zip`
  /// 3. Desktop source folder (if present)
  static Future<int> installBundledCheats() async {
    await ensureCheatsDir();
    final existing = installedCount();
    if (existing >= 100) {
      debugPrint('Cheats already installed: $existing files in $cheatsDir');
      return existing;
    }

    // Prefer asset zip (works on Android + desktop release builds).
    try {
      final data = await rootBundle.load(assetCheatsZip);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final n = await _extractZipBytes(bytes);
      if (n > 0) {
        debugPrint('Cheats from assets zip: $n → $cheatsDir');
        return n;
      }
    } catch (e) {
      debugPrint('No bundled cheats zip ($assetCheatsZip): $e');
    }

    // Loose assets/cheats/*.ini (small personal subsets).
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      var n = 0;
      for (final key in manifest.listAssets()) {
        if (!key.startsWith(assetCheatsPrefix)) continue;
        if (!key.toLowerCase().endsWith('.ini')) continue;
        final data = await rootBundle.load(key);
        final bytes =
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        final dest = File(p.join(cheatsDir, p.basename(key)));
        await dest.writeAsBytes(bytes, flush: true);
        n++;
      }
      if (n > 0) {
        debugPrint('Cheats from loose assets: $n → $cheatsDir');
        return n;
      }
    } catch (e) {
      debugPrint('AssetManifest cheats scan failed: $e');
    }

    // Desktop: copy from the user's FBNeo-cheats checkout.
    final desktop = Directory(desktopSourceHint);
    if (desktop.existsSync()) {
      final n = await installFromDirectory(desktop.path);
      if (n > 0) {
        debugPrint('Cheats from desktop folder: $n → $cheatsDir');
        return n;
      }
    }

    debugPrint('No FBNeo cheat pack found — Cheats menu will be empty');
    return installedCount();
  }

  /// Copy all `.ini` from [sourceDir] into the FBNeo cheats folder.
  static Future<int> installFromDirectory(String sourceDir) async {
    await ensureCheatsDir();
    final src = Directory(sourceDir);
    if (!src.existsSync()) return 0;
    var n = 0;
    await for (final entity in src.list(recursive: false, followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.toLowerCase().endsWith('.ini')) continue;
      final dest = File(p.join(cheatsDir, p.basename(entity.path)));
      if (dest.existsSync() &&
          dest.lengthSync() == entity.lengthSync()) {
        n++;
        continue;
      }
      await entity.copy(dest.path);
      n++;
    }
    return n;
  }

  static Future<int> _extractZipBytes(Uint8List bytes) async {
    await ensureCheatsDir();
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    var n = 0;
    for (final f in archive) {
      if (!f.isFile) continue;
      final name = p.basename(f.name).toLowerCase();
      if (!name.endsWith('.ini')) continue;
      final content = f.content;
      if (content.isEmpty) continue;
      final dest = File(p.join(cheatsDir, p.basename(f.name)));
      await dest.writeAsBytes(content, flush: true);
      n++;
    }
    return n;
  }

  /// Path to the cheat ini for a ROM basename (`mslug3.zip` → `mslug3.ini`).
  static String? iniPathForRom(String? romBasename) {
    final stem = CoreLocator.romStem(romBasename);
    if (stem.isEmpty) return null;
    final path = p.join(cheatsDir, '$stem.ini');
    return File(path).existsSync() ? path : null;
  }

  static bool hasCheatsForRom(String? romBasename) =>
      iniPathForRom(romBasename) != null;
}

/// One FBNeo core-option cheat exposed after `loadGame`.
class CheatOption {
  const CheatOption({
    required this.key,
    required this.label,
    required this.values,
    required this.current,
  });

  final String key;
  final String label;
  final List<String> values;
  final String current;

  bool get isEnabled =>
      current != values.first &&
      !current.toLowerCase().contains('disabled');
}
