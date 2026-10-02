import 'common.dart';

/// Bookshelf (ebook / comic / audiobook) DTOs.

/// Bookshelf segment kinds matching backend routers.
enum BookShelfKind {
  ebook('/api/v1/ebooks'),
  comic('/api/v1/comics'),
  audiobook('/api/v1/audiobooks');

  const BookShelfKind(this.basePath);
  final String basePath;

  String coverPath(int id) => '$basePath/$id/cover';
  String detailPath(int id) => '$basePath/$id';

  double get coverAspect => switch (this) {
    BookShelfKind.ebook => 2 / 3,
    BookShelfKind.comic => 5 / 7,
    BookShelfKind.audiobook => 1,
  };
}

class BookItem {
  const BookItem({
    required this.id,
    required this.title,
    this.author,
    this.narrator,
    this.publisher,
    this.overview,
    this.series,
    this.seriesPart,
    this.coverUrl,
    this.positionPercent,
    this.chapterIndex,
    this.pageCount,
    this.trackCount,
  });

  final int id;
  final String title;
  final String? author;
  final String? narrator;
  final String? publisher;
  final String? overview;
  final String? series;
  final int? seriesPart;
  final String? coverUrl;
  final double? positionPercent;
  final int? chapterIndex;
  final int? pageCount;
  final int? trackCount;

  String get displayTitle => title.isEmpty ? '(未命名)' : title;
  String get subtitle {
    final parts = <String>[
      if (author != null && author!.isNotEmpty) author!,
      if (narrator != null && narrator!.isNotEmpty) '演播：${narrator!}',
    ];
    return parts.join(' · ');
  }

  factory BookItem.fromJson(Map<String, dynamic> json) => BookItem(
    id: (json['id'] as num?)?.toInt() ?? 0,
    title: json['title'] as String? ?? '',
    author: json['author'] as String?,
    narrator: json['narrator'] as String?,
    publisher: json['publisher'] as String?,
    overview: json['overview'] as String?,
    series: json['series'] as String?,
    seriesPart: (json['seriesPart'] as num?)?.toInt(),
    coverUrl: readCoverJson(json),
    positionPercent:
        ((json['progressPercent'] ?? json['positionPercent']) as num?)
            ?.toDouble(),
    chapterIndex: (json['chapterIndex'] as num?)?.toInt(),
    pageCount: (json['pageCount'] as num?)?.toInt(),
    trackCount: (json['trackCount'] as num?)?.toInt(),
  );
}

class ScrapeProviderInfo {
  const ScrapeProviderInfo({required this.source, required this.displayName});

  final String source;
  final String displayName;

  factory ScrapeProviderInfo.fromJson(Map<String, dynamic> json) =>
      ScrapeProviderInfo(
        source: json['source'] as String? ?? '',
        displayName:
            json['displayName'] as String? ?? json['source'] as String? ?? '',
      );
}

class ScrapeResult {
  const ScrapeResult({
    required this.source,
    required this.sourceId,
    required this.title,
    this.author,
    this.overview,
    this.coverUrl,
    this.pubYear,
    this.rating,
  });

  final String source;
  final String sourceId;
  final String title;
  final String? author;
  final String? overview;
  final String? coverUrl;
  final int? pubYear;
  final double? rating;

  factory ScrapeResult.fromJson(Map<String, dynamic> json) => ScrapeResult(
    source: json['source'] as String? ?? '',
    sourceId: json['sourceId'] as String? ?? '',
    title: (json['title'] ?? json['name']) as String? ?? '(未命名)',
    author: json['author'] as String?,
    overview: json['overview'] as String?,
    coverUrl: readCoverJson(json),
    pubYear: (json['pubYear'] as num?)?.toInt(),
    rating: (json['rating'] as num?)?.toDouble(),
  );
}

class BookChapter {
  const BookChapter({
    required this.id,
    required this.chapterIndex,
    this.title,
    this.pageCount,
    this.type,
  });

  final int id;
  final int chapterIndex;
  final String? title;
  final int? pageCount;
  final String? type;

  String get label =>
      (title != null && title!.isNotEmpty) ? title! : '第 ${chapterIndex + 1} 话';

  factory BookChapter.fromJson(Map<String, dynamic> json) => BookChapter(
    id: (json['id'] as num?)?.toInt() ?? 0,
    chapterIndex: (json['chapterIndex'] as num?)?.toInt() ?? 0,
    title: json['title'] as String?,
    pageCount: (json['pageCount'] as num?)?.toInt(),
    type: json['type'] as String?,
  );
}

/// Reading progress from comic detail / `PUT /comics/{id}/progress`.
class ReadingProgress {
  const ReadingProgress({
    this.chapterIndex,
    this.pageIndex,
    this.completed = false,
    this.progressPercent,
  });

  final int? chapterIndex;
  final int? pageIndex;
  final bool completed;
  final double? progressPercent;

  bool get hasPosition => chapterIndex != null || pageIndex != null;

  factory ReadingProgress.fromJson(Map<String, dynamic> json) =>
      ReadingProgress(
        chapterIndex: (json['chapterIndex'] as num?)?.toInt(),
        pageIndex: (json['pageIndex'] as num?)?.toInt(),
        completed: json['completed'] == true,
        // Ebook progress uses `positionPercent`, comic uses `progressPercent`.
        progressPercent:
            ((json['progressPercent'] ?? json['positionPercent']) as num?)
                ?.toDouble(),
      );
}

/// Detail payload of `/api/v1/{ebooks|comics|audiobooks}/{id}`.
class BookDetail {
  const BookDetail({
    required this.id,
    required this.title,
    this.author,
    this.narrator,
    this.overview,
    this.series,
    this.seriesPart,
    this.metadataSource,
    this.sourceId,
    this.pubYear,
    this.rating,
    this.totalChapters,
    this.format,
    this.coverUrl,
    this.positionPercent,
    this.progress,
    this.chapters = const [],
  });

  final int id;
  final String title;
  final String? author;
  final String? narrator;
  final String? overview;
  final String? series;
  final int? seriesPart;
  final String? metadataSource;
  final String? sourceId;
  final int? pubYear;
  final double? rating;
  final int? totalChapters;
  final String? format;
  final String? coverUrl;
  final double? positionPercent;
  final ReadingProgress? progress;
  final List<BookChapter> chapters;

  /// Ebook format that supports online reading (backend gate: TXT only).
  bool get isReadableText => (format ?? '').toUpperCase() == 'TXT';

  String get displayTitle => title.isEmpty ? '(未命名)' : title;
  String get subtitle {
    final parts = <String>[
      if (author != null && author!.isNotEmpty) author!,
      if (narrator != null && narrator!.isNotEmpty) '演播：${narrator!}',
    ];
    return parts.join(' · ');
  }

  String? get coverPath =>
      (coverUrl != null && coverUrl!.isNotEmpty) ? coverUrl : null;

  String get metadataSourceText => switch (metadataSource) {
    'scrape' => '已刮削',
    'manual' => '手动',
    _ => '扫描',
  };

  /// Copy with the chapter TOC fetched from a side endpoint (ebook TXT).
  BookDetail withChapters(List<BookChapter> list) => BookDetail(
    id: id,
    title: title,
    author: author,
    narrator: narrator,
    overview: overview,
    series: series,
    seriesPart: seriesPart,
    metadataSource: metadataSource,
    sourceId: sourceId,
    pubYear: pubYear,
    rating: rating,
    totalChapters: totalChapters,
    format: format,
    coverUrl: coverUrl,
    positionPercent: positionPercent,
    progress: progress,
    chapters: list,
  );

  factory BookDetail.fromJson(Map<String, dynamic> json) => BookDetail(
    id: (json['id'] as num?)?.toInt() ?? 0,
    title: json['title'] as String? ?? '',
    author: json['author'] as String?,
    narrator: json['narrator'] as String?,
    overview: json['overview'] as String?,
    series: json['series'] as String?,
    seriesPart: (json['seriesPart'] as num?)?.toInt(),
    metadataSource: json['metadataSource'] as String?,
    sourceId: json['sourceId'] as String?,
    pubYear: (json['pubYear'] as num?)?.toInt(),
    rating: (json['rating'] as num?)?.toDouble(),
    totalChapters: (json['totalChapters'] as num?)?.toInt(),
    format: json['format'] as String?,
    coverUrl: readCoverJson(json),
    positionPercent:
        ((json['progressPercent'] ??
                    (json['progress'] is Map<String, dynamic>
                        ? (json['progress']
                              as Map<String, dynamic>)['progressPercent']
                        : null) ??
                    json['positionPercent'])
                as num?)
            ?.toDouble(),
    progress: json['progress'] is Map<String, dynamic>
        ? ReadingProgress.fromJson(json['progress'] as Map<String, dynamic>)
        : null,
    chapters: ((json['chapters'] ?? json['tracks']) as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(BookChapter.fromJson)
        .toList(growable: false),
  );
}

/// One TXT chapter's body from `GET /api/v1/ebooks/{id}/content`.
class EbookChapterContent {
  const EbookChapterContent({
    required this.index,
    required this.title,
    required this.text,
    this.chapterCount = 0,
  });

  final int index;
  final String title;
  final String text;
  final int chapterCount;

  factory EbookChapterContent.fromJson(Map<String, dynamic> json) =>
      EbookChapterContent(
        index: (json['index'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? '',
        text: json['text'] as String? ?? '',
        chapterCount: (json['chapterCount'] as num?)?.toInt() ?? 0,
      );
}
