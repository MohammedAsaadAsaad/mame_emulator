class SaveSlotInfo {
  const SaveSlotInfo({
    required this.slot,
    required this.occupied,
    this.savedAt,
    this.romName,
    this.thumbnailPath,
    this.thumbnailRevision,
  });

  final int slot;
  final bool occupied;
  final DateTime? savedAt;
  final String? romName;
  final String? thumbnailPath;
  /// Busts Flutter's Image.file cache when overwriting the same path.
  final int? thumbnailRevision;
}

class LibraryGame {
  LibraryGame({
    required this.id,
    required this.title,
    required this.path,
    this.lastPlayed,
    this.favorite = false,
    this.artPath,
  });

  final String id;
  String title;
  /// Absolute path to the original ROM on disk (not copied into app storage).
  String path;
  DateTime? lastPlayed;
  bool favorite;
  /// Cached boxart path under app support (optional).
  String? artPath;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'path': path,
        'lastPlayed': lastPlayed?.toIso8601String(),
        'favorite': favorite,
        if (artPath != null) 'artPath': artPath,
      };

  factory LibraryGame.fromJson(Map<String, dynamic> json) => LibraryGame(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Unknown',
        path: json['path'] as String,
        lastPlayed: json['lastPlayed'] != null
            ? DateTime.tryParse(json['lastPlayed'] as String)
            : null,
        favorite: json['favorite'] as bool? ?? false,
        artPath: json['artPath'] as String?,
      );
}
