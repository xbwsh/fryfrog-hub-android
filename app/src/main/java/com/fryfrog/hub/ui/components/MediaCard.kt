package com.fryfrog.hub.ui.components

import android.content.res.Configuration
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.fryfrog.hub.R
import com.fryfrog.hub.ui.theme.Dimens
import com.fryfrog.hub.ui.theme.Gold

/**
 * 条目标题：有 logo 时用图片替代文字，加载失败或缺失时回退到文字。
 * 横版 logo 限高，竖版 logo 限宽，避免竖长条被压成细线。
 * 竖图尺寸可通过 [logoPortraitMaxWidth]/[logoPortraitMaxHeight] 单独放宽（如详情页 Hero）。
 * [logoBackdropAlpha] 默认 0（无底板）；在浅色背景上展示白字 logo 时可传深色底板。
 */
@Composable
fun MediaTitle(
    title: String,
    logoUrl: String?,
    modifier: Modifier = Modifier,
    textStyle: TextStyle = MaterialTheme.typography.bodyMedium,
    color: Color = Color.Unspecified,
    maxLines: Int = 1,
    logoMaxHeight: Dp = Dimens.logoMaxHeight,
    logoMaxWidth: Dp = Dimens.logoMaxWidth,
    logoPortraitMaxWidth: Dp = logoMaxWidth,
    logoPortraitMaxHeight: Dp = logoMaxHeight * 2.5f,
    logoBackdropAlpha: Float = 0f
) {
    var logoFailed by remember(logoUrl) { mutableStateOf(false) }
    // null = 未知/横图，true = 竖图（加载完成后根据宽高比设置）
    var isPortrait by remember(logoUrl) { mutableStateOf<Boolean?>(null) }

    if (logoUrl != null && !logoFailed) {
        val sizeModifier = if (isPortrait == true) {
            Modifier.widthIn(max = logoPortraitMaxWidth).heightIn(max = logoPortraitMaxHeight)
        } else {
            Modifier.heightIn(max = logoMaxHeight)
        }
        if (logoBackdropAlpha > 0f) {
            // 深色圆角底板：浅色背景上白字 logo 仍可见
            Box(
                modifier = modifier
                    .clip(RoundedCornerShape(Dimens.radiusSm))
                    .background(Color.Black.copy(alpha = logoBackdropAlpha))
                    .padding(horizontal = Dimens.spacingSm, vertical = Dimens.spacingXxs)
            ) {
                AsyncImage(
                    model = logoUrl,
                    contentDescription = title,
                    modifier = sizeModifier,
                    contentScale = ContentScale.Fit,
                    onSuccess = { state ->
                        val drawable = state.result.drawable
                        val width = drawable.intrinsicWidth
                        val height = drawable.intrinsicHeight
                        if (width > 0 && height > 0) {
                            isPortrait = height > width
                        }
                    },
                    onError = { logoFailed = true }
                )
            }
        } else {
            AsyncImage(
                model = logoUrl,
                contentDescription = title,
                modifier = modifier.then(sizeModifier),
                contentScale = ContentScale.Fit,
                onSuccess = { state ->
                    val drawable = state.result.drawable
                    val width = drawable.intrinsicWidth
                    val height = drawable.intrinsicHeight
                    if (width > 0 && height > 0) {
                        isPortrait = height > width
                    }
                },
                onError = { logoFailed = true }
            )
        }
    } else {
        Text(
            text = title,
            style = textStyle,
            color = color,
            maxLines = maxLines,
            overflow = TextOverflow.Ellipsis,
            modifier = modifier
        )
    }
}

@Composable
fun MediaCard(
    title: String,
    subtitle: String?,
    coverUrl: String?,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    square: Boolean = false,
    rating: Double? = null,
    resolutions: List<String>? = null
) {
    val configuration = LocalConfiguration.current
    val isTablet = configuration.screenWidthDp >= 600
    val cardWidth = if (isTablet) Dimens.cardMediaWidthTablet else Dimens.cardMediaWidth

    Column(
        modifier = modifier
            .width(cardWidth)
            .clip(RoundedCornerShape(Dimens.radiusMd))
            .clickable(onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(if (square) 1f else 0.7f)
                .clip(RoundedCornerShape(Dimens.radiusMd))
                .background(MaterialTheme.colorScheme.surfaceVariant)
        ) {
            if (coverUrl != null) {
                AsyncImage(
                    model = coverUrl,
                    contentDescription = title,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop,
                    alignment = Alignment.TopCenter
                )
            } else {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = title.take(1),
                        style = MaterialTheme.typography.headlineMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            // 左上角评分徽章（金黄字 + 半透明黑底）
            if (rating != null) {
                Box(
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(Dimens.spacingXs)
                        .clip(RoundedCornerShape(Dimens.radiusMd))
                        .background(Color.Black.copy(alpha = Dimens.alphaOverlay))
                        .padding(horizontal = Dimens.spacingXs, vertical = Dimens.spacingXxs)
                ) {
                    Text(
                        text = String.format("%.1f", rating),
                        style = MaterialTheme.typography.labelSmall,
                        color = Gold,
                        fontWeight = FontWeight.Bold
                    )
                }
            }

            // 右下角分辨率徽标（如 "4K" 或 "4K · 1080p"）
            if (!resolutions.isNullOrEmpty()) {
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(Dimens.spacingXs)
                        .clip(RoundedCornerShape(Dimens.radiusMd))
                        .background(Color.Black.copy(alpha = Dimens.alphaOverlay))
                        .padding(horizontal = Dimens.spacingXs, vertical = Dimens.spacingXxs)
                ) {
                    Text(
                        text = resolutions.joinToString(" · "),
                        style = MaterialTheme.typography.labelSmall,
                        color = Color.White,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(Dimens.spacingSm))

        Text(
            text = title,
            style = MaterialTheme.typography.bodyMedium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.fillMaxWidth()
        )

        if (subtitle != null) {
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
fun SectionHeader(
    title: String,
    subtitle: String? = null,
    onSeeAll: (() -> Unit)? = null,
    onTitleClick: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = Dimens.pageHorizontalPadding, vertical = Dimens.pageVerticalPadding),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            verticalAlignment = Alignment.Bottom,
            modifier = if (onTitleClick != null) Modifier.clickable(onClick = onTitleClick) else Modifier
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onBackground
            )
            if (onTitleClick != null) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onBackground,
                    modifier = Modifier
                        .padding(bottom = 2.dp)
                        .size(20.dp)
                )
            }
            if (subtitle != null) {
                Text(
                    text = " $subtitle",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(bottom = 2.dp)
                )
            }
        }

        if (onSeeAll != null) {
            Text(
                text = stringResource(R.string.see_all),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.clickable(onClick = onSeeAll)
            )
        }
    }
}

@Composable
fun WideMediaCard(
    title: String,
    subtitle: String?,
    coverUrl: String?,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    fixedSize: Boolean = true,
    clipShape: Shape = RoundedCornerShape(Dimens.radiusLg),
    bottomContentPadding: Dp? = null,
    resolutions: List<String>? = null
) {
    val configuration = LocalConfiguration.current
    val isTablet = configuration.screenWidthDp >= 600
    val cardWidth = if (isTablet) Dimens.cardWideWidthTablet else Dimens.cardWideWidth
    val cardHeight = if (isTablet) Dimens.cardWideHeightTablet else Dimens.cardWideHeight

    Box(
        modifier = modifier
            .then(if (fixedSize) Modifier.width(cardWidth).height(cardHeight) else Modifier)
            .clip(clipShape)
            .clickable(onClick = onClick)
    ) {
        if (coverUrl != null) {
            AsyncImage(
                model = coverUrl,
                contentDescription = title,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
                alignment = Alignment.TopCenter
            )
        } else {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.surfaceVariant)
            )
        }

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(Color.Transparent, Color.Black.copy(alpha = Dimens.alphaOverlay))
                    )
                )
        )

        Column(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(
                    start = Dimens.spacingLg,
                    top = Dimens.spacingLg,
                    end = Dimens.spacingLg,
                    bottom = bottomContentPadding ?: Dimens.spacingLg
                )
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleLarge,
                color = Color.White,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )

            if (subtitle != null) {
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.White.copy(alpha = Dimens.alphaSubtle),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }

        // 右下角分辨率徽标（如 "4K" 或 "4K · 1080p"）
        if (!resolutions.isNullOrEmpty()) {
            Box(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(Dimens.spacingSm)
                    .clip(RoundedCornerShape(Dimens.radiusSm))
                    .background(Color.Black.copy(alpha = Dimens.alphaOverlay))
                    .padding(horizontal = Dimens.spacingXs, vertical = Dimens.spacingXxs)
            ) {
                Text(
                    text = resolutions.joinToString(" · "),
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.White,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}
