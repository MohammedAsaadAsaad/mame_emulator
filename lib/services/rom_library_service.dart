import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/library_models.dart';
import 'system_bios_service.dart';

/// Persistent ROM library. Save states / thumbnails live under app support.
///
/// Desktop indexes games at their original paths. On Android/iOS, ROMs are
/// copied into an app-private `roms/` folder so Neo Geo BIOS and CPS `.key`
/// files can be written beside each game (external storage is often read-only).
class RomLibraryService {
  static const _manifestName = 'library.json';

  Future<Directory> appDataRoot() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'mame_cabinet'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> libraryMetaDir() async {
    final dir = Directory(p.join((await appDataRoot()).path, 'library'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> saveStatesDir() async {
    final dir = Directory(p.join((await appDataRoot()).path, 'savestates'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> thumbnailsDir() async {
    final dir = Directory(p.join((await appDataRoot()).path, 'save_thumbnails'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// App-owned ROM folder (Android/iOS). Writable so we can place BIOS/keys beside games.
  Future<Directory> romsDir() async {
    final dir = Directory(p.join((await appDataRoot()).path, 'roms'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// On mobile, copy [path] into app-private `roms/` so BIOS/keys can sit beside the ZIP.
  /// Desktop keeps the original path (writable project / user folders).
  Future<String> ensurePlayableRomPath(String path) async {
    final abs = p.normalize(p.absolute(path));
    if (!File(abs).existsSync()) {
      throw StateError('ROM not found: $abs');
    }
    if (!Platform.isAndroid && !Platform.isIOS) return abs;

    final destDir = await romsDir();
    final destPath = p.join(destDir.path, p.basename(abs));
    if (p.equals(abs, destPath)) return destPath;

    final dest = File(destPath);
    final src = File(abs);
    final needsCopy = !dest.existsSync() ||
        dest.lengthSync() != src.lengthSync() ||
        dest.lastModifiedSync().isBefore(src.lastModifiedSync());
    if (needsCopy) {
      await src.copy(destPath);
    }
    return destPath;
  }

  Future<File> _manifest() async =>
      File(p.join((await libraryMetaDir()).path, _manifestName));

  /// Stable id from absolute path so same basename in different folders is unique.
  static String idForPath(String path) {
    final abs = p.normalize(p.absolute(path));
    var hash = 0;
    for (final c in abs.codeUnits) {
      hash = 0x1fffffff & (hash + c);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= hash >> 11;
    final base = p
        .basenameWithoutExtension(abs)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return '${base}_${hash.toRadixString(16)}';
  }

  Future<List<LibraryGame>> loadAll() async {
    final file = await _manifest();
    if (!await file.exists()) {
      return [];
    }
    try {
      final list = jsonDecode(await file.readAsString()) as List<dynamic>;
      return list
          .map((e) => LibraryGame.fromJson(e as Map<String, dynamic>))
          .where((g) => File(g.path).existsSync())
          .toList()
        ..sort((a, b) => (b.lastPlayed ?? DateTime(1970))
            .compareTo(a.lastPlayed ?? DateTime(1970)));
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<LibraryGame> games) async {
    final file = await _manifest();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(games.map((g) => g.toJson()).toList()),
    );
  }

  /// Persist an updated library list (e.g. after metadata enrichment).
  Future<void> saveAll(List<LibraryGame> games) => _save(games);

  /// Index a ROM. On mobile, copies into app-private storage first.
  Future<LibraryGame> importPath(String path) async {
    final playable = await ensurePlayableRomPath(path);
    if (SystemBiosService.isBiosArchive(playable)) {
      await SystemBiosService.installBiosArchive(playable);
      return LibraryGame(
        id: idForPath(playable),
        title: p.basenameWithoutExtension(playable),
        path: playable,
      );
    }

    final games = await loadAll();
    final existing = games.where((g) => p.equals(g.path, playable)).firstOrNull;
    if (existing != null) return existing;

    // Prefer updating an entry that still points at the pre-copy path.
    final absIn = p.normalize(p.absolute(path));
    final staleIdx = games.indexWhere((g) => p.equals(g.path, absIn));
    if (staleIdx >= 0 && !p.equals(games[staleIdx].path, playable)) {
      games[staleIdx].path = playable;
      await _save(games);
      return games[staleIdx];
    }

    final game = LibraryGame(
      id: idForPath(playable),
      title: p.basenameWithoutExtension(playable),
      path: playable,
    );
    games.add(game);
    await _save(games);
    return game;
  }

  /// Scan a folder for arcade zips and index them in place (no copy).
  Future<int> scanFolder(String folderPath) async {
    final dir = Directory(folderPath);
    if (!dir.existsSync()) return 0;
    await SystemBiosService.provisionFromDirs([folderPath]);
    final games = await loadAll();
    final known = games.map((g) => p.normalize(g.path)).toSet();
    var added = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final lower = entity.path.toLowerCase();
      if (!lower.endsWith('.zip') && !lower.endsWith('.7z')) continue;
      if (SystemBiosService.isBiosArchive(entity.path)) continue;
      final abs = p.normalize(p.absolute(entity.path));
      if (known.contains(abs)) continue;
      games.add(LibraryGame(
        id: idForPath(abs),
        title: p.basenameWithoutExtension(abs),
        path: abs,
      ));
      known.add(abs);
      added++;
    }
    if (added > 0) await _save(games);
    return added;
  }

  Future<void> markPlayed(LibraryGame game) async {
    final games = await loadAll();
    final i = games.indexWhere((g) => g.id == game.id);
    if (i < 0) return;
    games[i].lastPlayed = DateTime.now();
    // Refresh path in case it was relative historically.
    games[i].path = p.normalize(p.absolute(games[i].path));
    await _save(games);
  }

  Future<void> toggleFavorite(LibraryGame game) async {
    final games = await loadAll();
    final i = games.indexWhere((g) => g.id == game.id);
    if (i < 0) return;
    games[i].favorite = !games[i].favorite;
    await _save(games);
  }

  /// Remove library entry only — never deletes the original ROM file.
  Future<void> remove(LibraryGame game) async {
    final games = await loadAll();
    games.removeWhere((g) => g.id == game.id);
    await _save(games);
  }
}
