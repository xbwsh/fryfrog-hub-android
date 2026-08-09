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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.fryfrog.hub.ui.theme.Dimens
import com.fryfrog.hub.ui.theme.Primary

@Composable
fun FryfrogBottomBar(
    currentRoute: String?,
    onNavigate: (String) -> Unit
) {
    // 悬浮圆角样式：左右留边 + 底部留边 + 阴影 + 细边框
    val shape = RoundedCornerShape(Dimens.radiusXl)
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Dimens.spacingXl)
            .navigationBarsPadding()
            .padding(bottom = Dimens.spacingSm)
            .shadow(elevation = 8.dp, shape = shape, clip = false)
            .clip(shape)
            .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.95f))
            .border(
                width = 1.dp,
                color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f),
                shape = shape
            )
            .padding(horizontal = Dimens.spacingSm, vertical = Dimens.spacingXs)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            bottomNavScreens.forEach { screen ->
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
