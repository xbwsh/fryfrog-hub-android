@file:OptIn(ExperimentalMaterial3Api::class)

package com.fryfrog.hub.ui.settings

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.fryfrog.hub.R
import com.fryfrog.hub.ui.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    isDarkTheme: Boolean,
    onThemeChange: (Boolean) -> Unit,
    onMediaLibrariesClick: () -> Unit,
    onLogout: () -> Unit = {}
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

    // 使用 Column 替代 Scaffold，确保 TopAppBar 和内容在同一个 recomposition 作用域
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        TopAppBar(
            title = { Text(stringResource(R.string.section_settings)) },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = MaterialTheme.colorScheme.background
            )
        )
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(Dimens.spacingLg),
            contentPadding = PaddingValues(
                horizontal = Dimens.spacingLg,
                vertical = Dimens.spacingLg
            )
        ) {
            // Section: Appearance
            item {
                SectionHeader(
                    title = stringResource(R.string.appearance),
                    icon = Icons.Default.Palette
                )
            }

            item {
                ModernCard {
                    // 动画效果
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
                    var isPressed by remember { mutableStateOf(false) }
                    val scale by animateFloatAsState(
                        targetValue = if (isPressed) 0.95f else 1f,
                        animationSpec = tween(durationMillis = 100),
                        label = "scale"
                    )

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .scale(scale)
                            .clickable {
                                isPressed = true
                                onThemeChange(!isDarkTheme)
                            }
                            .padding(Dimens.spacingLg),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(40.dp)
                                .clip(CircleShape)
                                .background(iconBackground),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = if (isDarkTheme) Icons.Default.DarkMode else Icons.Default.LightMode,
                                contentDescription = null,
                                tint = iconTint,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                        Spacer(Modifier.width(Dimens.spacingMd))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                stringResource(R.string.theme_mode),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Medium
                            )
                            Text(
                                if (isDarkTheme) stringResource(R.string.dark_theme) else stringResource(R.string.light_theme),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        // 右侧显示当前主题的图标
                        Icon(
                            imageVector = if (isDarkTheme) Icons.Default.LightMode else Icons.Default.DarkMode,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }
            }

            // Section: Content
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
                            .clickable { onMediaLibrariesClick() }
                            .padding(Dimens.spacingLg),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(40.dp)
                                .clip(CircleShape)
                                .background(Primary.copy(alpha = 0.1f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.VideoLibrary,
                                contentDescription = null,
                                tint = Primary,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                        Spacer(Modifier.width(Dimens.spacingMd))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                stringResource(R.string.media_libraries),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Medium
                            )
                            Text(
                                stringResource(R.string.manage_media_libraries),
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

            // Section: Account
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
                                .size(40.dp)
                                .clip(CircleShape)
                                .background(MaterialTheme.colorScheme.errorContainer),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.Logout,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.error,
                                modifier = Modifier.size(20.dp)
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

            // Version
            item {
                Spacer(Modifier.height(Dimens.spacingSm))
                Text(
                    "Fryfrog Hub v$versionName",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                    modifier = Modifier.fillMaxWidth(),
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center
                )
            }
        }
    }

    // Logout dialog
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
                    // Icon
                    Box(
                        modifier = Modifier
                            .size(56.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.errorContainer),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Logout,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.error,
                            modifier = Modifier.size(28.dp)
                        )
                    }

                    Spacer(Modifier.height(Dimens.spacingLg))

                    // Title
                    Text(
                        text = stringResource(R.string.logout),
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface
                    )

                    Spacer(Modifier.height(Dimens.spacingSm))

                    // Message
                    Text(
                        text = stringResource(R.string.logout_confirm),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center
                    )

                    Spacer(Modifier.height(Dimens.spacingXl))

                    // Buttons
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
                    ) {
                        // Cancel button
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

                        // Confirm button
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
            modifier = Modifier.size(20.dp)
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
