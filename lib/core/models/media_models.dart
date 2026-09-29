/// Barrel: domain DTOs split by media type.
///
/// Prefer importing a domain file (`video.dart` / `books.dart` / …)
/// in new code; this export keeps existing `media_models.dart` imports working.
library;

export 'books.dart';
export 'common.dart';
export 'library.dart';
export 'music.dart';
export 'user.dart';
export 'video.dart';
