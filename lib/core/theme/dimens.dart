/// Spacing / radius / size tokens. Never hardcode dp in feature code.
class Dimens {
  const Dimens._();

  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 12;
  static const double spacingLg = 16;
  static const double spacingXl = 24;
  static const double spacingXxl = 32;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 22;

  static const double posterWidth = 120;
  static const double posterHeight = 180;
  static const double posterWidthWide = 148;
  static const double posterHeightWide = 220;
  static const double posterWidthTv = 180;
  static const double posterHeightTv = 270;

  /// Title + author/narrator strip under a book cover in the shelf grid.
  /// Must fit two text lines (CJK ~1.15 line height) + top gap without overflow.
  static const double bookMetaExtent = 52;

  /// Title + year strip under a video poster in the library grid.
  static const double videoMetaExtent = 44;

  static const double carouselHeightPhone = 220;
  static const double carouselHeightTablet = 300;
  static const double carouselHeightTv = 380;

  static const double dockHeight = 64;
  static const double railWidthCompact = 72;
  static const double railWidthExpanded = 220;
  static const double tvNavWidth = 260;

  static const double maxFormWidth = 360;
  static const double maxContentTablet = 960;
  static const double maxContentTv = 1280;

  static const double focusBorder = 3;

  /// Comic reader page gap in continuous-scroll mode.
  static const double readerPageGap = 6;

  /// Video detail hero height (backdrop + poster row), excluding status bar.
  static const double videoHeroHeight = 300;
  static const double videoPosterWidth = 120;
  static const double videoEpisodeThumbWidth = 140;

  /// Circular watch-progress ring overlaid on the hero poster.
  static const double videoProgressRing = 44;
}
