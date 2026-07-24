package com.fryfrog.hub.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

data class AppDimens(
    // Spacing
    val spacingXxs: Dp = 2.dp,
    val spacingXs: Dp = 4.dp,
    val spacingSm: Dp = 6.dp,
    val spacingMd: Dp = 10.dp,
    val spacingLg: Dp = 14.dp,
    val spacingXl: Dp = 18.dp,
    val spacingXxl: Dp = 24.dp,

    // Corner Radius
    val radiusSm: Dp = 4.dp,
    val radiusMd: Dp = 6.dp,
    val radiusLg: Dp = 10.dp,
    val radiusXl: Dp = 14.dp,
    val radiusFull: Dp = 999.dp,

    // Media Card
    val cardMediaWidth: Dp = 110.dp,
    val cardMediaWidthTablet: Dp = 160.dp,
    val gridMinCardWidth: Dp = 90.dp,

    // Wide Media Card
    val cardWideWidth: Dp = 200.dp,
    val cardWideWidthTablet: Dp = 280.dp,
    val cardWideHeight: Dp = 120.dp,
    val cardWideHeightTablet: Dp = 160.dp,

    // Carousel
    val carouselHeight: Dp = 150.dp,
    val carouselHeightTablet: Dp = 320.dp,
    val indicatorSize: Dp = 6.dp,
    val indicatorSpacing: Dp = 3.dp,

    // Page Padding
    val pageHorizontalPadding: Dp = 12.dp,
    val pageVerticalPadding: Dp = 6.dp,

    // Component Sizes
    val iconSize: Dp = 20.dp,
    val chipIconSize: Dp = 14.dp,
    val chipCloseIconSize: Dp = 10.dp,
    val buttonHeight: Dp = 38.dp,
    val topBarHeight: Dp = 44.dp,
    val avatarSize: Dp = 36.dp,
    val avatarIconSize: Dp = 18.dp,
    val smallButtonSize: Dp = 26.dp,
    val smallIconSize: Dp = 14.dp,
    val dialogAvatarSize: Dp = 44.dp,
    val dialogIconSize: Dp = 22.dp,
    val switchWidth: Dp = 42.dp,
    val switchHeight: Dp = 22.dp,
    val switchThumbSize: Dp = 16.dp,
    val emptyStateIconSize: Dp = 48.dp,
    val listMaxHeight: Dp = 240.dp,

    // Alpha
    val alphaOverlay: Float = 0.7f,
    val alphaSubtle: Float = 0.8f,
    val alphaDisabled: Float = 0.38f
)

val PhoneDimens = AppDimens()

val TabletDimens = AppDimens(
    // Spacing - 平板加大
    spacingSm = 8.dp,
    spacingMd = 12.dp,
    spacingLg = 16.dp,
    spacingXl = 24.dp,
    spacingXxl = 32.dp,

    // Media Card - 平板加大
    gridMinCardWidth = 110.dp,

    // Component Sizes - 平板加大
    iconSize = 24.dp,
    chipIconSize = 18.dp,
    chipCloseIconSize = 14.dp,
    buttonHeight = 48.dp,
    topBarHeight = 56.dp,
    avatarSize = 44.dp,
    avatarIconSize = 22.dp,
    smallButtonSize = 32.dp,
    smallIconSize = 18.dp,
    dialogAvatarSize = 56.dp,
    dialogIconSize = 28.dp,
    switchWidth = 52.dp,
    switchHeight = 28.dp,
    switchThumbSize = 20.dp,
    emptyStateIconSize = 64.dp,
    listMaxHeight = 320.dp,

    // Page Padding - 平板加大
    pageHorizontalPadding = 16.dp,
    pageVerticalPadding = 8.dp
)

val LocalDimens = staticCompositionLocalOf { PhoneDimens }

object Dimens {
    val spacingXxs: Dp @Composable get() = LocalDimens.current.spacingXxs
    val spacingXs: Dp @Composable get() = LocalDimens.current.spacingXs
    val spacingSm: Dp @Composable get() = LocalDimens.current.spacingSm
    val spacingMd: Dp @Composable get() = LocalDimens.current.spacingMd
    val spacingLg: Dp @Composable get() = LocalDimens.current.spacingLg
    val spacingXl: Dp @Composable get() = LocalDimens.current.spacingXl
    val spacingXxl: Dp @Composable get() = LocalDimens.current.spacingXxl

    val radiusSm: Dp @Composable get() = LocalDimens.current.radiusSm
    val radiusMd: Dp @Composable get() = LocalDimens.current.radiusMd
    val radiusLg: Dp @Composable get() = LocalDimens.current.radiusLg
    val radiusXl: Dp @Composable get() = LocalDimens.current.radiusXl
    val radiusFull: Dp @Composable get() = LocalDimens.current.radiusFull

    val cardMediaWidth: Dp @Composable get() = LocalDimens.current.cardMediaWidth
    val cardMediaWidthTablet: Dp @Composable get() = LocalDimens.current.cardMediaWidthTablet
    val gridMinCardWidth: Dp @Composable get() = LocalDimens.current.gridMinCardWidth

    val cardWideWidth: Dp @Composable get() = LocalDimens.current.cardWideWidth
    val cardWideWidthTablet: Dp @Composable get() = LocalDimens.current.cardWideWidthTablet
    val cardWideHeight: Dp @Composable get() = LocalDimens.current.cardWideHeight
    val cardWideHeightTablet: Dp @Composable get() = LocalDimens.current.cardWideHeightTablet

    val carouselHeight: Dp @Composable get() = LocalDimens.current.carouselHeight
    val carouselHeightTablet: Dp @Composable get() = LocalDimens.current.carouselHeightTablet
    val indicatorSize: Dp @Composable get() = LocalDimens.current.indicatorSize
    val indicatorSpacing: Dp @Composable get() = LocalDimens.current.indicatorSpacing

    val pageHorizontalPadding: Dp @Composable get() = LocalDimens.current.pageHorizontalPadding
    val pageVerticalPadding: Dp @Composable get() = LocalDimens.current.pageVerticalPadding

    val iconSize: Dp @Composable get() = LocalDimens.current.iconSize
    val chipIconSize: Dp @Composable get() = LocalDimens.current.chipIconSize
    val chipCloseIconSize: Dp @Composable get() = LocalDimens.current.chipCloseIconSize
    val buttonHeight: Dp @Composable get() = LocalDimens.current.buttonHeight
    val topBarHeight: Dp @Composable get() = LocalDimens.current.topBarHeight
    val avatarSize: Dp @Composable get() = LocalDimens.current.avatarSize
    val avatarIconSize: Dp @Composable get() = LocalDimens.current.avatarIconSize
    val smallButtonSize: Dp @Composable get() = LocalDimens.current.smallButtonSize
    val smallIconSize: Dp @Composable get() = LocalDimens.current.smallIconSize
    val dialogAvatarSize: Dp @Composable get() = LocalDimens.current.dialogAvatarSize
    val dialogIconSize: Dp @Composable get() = LocalDimens.current.dialogIconSize
    val switchWidth: Dp @Composable get() = LocalDimens.current.switchWidth
    val switchHeight: Dp @Composable get() = LocalDimens.current.switchHeight
    val switchThumbSize: Dp @Composable get() = LocalDimens.current.switchThumbSize
    val emptyStateIconSize: Dp @Composable get() = LocalDimens.current.emptyStateIconSize
    val listMaxHeight: Dp @Composable get() = LocalDimens.current.listMaxHeight

    // Alpha - 常量，不需要响应式
    const val alphaOverlay = 0.7f
    const val alphaSubtle = 0.8f
    const val alphaDisabled = 0.38f
}
