import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../libretro/libretro_host.dart';
import '../models/library_models.dart';

/// Resolves arcade ROM stems → real titles (FBNeo gamelist) and caches
/// libretro Named_Boxarts thumbnails under app support.
class GameMetadataService {
  GameMetadataService();

  static const _gamelistUrl =
      'https://raw.githubusercontent.com/libretro/FBNeo/master/gamelist.txt';
  static const _thumbBase =
      'https://thumbnails.libretro.com/MAME/Named_Boxarts';

  Map<String, String> _titles = {};
  bool _loadingTitles = false;
  Completer<void>? _titlesReady;
  final Set<String> _thumbInFlight = {};

  Future<Directory> _metaRoot() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'mame_cabinet', 'metadata'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> thumbsDir() async {
    final dir = Directory(p.join((await _metaRoot()).path, 'boxarts'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _titlesCacheFile() async =>
      File(p.join((await _metaRoot()).path, 'arcade_titles.json'));

  /// Load cached titles, or download/parse FBNeo gamelist once (silent).
  Future<void> ensureTitlesLoaded() async {
    if (_titles.isNotEmpty) return;
    if (_titlesReady != null) return _titlesReady!.future;
    _titlesReady = Completer<void>();
    _loadingTitles = true;
    try {
      final cache = await _titlesCacheFile();
      if (await cache.exists()) {
        try {
          final map = jsonDecode(await cache.readAsString()) as Map<String, dynamic>;
          _titles = map.map((k, v) => MapEntry(k, v.toString()));
        } catch (_) {}
      }
      if (_titles.isEmpty) {
        await _downloadAndParseGamelist(cache);
      } else {
        // Refresh in background if cache is older than 30 days.
        final age = DateTime.now().difference(await cache.lastModified());
        if (age.inDays >= 30) {
          unawaited(_downloadAndParseGamelist(cache));
        }
      }
      _titlesReady!.complete();
    } catch (e) {
      debugPrint('GameMetadataService titles: $e');
      if (!_titlesReady!.isCompleted) _titlesReady!.complete();
    } finally {
      _loadingTitles = false;
    }
  }

  Future<void> _downloadAndParseGamelist(File cache) async {
    final res = await http.get(Uri.parse(_gamelistUrl)).timeout(
      const Duration(seconds: 60),
    );
    if (res.statusCode != 200) {
      throw StateError('gamelist HTTP ${res.statusCode}');
    }
    final parsed = _parseGamelist(res.body);
    if (parsed.isEmpty) return;
    _titles = parsed;
    await cache.writeAsString(jsonEncode(parsed));
  }

  /// FBNeo `gamelist.txt` ASCII table → stem → full name.
  static Map<String, String> _parseGamelist(String body) {
    final out = <String, String>{};
    for (final line in body.split('\n')) {
      if (!line.startsWith('|')) continue;
      final cols = line.split('|');
      if (cols.length < 5) continue;
      final stem = cols[1].trim();
      final full = cols[3].trim();
      if (stem.isEmpty || full.isEmpty) continue;
      if (stem == 'name' || stem.startsWith('-')) continue;
      out[stem] = full;
    }
    return out;
  }

  String stemForPath(String path) => CoreLocator.romStem(p.basename(path));

  /// Real game name if known, else basename without extension.
  String displayTitleForPath(String path) {
    final stem = stemForPath(path);
    return _titles[stem] ?? p.basenameWithoutExtension(path);
  }

  String? titleForStem(String stem) => _titles[stem];

  bool get hasTitles => _titles.isNotEmpty;
  bool get loadingTitles => _loadingTitles;

  File thumbFileForStem(String stem, Directory thumbs) =>
      File(p.join(thumbs.path, '$stem.png'));

  /// Cached boxart path if already downloaded.
  Future<String?> cachedThumbPath(String path) async {
    final stem = stemForPath(path);
    final file = thumbFileForStem(stem, await thumbsDir());
    if (await file.exists() && await file.length() > 0) return file.path;
    return null;
  }

  /// Silently download boxart for [path] if missing. Returns local path or null.
  Future<String?> ensureThumbnail(String path) async {
    final stem = stemForPath(path);
    if (stem.isEmpty) return null;
    final dir = await thumbsDir();
    final dest = thumbFileForStem(stem, dir);
    if (await dest.exists() && await dest.length() > 0) return dest.path;

    await ensureTitlesLoaded();
    final title = _titles[stem];
    if (title == null || title.isEmpty) return null;
    if (!_thumbInFlight.add(stem)) return null;

    try {
      final url = '$_thumbBase/${Uri.encodeComponent(title)}.png';
      final res = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 20),
      );
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      await dest.writeAsBytes(res.bodyBytes, flush: true);
      return dest.path;
    } catch (e) {
      debugPrint('thumb $stem: $e');
      return null;
    } finally {
      _thumbInFlight.remove(stem);
    }
  }

  /// Update [games] titles from the database and kick off silent thumb fetches.
  /// Calls [onChanged] when a title or thumb becomes available.
  Future<void> enrichGames(
    List<LibraryGame> games, {
    void Function()? onChanged,
    Future<void> Function(List<LibraryGame> games)? persist,
  }) async {
    await ensureTitlesLoaded();
    var titlesChanged = false;
    for (final g in games) {
      final resolved = displayTitleForPath(g.path);
      if (resolved != g.title && _titles.containsKey(stemForPath(g.path))) {
        g.title = resolved;
        titlesChanged = true;
      }
      // Keep artPath if file still exists.
      if (g.artPath != null && !File(g.artPath!).existsSync()) {
        g.artPath = null;
        titlesChanged = true;
      }
    }
    if (titlesChanged) {
      if (persist != null) await persist(games);
      onChanged?.call();
    }

    // Silent thumbnails — one at a time to avoid hammering the CDN.
    for (final g in games) {
      final path = await ensureThumbnail(g.path);
      if (path != null && g.artPath != path) {
        g.artPath = path;
        if (persist != null) await persist(games);
        onChanged?.call();
      }
    }
  }
}
