package com.fryfrog.hub.ui.navigation

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.fryfrog.hub.ui.theme.Dimens
import com.fryfrog.hub.ui.theme.Primary
import dev.chrisbanes.haze.HazeInputScale
import dev.chrisbanes.haze.HazeState
import dev.chrisbanes.haze.HazeStyle
import dev.chrisbanes.haze.HazeTint
import dev.chrisbanes.haze.hazeEffect

@Composable
fun FryfrogBottomBar(
    currentRoute: String?,
    onNavigate: (String) -> Unit,
    isAdmin: Boolean = true,
    hazeState: HazeState? = null
) {
    // 普通用户不显示媒体库 tab
    val visibleScreens = if (isAdmin) {
        bottomNavScreens
    } else {
        bottomNavScreens.filter { it != Screen.MediaLibraries }
    }
    // 悬浮圆角样式：左右留边 + 底部留边 + 阴影
    val shape = RoundedCornerShape(Dimens.radiusXl)

    // 液态玻璃：深色主题用暗色烟熏玻璃，浅色主题用白色磨砂；旧系统回退为高不透明度纯色
    val surfaceColor = MaterialTheme.colorScheme.surface
    val isDarkGlass = surfaceColor.luminance() < 0.5f
    val glassStyle = HazeStyle(
        backgroundColor = surfaceColor,
        tints = listOf(
            HazeTint(
                if (isDarkGlass) {
                    Color.Black.copy(alpha = 0.32f)
                } else {
                    Color.White.copy(alpha = 0.55f)
                }
            )
        ),
        fallbackTint = HazeTint(surfaceColor.copy(alpha = 0.95f)),
        blurRadius = Dimens.glassBlurRadius,
        noiseFactor = Dimens.glassNoise
    )
    // 边缘高光描边（模拟玻璃折射的镜面反光）
    val edgeBrush = Brush.linearGradient(
        listOf(
            Color.White.copy(alpha = Dimens.alphaGlassEdgeLight),
            Color.White.copy(alpha = Dimens.alphaGlassEdgeDark),
            Color.White.copy(alpha = Dimens.alphaGlassEdgeLight * 0.5f)
        )
    )

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Dimens.spacingXl)
            .navigationBarsPadding()
            .padding(bottom = Dimens.spacingSm)
            .shadow(elevation = 8.dp, shape = shape, clip = false)
            .clip(shape)
            .then(
                if (hazeState != null) {
                    Modifier.hazeEffect(state = hazeState, style = glassStyle) {
                        inputScale = HazeInputScale.Auto
                    }
                } else {
                    Modifier.background(surfaceColor.copy(alpha = 0.95f))
                }
            )
            // 顶部光泽渐变（玻璃上沿受光）
            .background(
                Brush.verticalGradient(
                    listOf(
                        Color.White.copy(alpha = Dimens.alphaGlassSheen),
                        Color.Transparent
                    )
                )
            )
            .border(Dimens.glassBorderWidth, edgeBrush, shape)
            .padding(horizontal = Dimens.spacingSm, vertical = Dimens.spacingXs)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            visibleScreens.forEach { screen ->
                val isSelected = currentRoute == screen.route

                val iconColor by animateColorAsState(
                    targetValue = if (isSelected) Primary else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                    animationSpec = spring(),
                    label = "iconColor"
                )

                val textColor by animateColorAsState(
                    targetValue = if (isSelected) Primary else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                    animationSpec = spring(),
                    label = "textColor"
                )

                Column(
                    modifier = Modifier
                        .clip(RoundedCornerShape(Dimens.radiusMd))
                        .clickable { onNavigate(screen.route) }
                        .padding(horizontal = Dimens.spacingSm, vertical = Dimens.spacingXs),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Icon(
                        imageVector = screen.icon,
                        contentDescription = null,
                        tint = iconColor,
                        modifier = Modifier.size(Dimens.iconSize)
                    )
                    Text(
                        text = stringResource(screen.titleResId),
                        style = MaterialTheme.typography.labelSmall,
                        color = textColor,
                        modifier = Modifier.padding(top = Dimens.spacingXxs)
                    )
                }
            }
        }
    }
}
