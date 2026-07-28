import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../libretro/libretro_host.dart';
import '../models/library_models.dart';
import 'system_bios_service.dart';

/// Persistent ROM library that indexes games at their **original paths**
/// (no copy into app storage). Save states / thumbnails live under app support.
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
      return _seedFromProjectRoms();
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

  Future<List<LibraryGame>> _seedFromProjectRoms() async {
    final dir = Directory(p.join(CoreLocator.projectRoot, 'roms'));
    if (!dir.existsSync()) return [];
    final games = <LibraryGame>[];
    for (final f in dir.listSync().whereType<File>()) {
      final lower = f.path.toLowerCase();
      if (!lower.endsWith('.zip') && !lower.endsWith('.7z')) continue;
      if (SystemBiosService.isBiosArchive(f.path)) {
        await SystemBiosService.installBiosArchive(f.path);
        continue;
      }
      final abs = p.normalize(p.absolute(f.path));
      games.add(LibraryGame(
        id: idForPath(abs),
        title: p.basenameWithoutExtension(abs),
        path: abs,
      ));
    }
    if (games.isNotEmpty) await _save(games);
    return games;
  }

  Future<void> _save(List<LibraryGame> games) async {
    final file = await _manifest();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(games.map((g) => g.toJson()).toList()),
    );
  }

  /// Persist an updated library list (e.g. after metadata enrichment).
  Future<void> saveAll(List<LibraryGame> games) => _save(games);

  /// Index a ROM at its current location — does **not** copy the file.
  Future<LibraryGame> importPath(String path) async {
    final abs = p.normalize(p.absolute(path));
    if (!File(abs).existsSync()) {
      throw StateError('ROM not found: $abs');
    }

    if (SystemBiosService.isBiosArchive(abs)) {
      await SystemBiosService.installBiosArchive(abs);
      return LibraryGame(
        id: idForPath(abs),
        title: p.basenameWithoutExtension(abs),
        path: abs,
      );
    }

    final games = await loadAll();
    final existing = games.where((g) => p.equals(g.path, abs)).firstOrNull;
    if (existing != null) return existing;

    final game = LibraryGame(
      id: idForPath(abs),
      title: p.basenameWithoutExtension(abs),
      path: abs,
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
