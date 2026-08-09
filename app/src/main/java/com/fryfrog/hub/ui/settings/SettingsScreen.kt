@file:OptIn(ExperimentalMaterial3Api::class)

package com.fryfrog.hub.ui.settings

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.ui.window.Dialog
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.offset
import com.fryfrog.hub.R
import com.fryfrog.hub.ui.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MeScreen(
    isDarkTheme: Boolean,
    themeMode: String,
    onThemeModeChange: (String) -> Unit,
    isAdultContentHidden: Boolean,
    onAdultContentHiddenChange: (Boolean) -> Unit,
    isCarouselEnabled: Boolean,
    onCarouselEnabledChange: (Boolean) -> Unit,
    onLogout: () -> Unit = {},
    onRefreshAllSeasonCovers: () -> Unit = {},
    onRefreshAllMovieActors: () -> Unit = {}
) {
    var showLogoutDialog by remember { mutableStateOf(false) }
    val context = androidx.compose.ui.platform.LocalContext.current
    val versionName = remember {
        try {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: "1.0.0"
        } catch (e: Exception) {
            "1.0.0"
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        TopAppBar(
            title = { Text(stringResource(R.string.section_me)) },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = MaterialTheme.colorScheme.background
            )
        )
        LazyColumn(
            modifier = Modifier.fillMaxSize().navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(Dimens.spacingLg),
            contentPadding = PaddingValues(
                start = Dimens.spacingLg,
                top = Dimens.spacingLg,
                end = Dimens.spacingLg,
                bottom = Dimens.bottomNavReserve
            )
        ) {
            // 外观
            item {
                SectionHeader(
                    title = stringResource(R.string.appearance),
                    icon = Icons.Default.Palette
                )
            }

            item {
                ModernCard {
                    val iconBackground by animateColorAsState(
                        targetValue = if (isDarkTheme) Color(0xFF1A1A2E) else Color(0xFFFFF8E1),
                        animationSpec = tween(durationMillis = 300),
                        label = "iconBg"
                    )
                    val iconTint by animateColorAsState(
                        targetValue = if (isDarkTheme) Color(0xFFFFD700) else Color(0xFFFF9800),
                        animationSpec = tween(durationMillis = 300),
                        label = "iconTint"
                    )

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(Dimens.spacingLg),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(Dimens.avatarSize)
                                .clip(CircleShape)
                                .background(iconBackground),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = if (isDarkTheme) Icons.Default.DarkMode else Icons.Default.LightMode,
                                contentDescription = null,
                                tint = iconTint,
                                modifier = Modifier.size(Dimens.avatarIconSize)
                            )
                        }
                        Spacer(Modifier.width(Dimens.spacingMd))
                        Text(
                            stringResource(R.string.theme_mode),
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Medium
                        )
                    }

                    Spacer(Modifier.height(Dimens.spacingSm))

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(start = Dimens.spacingLg, end = Dimens.spacingLg, bottom = Dimens.spacingLg),
                        horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm)
                    ) {
                        ThemeModeOption(
                            mode = "system",
                            label = stringResource(R.string.theme_mode_system),
                            icon = Icons.Default.BrightnessAuto,
                            selected = themeMode == "system",
                            onClick = { onThemeModeChange("system") },
                            modifier = Modifier.weight(1f)
                        )
                        ThemeModeOption(
                            mode = "light",
                            label = stringResource(R.string.theme_mode_light),
                            icon = Icons.Default.LightMode,
                            selected = themeMode == "light",
                            onClick = { onThemeModeChange("light") },
                            modifier = Modifier.weight(1f)
                        )
                        ThemeModeOption(
                            mode = "dark",
                            label = stringResource(R.string.theme_mode_dark),
                            icon = Icons.Default.DarkMode,
                            selected = themeMode == "dark",
                            onClick = { onThemeModeChange("dark") },
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }

            // 首页布局
            item {
                Spacer(Modifier.height(Dimens.spacingSm))
                SectionHeader(
                    title = stringResource(R.string.home_layout),
                    icon = Icons.Default.Home
                )
            }

            item {
                ModernCard {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onCarouselEnabledChange(!isCarouselEnabled) }
                            .padding(Dimens.spacingLg),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(Dimens.avatarSize)
                                .clip(CircleShape)
                                .background(Primary.copy(alpha = 0.1f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.ViewCarousel,
                                contentDescription = null,
                                tint = Primary,
                                modifier = Modifier.size(Dimens.avatarIconSize)
                            )
                        }
                        Spacer(Modifier.width(Dimens.spacingMd))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                stringResource(R.string.carousel_enabled),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Medium
                            )
                        }
                        UniformSwitch(
                            checked = isCarouselEnabled,
                            onCheckedChange = onCarouselEnabledChange
                        )
                    }
                }
            }

            // 内容
            item {
                Spacer(Modifier.height(Dimens.spacingSm))
                SectionHeader(
                    title = stringResource(R.string.content),
                    icon = Icons.Default.Folder
                )
            }

            item {
                ModernCard {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onAdultContentHiddenChange(!isAdultContentHidden) }
                            .padding(Dimens.spacingLg),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(Dimens.avatarSize)
                                .clip(CircleShape)
                                .background(Primary.copy(alpha = 0.1f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.Lock,
                                contentDescription = null,
                                tint = Primary,
                                modifier = Modifier.size(Dimens.avatarIconSize)
                            )
                        }
                        Spacer(Modifier.width(Dimens.spacingMd))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                stringResource(R.string.privacy_mode),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Medium
                            )
                            Text(
                                stringResource(R.string.privacy_mode_desc),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        UniformSwitch(
                            checked = isAdultContentHidden,
                            onCheckedChange = onAdultContentHiddenChange
                        )
                    }
                }
            }

            // 批量刷新季海报
            item {
                ModernCard {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onRefreshAllSeasonCovers() }
                            .padding(Dimens.spacingLg),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(Dimens.avatarSize)
                                .clip(CircleShape)
                                .background(Primary.copy(alpha = 0.1f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.Refresh,
                                contentDescription = null,
                                tint = Primary,
                                modifier = Modifier.size(Dimens.avatarIconSize)
                            )
                        }
                        Spacer(Modifier.width(Dimens.spacingMd))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                stringResource(R.string.refresh_all_season_covers),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Medium
                            )
                            Text(
                                stringResource(R.string.refresh_all_season_covers_desc),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Icon(
                            Icons.Default.ChevronRight,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            // 批量刷新电影演员
            item {
                ModernCard {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onRefreshAllMovieActors() }
                            .padding(Dimens.spacingLg),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(Dimens.avatarSize)
                                .clip(CircleShape)
                                .background(Primary.copy(alpha = 0.1f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.Person,
                                contentDescription = null,
                                tint = Primary,
                                modifier = Modifier.size(Dimens.avatarIconSize)
                            )
                        }
                        Spacer(Modifier.width(Dimens.spacingMd))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                stringResource(R.string.refresh_all_movie_actors),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Medium
                            )
                            Text(
                                stringResource(R.string.refresh_all_movie_actors_desc),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Icon(
                            Icons.Default.ChevronRight,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            // 账户
            item {
                Spacer(Modifier.height(Dimens.spacingSm))
                SectionHeader(
                    title = stringResource(R.string.account),
                    icon = Icons.Default.Person
                )
            }

            item {
                ModernCard {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { showLogoutDialog = true }
                            .padding(Dimens.spacingLg),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(Dimens.avatarSize)
                                .clip(CircleShape)
                                .background(MaterialTheme.colorScheme.errorContainer),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.Logout,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.error,
                                modifier = Modifier.size(Dimens.avatarIconSize)
                            )
                        }
                        Spacer(Modifier.width(Dimens.spacingMd))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = stringResource(R.string.logout),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Medium,
                                color = MaterialTheme.colorScheme.error
                            )
                        }
                        Icon(
                            Icons.Default.ChevronRight,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            // 版本
            item {
                Spacer(Modifier.height(Dimens.spacingSm))
                Text(
                    "Fryfrog Hub v$versionName",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                    modifier = Modifier.fillMaxWidth(),
                    textAlign = TextAlign.Center
                )
            }
        }
    }

    // 退出登录对话框
    if (showLogoutDialog) {
        Dialog(onDismissRequest = { showLogoutDialog = false }) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(Dimens.spacingLg),
                shape = RoundedCornerShape(Dimens.radiusXl),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            ) {
                Column(
                    modifier = Modifier.padding(Dimens.spacingXl),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Box(
                        modifier = Modifier
                            .size(Dimens.dialogAvatarSize)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.errorContainer),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Logout,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.error,
                            modifier = Modifier.size(Dimens.dialogIconSize)
                        )
                    }

                    Spacer(Modifier.height(Dimens.spacingLg))

                    Text(
                        text = stringResource(R.string.logout),
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface
                    )

                    Spacer(Modifier.height(Dimens.spacingSm))

                    Text(
                        text = stringResource(R.string.logout_confirm),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center
                    )

                    Spacer(Modifier.height(Dimens.spacingXl))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
                    ) {
                        OutlinedButton(
                            onClick = { showLogoutDialog = false },
                            modifier = Modifier.weight(1f),
                            shape = RoundedCornerShape(Dimens.radiusMd),
                            colors = ButtonDefaults.outlinedButtonColors(
                                contentColor = MaterialTheme.colorScheme.onSurface
                            )
                        ) {
                            Text(stringResource(R.string.cancel))
                        }

                        Button(
                            onClick = {
                                showLogoutDialog = false
                                onLogout()
                            },
                            modifier = Modifier.weight(1f),
                            shape = RoundedCornerShape(Dimens.radiusMd),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = MaterialTheme.colorScheme.error
                            )
                        ) {
                            Text(stringResource(R.string.confirm))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SectionHeader(
    title: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = Primary,
            modifier = Modifier.size(Dimens.iconSize)
        )
        Spacer(Modifier.width(Dimens.spacingSm))
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface
        )
    }
}

@Composable
private fun ThemeModeOption(
    mode: String,
    label: String,
    icon: ImageVector,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        onClick = onClick,
        modifier = modifier,
        shape = RoundedCornerShape(Dimens.radiusMd),
        color = if (selected) Primary.copy(alpha = 0.15f) else Color.Transparent,
        border = BorderStroke(
            1.dp,
            if (selected) Primary else MaterialTheme.colorScheme.outlineVariant
        )
    ) {
        Column(
            modifier = Modifier.padding(vertical = Dimens.spacingSm),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(Dimens.iconSize),
                tint = if (selected) Primary else MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(Modifier.height(Dimens.spacingXs))
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = if (selected) Primary else MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun ModernCard(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        shape = RoundedCornerShape(Dimens.radiusLg)
    ) {
        Column(content = content)
    }
}

@Composable
internal fun UniformSwitch(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier
) {
    val thumbSize = Dimens.switchThumbSize
    val trackWidth = Dimens.switchWidth
    val trackHeight = Dimens.switchHeight
    val thumbPadding = Dimens.spacingXs

    val thumbPosition by animateFloatAsState(
        targetValue = if (checked) 1f else 0f,
        animationSpec = tween(durationMillis = 200),
        label = "thumbPosition"
    )

    val trackColor by animateColorAsState(
        targetValue = if (checked) Primary else MaterialTheme.colorScheme.surfaceVariant,
        animationSpec = tween(durationMillis = 200),
        label = "trackColor"
    )

    val thumbColor by animateColorAsState(
        targetValue = if (checked) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface,
        animationSpec = tween(durationMillis = 200),
        label = "thumbColor"
    )

    Box(
        modifier = modifier
            .width(trackWidth)
            .height(trackHeight)
            .clip(RoundedCornerShape(trackHeight / 2))
            .background(trackColor)
            .clickable { onCheckedChange(!checked) },
        contentAlignment = Alignment.CenterStart
    ) {
        Box(
            modifier = Modifier
                .padding(start = thumbPadding)
                .offset(x = (trackWidth - thumbSize - thumbPadding * 2) * thumbPosition)
                .size(thumbSize)
                .clip(CircleShape)
                .background(thumbColor)
        )
    }
}
