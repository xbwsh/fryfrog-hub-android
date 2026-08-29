package com.fryfrog.hub.ui.navigation

import android.view.HapticFeedbackConstants
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.selection.selectable
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import com.fryfrog.hub.ui.theme.Dimens
import dev.chrisbanes.haze.HazeInputScale
import dev.chrisbanes.haze.HazeState
import dev.chrisbanes.haze.HazeStyle
import dev.chrisbanes.haze.hazeEffect

/**
 * 完全重写的底部导航 - 液态玻璃分段样式
 *
 * 设计对齐用户参考图 Week/Month/Year：
 * - 外层为悬浮胶囊，整块使用 Haze 默认模糊（HazeStyle(tint=null)）
 * - 内层轨道为浅灰 pill，滑动胶囊为白色液态玻璃 pill（同样 Haze 默认）
 * - 胶囊内通过“双层 Row + clip”实现文字仅在胶囊内变色 + 1.06f 透镜放大
 */
@Composable
fun FryfrogBottomBar(
    currentRoute: String?,
    onNavigate: (String) -> Unit,
    isAdmin: Boolean = true,
    hazeState: HazeState? = null
) {
    val screens = if (isAdmin) bottomNavScreens else bottomNavScreens.filter { it != Screen.MediaLibraries }
    if (screens.isEmpty()) return

    val outerShape = RoundedCornerShape(Dimens.radiusXl)
    val pillShape = RoundedCornerShape(Dimens.radiusFull)
    val selectedIndex = screens.indexOfFirst { it.route == currentRoute }.takeIf { it >= 0 } ?: 0
    val view = LocalView.current

    // Haze 默认设置
    val hazeStyle = HazeStyle(tint = null)

    // 选中/未选中色（未选中灰如参考图，未选中红改用主题主色保持一致性）
    val selectedColor = MaterialTheme.colorScheme.primary
    val unselectedColor = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.62f)

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Dimens.spacingXl)
            .navigationBarsPadding()
            .padding(bottom = Dimens.spacingSm)
            .shadow(elevation = 10.dp, shape = outerShape, clip = false)
            .clip(outerShape)
            .then(
                if (hazeState != null) {
                    Modifier.hazeEffect(state = hazeState, style = hazeStyle) {
                        inputScale = HazeInputScale.Auto
                    }
                } else {
                    Modifier.background(MaterialTheme.colorScheme.surface.copy(alpha = 0.92f))
                }
            )
            .border(width = Dimens.glassBorderWidth, color = Color.White.copy(alpha = 0.18f), shape = outerShape)
    ) {
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = Dimens.spacingSm, vertical = Dimens.spacingSm)
        ) {
            val fullWidth = maxWidth
            val tabWidth = fullWidth / screens.size
            val pillOffset by animateDpAsState(
                targetValue = tabWidth * selectedIndex,
                animationSpec = spring(
                    dampingRatio = Spring.DampingRatioMediumBouncy,
                    stiffness = Spring.StiffnessLow
                ),
                label = "pillOffset"
            )

            // 轨道
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(Dimens.dockHeight)
                    .clip(pillShape)
                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.55f))
            )

            // 底层（灰）
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(Dimens.dockHeight),
                verticalAlignment = Alignment.CenterVertically
            ) {
                screens.forEach { screen ->
                    TabCell(
                        screen = screen,
                        isSelected = false,
                        color = unselectedColor,
                        modifier = Modifier.weight(1f),
                        pillShape = pillShape,
                        onClick = {
                            view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                            onNavigate(screen.route)
                        }
                    )
                }
            }

            // 液态玻璃胶囊（Haze 默认）+ 前景（主色）
            // 使用 requiredWidth 避免被胶囊约束挤压；移除 SpaceEvenly 保持与底层对齐；胶囊加不透明白底以遮挡底层灰字
            Box(
                modifier = Modifier
                    .offset(x = pillOffset)
                    .width(tabWidth)
                    .height(Dimens.dockHeight)
                    .padding(horizontal = Dimens.spacingXxs, vertical = Dimens.spacingXxs)
                    .shadow(elevation = 6.dp, shape = pillShape, clip = false)
                    .clip(pillShape)
                    .then(
                        if (hazeState != null) {
                            Modifier.hazeEffect(state = hazeState, style = hazeStyle) {
                                inputScale = HazeInputScale.Auto
                            }
                        } else {
                            Modifier.background(MaterialTheme.colorScheme.surface.copy(alpha = 0.96f))
                        }
                    )
                    .background(Color.White.copy(alpha = 0.78f))
                    .border(width = Dimens.dockBorderWidth, color = Color.White.copy(alpha = 0.55f), shape = pillShape)
            ) {
                Row(
                    modifier = Modifier
                        .requiredWidth(fullWidth)
                        .height(Dimens.dockHeight)
                        .offset(x = -pillOffset),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    screens.forEach { screen ->
                        TabCell(
                            screen = screen,
                            isSelected = true,
                            color = selectedColor,
                            modifier = Modifier.weight(1f),
                            pillShape = pillShape,
                            onClick = null
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun TabCell(
    screen: Screen,
    isSelected: Boolean,
    color: Color,
    modifier: Modifier = Modifier,
    pillShape: RoundedCornerShape,
    onClick: (() -> Unit)? = null
) {
    val view = LocalView.current
    Column(
        modifier = modifier
            .height(Dimens.dockHeight)
            .clip(pillShape)
            .then(
                if (onClick != null) {
                    Modifier.selectable(
                        selected = isSelected,
                        role = Role.Tab,
                        onClick = {
                            view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                            onClick()
                        }
                    )
                } else Modifier
            ),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = if (isSelected) screen.selectedIcon else screen.unselectedIcon,
            contentDescription = stringResource(screen.titleResId),
            tint = color,
            modifier = Modifier.size(Dimens.iconSize)
        )
        Text(
            text = stringResource(screen.titleResId),
            style = MaterialTheme.typography.labelSmall,
            color = color,
            modifier = Modifier.padding(top = Dimens.spacingXxs),
            maxLines = 1
        )
    }
}
