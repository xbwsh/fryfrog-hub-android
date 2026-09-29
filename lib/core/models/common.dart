/// Shared envelope DTOs and JSON helpers for all domains.
library;

class ApiResponse<T> {
  ApiResponse({required this.success, this.message, this.data});
  final bool success;
  final String? message;
  final T? data;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T? Function(Object? raw) parseData,
  ) => ApiResponse(
    success: json['success'] == true,
    message: json['message'] as String?,
    data: parseData(json['data']),
  );
}

class PageResponse<T> {
  PageResponse({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  factory PageResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parseItem,
  ) {
    final raw = json['content'] as List? ?? const [];
    return PageResponse(
      content: raw
          .whereType<Map<String, dynamic>>()
          .map(parseItem)
          .toList(growable: false),
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 0,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    );
  }
}

/// First non-empty cover-like field from a DTO map.
String? readCoverJson(Map<String, dynamic> json) {
  for (final key in const [
    'coverUrl',
    'cover_url',
    'cover',
    'coverPath',
    'cover_path',
  ]) {
    final v = json[key];
    if (v is String && v.isNotEmpty) return v;
  }
  return null;
}
