/// Media library admin DTOs (list / CRUD / browse / scan progress).
library;

class MediaLibrary {
  const MediaLibrary({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    this.subType,
    this.enabled = true,
    this.enableScraping = true,
    this.isAdult = false,
    this.sortOrder,
    this.description,
  });

  final int id;
  final String name;
  final String path;
  final String type; // VIDEO / MUSIC / COMIC / EBOOK / AUDIOBOOK
  final String? subType; // VIDEO only: MOVIE / TV / MIXED
  final bool enabled;
  final bool enableScraping;
  final bool isAdult;
  final int? sortOrder;
  final String? description;

  static const Map<String, String> _typeLabels = {
    'VIDEO': '视频',
    'MUSIC': '音乐',
    'COMIC': '漫画',
    'EBOOK': '电子书',
    'AUDIOBOOK': '有声书',
  };

  static const Map<String, String> _subTypeLabels = {
    'MOVIE': '电影',
    'TV': '电视剧',
    'MIXED': '混合',
  };

  String get typeLabel {
    final base = _typeLabels[type] ?? type;
    final sub = subType == null ? null : _subTypeLabels[subType];
    return sub == null ? base : '$base·$sub';
  }

  factory MediaLibrary.fromJson(Map<String, dynamic> json) => MediaLibrary(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    path: json['path'] as String? ?? '',
    type: json['type'] as String? ?? 'VIDEO',
    subType: json['subType'] as String?,
    enabled: json['enabled'] as bool? ?? true,
    enableScraping: json['enableScraping'] as bool? ?? true,
    isAdult: json['isAdult'] as bool? ?? false,
    sortOrder: (json['sortOrder'] as num?)?.toInt(),
    description: json['description'] as String?,
  );
}

/// One directory from `GET /media-libraries/browse`.
class LibraryDirItem {
  const LibraryDirItem({
    required this.name,
    required this.path,
    required this.writable,
  });

  final String name;
  final String path;
  final bool writable;

  factory LibraryDirItem.fromJson(Map<String, dynamic> json) => LibraryDirItem(
    name: json['name'] as String? ?? '',
    path: json['path'] as String? ?? '',
    writable: json['writable'] as bool? ?? false,
  );
}

/// Aggregated progress across all libraries during `POST /scan`.
class LibraryScanProgress {
  const LibraryScanProgress({
    required this.running,
    required this.total,
    required this.completed,
    required this.failed,
    required this.skipped,
    this.currentItem,
  });

  final bool running;
  final int total;
  final int completed;
  final int failed;
  final int skipped;
  final String? currentItem;

  int get done => completed + failed + skipped;
  double get percent => total == 0 ? 0 : done / total * 100;

  factory LibraryScanProgress.fromJson(Map<String, dynamic> json) =>
      LibraryScanProgress(
        running: json['running'] as bool? ?? false,
        total: (json['total'] as num?)?.toInt() ?? 0,
        completed: (json['completed'] as num?)?.toInt() ?? 0,
        failed: (json['failed'] as num?)?.toInt() ?? 0,
        skipped: (json['skipped'] as num?)?.toInt() ?? 0,
        currentItem: json['currentItem'] as String?,
      );
}

/// Per-library pipeline progress from `GET /media-libraries/{id}/pipeline-progress`.
class LibraryPipelineProgress {
  const LibraryPipelineProgress({
    required this.running,
    required this.stage,
    required this.percent,
    this.currentItem,
  });

  final bool running;
  final String stage;
  final double percent;
  final String? currentItem;

  factory LibraryPipelineProgress.fromJson(Map<String, dynamic> json) =>
      LibraryPipelineProgress(
        running: json['running'] as bool? ?? false,
        stage: json['stage'] as String? ?? 'idle',
        percent: (json['percent'] as num?)?.toDouble() ?? 0,
        currentItem: json['currentItem'] as String?,
      );
}
