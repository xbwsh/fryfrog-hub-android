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

  static const double carouselHeightPhone = 250;
  static const double carouselHeightTablet = 340;
  static const double carouselHeightTv = 380;

  /// Tablet-landscape home carousel (full-bleed hero): height as a fraction
  /// of the viewport, clamped so short windows stay scrollable.
  static const double carouselHeightLandscapeFraction = 0.55;
  static const double carouselHeightLandscapeMin = 360;
  static const double carouselHeightLandscapeMax = 520;

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

  /// Height reserved under overlaid reader chrome (bottom bar area).
  static const double readerChromeExtent = 88;

  /// TXT ebook reader body text.
  static const double ebookTextSize = 17;
  static const double ebookTextLineHeight = 1.75;

  /// Video detail hero height (backdrop + poster row), excluding status bar.
  static const double videoHeroHeight = 300;
  static const double videoPosterWidth = 120;
  static const double videoEpisodeThumbWidth = 140;

  /// Circular watch-progress ring overlaid on the hero poster.
  static const double videoProgressRing = 44;

  // ── 播放器浮层（右侧选集抽屉 / 右下倍速面板）──────────────────────
  /// 抽屉最大宽度（dp）；小屏取 min(此值, 屏宽 × fraction)。
  static const double playerDrawerWidth = 352;

  /// 抽屉宽度占屏宽比例上限（窄屏时用它，避免抽屉顶满整屏）。
  static const double playerDrawerWidthFraction = 0.88;

  /// 选集「列表」样式缩略图宽（16:9）。
  static const double playerEpisodeThumbWidth = 88;

  /// 「数字」宫格单元最大宽；GridView 按它自适应列数（≈原型 minmax 52+gap）。
  static const double playerNumCellMaxExtent = 60;

  /// 倍速浮层宽度。
  static const double playerSpeedPanelWidth = 268;

  /// 倍速浮层距屏幕底部的距离（压在底栏控制条上方）。
  static const double playerSpeedPanelBottom = 78;

  /// 倍速浮层滑条拇指半径（刻度/气泡按它对齐行程两端）。
  static const double playerSpeedThumbRadius = 8;

  /// 倍速浮层「拖动气泡」固定宽（按中线定位）。
  static const double playerSpeedBubbleWidth = 64;

  /// 倍速浮层单个刻度标签的占位宽。
  static const double playerSpeedTickWidth = 32;

  /// 倍速浮层底部预设档位（0.5X/1.0X/1.5X/2.0X）按钮高。
  static const double playerSpeedChipHeight = 28;
}
