import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../libretro/libretro_host.dart';

/// Finds arcade **BIOS / device support archives** (not libretro cores) next to
/// ROMs and installs them where FBNeo looks (`system_dir`, `system_dir/fbneo/`).
///
/// These are MAME/FBNeo parent/BIOS zips required by some drivers (Neo Geo,
/// PGM, CPS-3, …). Emulation **cores** are separate: `fbneo_libretro` /
/// `mame2003_plus_libretro`.
///
/// Personal builds may also ship BIOS under [assetBiosPrefix] (`assets/bios/`);
/// [installBundledAssets] copies them into the system dir at startup.
/// Multiple `neogeo.zip*` candidates are CRC-scored; the best FBNeo match wins.
class SystemBiosService {
  SystemBiosService._();

  static const assetBiosPrefix = 'assets/bios/';

  /// Required inner dumps for current FBNeo Neo Geo support.
  static const fbneoNeogeoRequiredCrcs = {
    'sm1.sm1': 0x94416d67,
    'sfix.sfix': 0xc2ea0cfd,
    '000-lo.lo': 0x5a86cff2,
  };

  /// Known BIOS / device archives shipped beside ROM packs.
  /// Not playable games — auto-installed into the system dir when found.
  static const biosArchives = {
    // Neo Geo
    'neogeo.zip',
    'neogeo.7z',
    'neocdz.zip',
    'neocdz.7z',
    // PolyGame Master
    'pgm.zip',
    'pgm.7z',
    // Capcom CPS-3 (+ optional decrypted companion)
    'cps3.zip',
    'cps3.7z',
    'decrypted.zip',
    // QSound (some CPS-1/2 sets / boards)
    'qsound.zip',
    'qsound.7z',
    // Other common FBNeo device / MCU dumps
    'nmk004.zip',
    'nmk004.7z',
    'skns.zip',
    'skns.7z',
    'midssio.zip',
    'midssio.7z',
    'cchip.zip',
    'cchip.7z',
    'ym2608.zip',
    'ym2608.7z',
  };

  static bool isBiosArchive(String path) {
    final base = p.basename(path).toLowerCase();
    if (biosArchives.contains(base)) return true;
    // Allow hashed downloads: neogeo.zip.ae758c39
    return base.startsWith('neogeo.zip.');
  }

  /// Rough Neo Geo content detection (Metal Slug, KOF, etc.).
  static bool looksLikeNeoGeo(String? romBasename) {
    final stem = CoreLocator.romStem(romBasename);
    if (stem.isEmpty) return false;
    if (stem == 'neogeo' || stem == 'neocdz') return false;
    const prefixes = [
      'mslug',
      'kof',
      'fatfury',
      'fatfursp',
      'garou',
      'samsho',
      'samsh5sp',
      'lastblad',
      'lastbld',
      'rbff',
      'aof',
      'savagere',
      'twinspri',
      'pulstar',
      'blazstar',
      'gowcaizr',
      'kabukikl',
      'wakuwak7',
      'wh1',
      'wh2',
      'whp',
      ' inher',
      'ninjamas',
      'ncommand',
      'neobombe',
      'neocup98',
      'neodrift',
      'neomrdo',
      'neonopon',
      'neoturf',
      'ironclad',
      'kabukikl',
      'kotm',
      'crsword',
      'ctomaday',
      'cyberlip',
      'diggerma',
      'doubledr',
      'eightman',
      'galaxyfg',
      'ganryu',
      'goalx3',
      'gururin',
      'irrmaze',
      'janshin',
      'jockeygp',
      'joyjoy',
      'kingofmonster',
      'lbowling',
      'legendos',
      'magdrop',
      'maglord',
      'mahretsu',
      'marukodq',
      'matrim',
      'miexchng',
      'minasan',
      'mosyougi',
      'mutnat',
      'nam1975',
      'overtop',
      'panicbom',
      'pbobblen',
      'pbobbl2n',
      'pgoal',
      'pnyaa',
      'popbounc',
      'preisle2',
      'pspikes2',
      'puzzldpr',
      'puzzledp',
      'quizdai2',
      'quizdais',
      'quizkof',
      'ridhero',
      'roboarmy',
      'sdodgeb',
      'sengoku',
      'shocktr',
      'socbrawl',
      'spinmast',
      'stakwin',
      'strhoop',
      'superspy',
      'tophuntr',
      'tpgolf',
      'trally',
      'viewpoin',
      'vliner',
      'wildcard',
      'wjammers',
      'zedblade',
      'zintrckb',
      'zupapa',
      '2020bb',
      '3countb',
      'alpham2',
      'androdun',
      'bangbead',
      'bjourney',
      'breakers',
      'bstars',
      'burningf',
      'flipshot',
      'gpilots',
      'kotm2',
      'lresort',
      'ncombat',
      'sidone',
      'ssideki',
      'tws96',
      'ghostlop',
      'bangbead',
    ];
    for (final pre in prefixes) {
      if (stem == pre || stem.startsWith(pre)) return true;
    }
    return false;
  }

  static String get _systemDir => CoreLocator.supportDir;
  static String get _fbneoDir => p.join(_systemDir, 'fbneo');

  static List<String> _neogeoCandidates({String? romPath}) {
    final out = <String>[];
    if (romPath != null) {
      final dir = p.dirname(p.normalize(p.absolute(romPath)));
      out.add(p.join(dir, 'neogeo.zip'));
      out.add(p.join(dir, 'neogeo.7z'));
      out.add(p.join(dir, 'arcade', 'neogeo.zip'));
    }
    out.add(p.join(_systemDir, 'neogeo.zip'));
    out.add(p.join(_systemDir, 'neogeo.7z'));
    out.add(p.join(_fbneoDir, 'neogeo.zip'));
    out.add(p.join(_fbneoDir, 'neogeo.7z'));
    out.add(p.join(_fbneoDir, 'arcade', 'neogeo.zip'));
    return out;
  }

  static bool hasNeogeoBios({String? romPath}) =>
      _neogeoCandidates(romPath: romPath).any((c) => File(c).existsSync());

  /// Ensure FBNeo system search dirs exist (Linux / Windows / Android / macOS).
  static Future<void> ensureSystemDirs() async {
    final root = _systemDir;
    for (final path in [
      root,
      p.join(root, 'fbneo'),
      p.join(root, 'fbneo', 'arcade'),
    ]) {
      Directory(path).createSync(recursive: true);
    }
  }

  /// Copy bytes into FBNeo system search paths.
  /// When [force] is true, always rewrite (used after picking best neogeo.zip).
  static Future<void> installBiosBytes(
    String archiveName,
    List<int> bytes, {
    bool force = false,
  }) async {
    await ensureSystemDirs();
    final base = p.basename(archiveName).toLowerCase();
    // Always install Neo Geo under the canonical name FBNeo searches for.
    final destName = base.startsWith('neogeo.zip') ? 'neogeo.zip' : base;
    final targets = <String>[
      p.join(_systemDir, destName),
      p.join(_fbneoDir, destName),
      p.join(_fbneoDir, 'arcade', destName),
    ];
    for (final t in targets) {
      final dest = File(t);
      if (!force && dest.existsSync() && dest.lengthSync() == bytes.length) {
        continue;
      }
      await dest.writeAsBytes(bytes, flush: true);
    }
  }

  /// Score a Neo Geo BIOS zip for current FBNeo (higher = better).
  /// Required dumps must match CRC; bonus for MVS default + UniBIOS + file count.
  static int scoreNeogeoZip(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      final byName = <String, ArchiveFile>{};
      for (final f in archive) {
        if (!f.isFile) continue;
        byName[p.basename(f.name).toLowerCase()] = f;
      }

      var requiredHits = 0;
      for (final entry in fbneoNeogeoRequiredCrcs.entries) {
        final f = byName[entry.key];
        if (f == null) continue;
        final crc = f.crc32 ?? getCrc32(f.content);
        if (crc == entry.value) requiredHits++;
      }
      if (requiredHits == 0) return 0;

      var score = requiredHits * 100;
      if (byName.containsKey('sp-s3.sp1')) score += 10;
      if (byName.containsKey('sp-s2.sp1')) score += 5;
      if (byName.containsKey('uni-bios_4_0.rom')) score += 8;
      if (byName.containsKey('uni-bios_3_3.rom')) score += 4;
      score += byName.length; // prefer richer sets when CRCs tie
      return score;
    } catch (e) {
      debugPrint('scoreNeogeoZip failed: $e');
      return 0;
    }
  }

  static bool _isNeogeoAssetKey(String key) {
    final base = p.basename(key).toLowerCase();
    return base == 'neogeo.zip' ||
        base == 'neogeo.7z' ||
        base.startsWith('neogeo.zip.');
  }

  static Uint8List _bytesFromAsset(ByteData data) => data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

  /// Install BIOS zips the developer placed under `assets/bios/` (personal use).
  /// Among multiple `neogeo.zip*` files, CRC-picks the best FBNeo match.
  ///
  /// Note: CI APKs usually lack these files (gitignored). Local `flutter build apk`
  /// with zips present in `assets/bios/` bundles them into the APK.
  static Future<int> installBundledAssets() async {
    var installed = 0;

    // --- Neo Geo: pick best among neogeo.zip / neogeo.zip.* ---
    final neoCandidates = <String, Uint8List>{};

    // Canonical paths first (more reliable than manifest-only on Android).
    for (final key in [
      '${assetBiosPrefix}neogeo.zip',
      '${assetBiosPrefix}neogeo.7z',
    ]) {
      try {
        final data = await rootBundle.load(key);
        final bytes = _bytesFromAsset(data);
        if (bytes.isNotEmpty) neoCandidates[key] = bytes;
      } catch (e) {
        debugPrint('BIOS asset miss $key: $e');
      }
    }

    // Hashed copies: assets/bios/neogeo.zip.<hash>
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final key in manifest.listAssets()) {
        if (!key.startsWith(assetBiosPrefix)) continue;
        if (!_isNeogeoAssetKey(key)) continue;
        if (neoCandidates.containsKey(key)) continue;
        try {
          final data = await rootBundle.load(key);
          final bytes = _bytesFromAsset(data);
          if (bytes.isNotEmpty) neoCandidates[key] = bytes;
        } catch (e) {
          debugPrint('BIOS asset miss $key: $e');
        }
      }
    } catch (e) {
      debugPrint('AssetManifest bios scan failed: $e');
    }

    debugPrint('Neo Geo asset candidates: ${neoCandidates.keys.toList()}');

    if (neoCandidates.isNotEmpty) {
      String? bestKey;
      var bestScore = -1;
      Uint8List? bestBytes;
      for (final e in neoCandidates.entries) {
        final score = scoreNeogeoZip(e.value);
        debugPrint(
          'Neo Geo candidate ${e.key} score=$score size=${e.value.length}',
        );
        if (score > bestScore) {
          bestScore = score;
          bestKey = e.key;
          bestBytes = e.value;
        }
      }
      if (bestBytes != null && bestScore > 0) {
        await installBiosBytes('neogeo.zip', bestBytes, force: true);
        installed++;
        debugPrint(
          'BIOS from assets: neogeo.zip ← $bestKey (score=$bestScore) → $_systemDir',
        );
      } else {
        debugPrint(
          'No FBNeo-compatible neogeo.zip in assets '
          '(need sm1.sm1 / sfix.sfix / 000-lo.lo with matching CRCs)',
        );
      }
    }

    // --- Other BIOS archives (exact names only) ---
    for (final name in biosArchives) {
      if (name.startsWith('neogeo.')) continue; // handled above
      final assetPath = '$assetBiosPrefix$name';
      try {
        final data = await rootBundle.load(assetPath);
        final bytes = _bytesFromAsset(data);
        if (bytes.isEmpty) continue;
        await installBiosBytes(name, bytes);
        installed++;
        debugPrint('BIOS from assets: $name → $_systemDir');
      } catch (_) {
        // Not bundled in this build — skip.
      }
    }
    return installed;
  }

  /// Copy [source] into FBNeo system search paths (idempotent).
  static Future<void> installBiosArchive(String source) async {
    final file = File(source);
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    final base = p.basename(source).toLowerCase();
    if (base.startsWith('neogeo.zip')) {
      final score = scoreNeogeoZip(bytes);
      if (score <= 0) {
        debugPrint('Skipping incompatible Neo Geo BIOS: $source');
        return;
      }
      await installBiosBytes('neogeo.zip', bytes, force: true);
      return;
    }
    await installBiosBytes(p.basename(source), bytes);
  }

  /// Scan folders for known BIOS archives and install them.
  /// Returns how many distinct BIOS files were installed.
  static Future<int> provisionFromDirs(Iterable<String> dirs) async {
    final seen = <String>{};
    var installed = 0;
    for (final dirPath in dirs) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;
      await for (final entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is! File) continue;
        if (!isBiosArchive(entity.path)) continue;
        final abs = p.normalize(p.absolute(entity.path));
        if (!seen.add(abs)) continue;
        // Prefer scoring Neo Geo candidates; skip incompatible dumps.
        await installBiosArchive(abs);
        if (File(p.join(_systemDir, 'neogeo.zip')).existsSync() ||
            !p.basename(abs).toLowerCase().startsWith('neogeo')) {
          installed++;
        }
      }
    }
    return installed;
  }

  /// Before loading [romPath], pull BIOS from the ROM folder + library folders.
  static Future<BiosProvisionResult> ensureForRom(
    String romPath, {
    Iterable<String> extraDirs = const [],
  }) async {
    final romDir = p.dirname(p.normalize(p.absolute(romPath)));
    final dirs = <String>{romDir, ...extraDirs};

    final biosFound = await provisionFromDirs(dirs);

    // Also walk one level of sibling folders named bios/BIOS/fbneo.
    for (final name in ['bios', 'BIOS', 'fbneo', 'system']) {
      final sibling = Directory(p.join(romDir, name));
      if (sibling.existsSync()) {
        await provisionFromDirs([sibling.path]);
      }
    }

    final neo = looksLikeNeoGeo(p.basename(romPath));
    final hasNeo = hasNeogeoBios(romPath: romPath);
    return BiosProvisionResult(
      biosArchivesInstalled: biosFound,
      needsNeogeo: neo,
      hasNeogeo: hasNeo,
      systemDir: _systemDir,
      romDir: romDir,
    );
  }

  static String missingNeogeoMessage(BiosProvisionResult r) {
    final buf = StringBuffer()
      ..writeln('Neo Geo BIOS missing (neogeo.zip).')
      ..writeln('Checked:')
      ..writeln('  ${r.romDir}')
      ..writeln('  ${r.systemDir}');
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      buf.writeln(
        'GitHub APK builds omit personal BIOS (gitignored).\n'
        'Import neogeo.zip once, or rebuild the APK locally '
        'with assets/bios/neogeo.zip present.',
      );
    } else {
      buf.writeln(
        'Put neogeo.zip in assets/bios/ then rebuild, '
        'or place it next to your ROMs.',
      );
    }
    return buf.toString().trim();
  }
}

class BiosProvisionResult {
  const BiosProvisionResult({
    required this.biosArchivesInstalled,
    required this.needsNeogeo,
    required this.hasNeogeo,
    required this.systemDir,
    required this.romDir,
  });

  final int biosArchivesInstalled;
  final bool needsNeogeo;
  final bool hasNeogeo;
  final String systemDir;
  final String romDir;
}
