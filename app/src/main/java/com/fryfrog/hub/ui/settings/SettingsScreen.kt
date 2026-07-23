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
import androidx.compose.ui.unit.offset
import com.fryfrog.hub.R
import com.fryfrog.hub.ui.theme.*

private val SECTION_NAMES = mapOf(
    "videos" to R.string.section_videos,
    "music" to R.string.section_music,
    "comics" to R.string.section_comics,
    "ebooks" to R.string.section_ebooks
)

private val SECTION_ICONS = mapOf(
    "videos" to Icons.Default.VideoLibrary,
    "music" to Icons.Default.LibraryMusic,
    "comics" to Icons.Default.MenuBook,
    "ebooks" to Icons.Default.AutoStories
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    isDarkTheme: Boolean,
    onThemeChange: (Boolean) -> Unit,
    isAdultContentHidden: Boolean,
    onAdultContentHiddenChange: (Boolean) -> Unit,
    isCarouselEnabled: Boolean,
    onCarouselEnabledChange: (Boolean) -> Unit,
    carouselSource: String,
    onCarouselSourceChange: (String) -> Unit,
    sectionOrder: List<String>,
    onSectionOrderChange: (List<String>) -> Unit,
    sectionVisible: Map<String, Boolean>,
    onSectionVisibleChange: (String, Boolean) -> Unit,
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
                        Icon(
                            imageVector = if (isDarkTheme) Icons.Default.LightMode else Icons.Default.DarkMode,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }
            }

            // Section: Home Layout
            item {
                Spacer(Modifier.height(Dimens.spacingSm))
                SectionHeader(
                    title = stringResource(R.string.home_layout),
                    icon = Icons.Default.Home
                )
            }

            // Carousel enabled
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
                                .size(40.dp)
                                .clip(CircleShape)
                                .background(Primary.copy(alpha = 0.1f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.ViewCarousel,
                                contentDescription = null,
                                tint = Primary,
                                modifier = Modifier.size(20.dp)
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

            // Carousel source
            if (isCarouselEnabled) {
                item {
                    ModernCard {
                        Column(
                            modifier = Modifier.padding(Dimens.spacingLg)
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Box(
                                    modifier = Modifier
                                        .size(40.dp)
                                        .clip(CircleShape)
                                        .background(Primary.copy(alpha = 0.1f)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.Source,
                                        contentDescription = null,
                                        tint = Primary,
                                        modifier = Modifier.size(20.dp)
                                    )
                                }
                                Spacer(Modifier.width(Dimens.spacingMd))
                                Text(
                                    stringResource(R.string.carousel_source),
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Medium
                                )
                            }
                            Spacer(Modifier.height(Dimens.spacingMd))
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm)
                            ) {
                                val sources = listOf("videos", "music", "comics", "ebooks")
                                val sourceLabels = sources.map { stringResource(SECTION_NAMES[it] ?: R.string.unknown) }
                                sources.forEachIndexed { index, source ->
                                    val isSelected = carouselSource == source
                                    Box(
                                        modifier = Modifier
                                            .weight(1f)
                                            .clip(RoundedCornerShape(Dimens.radiusMd))
                                            .background(
                                                if (isSelected) Primary
                                                else MaterialTheme.colorScheme.surfaceVariant
                                            )
                                            .clickable { onCarouselSourceChange(source) }
                                            .padding(vertical = Dimens.spacingSm),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Text(
                                            text = sourceLabels[index],
                                            style = MaterialTheme.typography.labelMedium,
                                            color = if (isSelected) MaterialTheme.colorScheme.onPrimary
                                            else MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Section order
            item {
                Spacer(Modifier.height(Dimens.spacingSm))
                Text(
                    stringResource(R.string.home_section_order_desc),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = Dimens.spacingLg)
                )
            }

            item {
                ModernCard {
                    Column {
                        sectionOrder.forEachIndexed { index, sectionId ->
                            val sectionName = stringResource(SECTION_NAMES[sectionId] ?: R.string.unknown)
                            val sectionIcon = SECTION_ICONS[sectionId] ?: Icons.Default.Folder
                            val isVisible = sectionVisible[sectionId] != false

                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = Dimens.spacingLg, vertical = Dimens.spacingSm),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    imageVector = sectionIcon,
                                    contentDescription = null,
                                    tint = if (isVisible) Primary else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = Dimens.alphaDisabled),
                                    modifier = Modifier.size(20.dp)
                                )
                                Spacer(Modifier.width(Dimens.spacingMd))
                                Text(
                                    sectionName,
                                    style = MaterialTheme.typography.bodyLarge,
                                    modifier = Modifier.weight(1f),
                                    color = if (isVisible) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurface.copy(alpha = Dimens.alphaDisabled)
                                )

                                // Move up
                                IconButton(
                                    onClick = {
                                        if (index > 0) {
                                            val newList = sectionOrder.toMutableList()
                                            newList.removeAt(index)
                                            newList.add(index - 1, sectionId)
                                            onSectionOrderChange(newList)
                                        }
                                    },
                                    enabled = index > 0,
                                    modifier = Modifier.size(32.dp)
                                ) {
                                    Icon(
                                        Icons.Default.KeyboardArrowUp,
                                        contentDescription = stringResource(R.string.move_up),
                                        modifier = Modifier.size(18.dp)
                                    )
                                }

                                // Move down
                                IconButton(
                                    onClick = {
                                        if (index < sectionOrder.size - 1) {
                                            val newList = sectionOrder.toMutableList()
                                            newList.removeAt(index)
                                            newList.add(index + 1, sectionId)
                                            onSectionOrderChange(newList)
                                        }
                                    },
                                    enabled = index < sectionOrder.size - 1,
                                    modifier = Modifier.size(32.dp)
                                ) {
                                    Icon(
                                        Icons.Default.KeyboardArrowDown,
                                        contentDescription = stringResource(R.string.move_down),
                                        modifier = Modifier.size(18.dp)
                                    )
                                }

                                // Visibility switch
                                UniformSwitch(
                                    checked = isVisible,
                                    onCheckedChange = { onSectionVisibleChange(sectionId, it) }
                                )
                            }

                            if (index < sectionOrder.size - 1) {
                                HorizontalDivider(
                                    modifier = Modifier.padding(horizontal = Dimens.spacingLg),
                                    color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)
                                )
                            }
                        }
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
                                .size(40.dp)
                                .clip(CircleShape)
                                .background(Primary.copy(alpha = 0.1f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.Lock,
                                contentDescription = null,
                                tint = Primary,
                                modifier = Modifier.size(20.dp)
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
                    textAlign = TextAlign.Center
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

@Composable
private fun UniformSwitch(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier
) {
    val thumbSize = 20.dp
    val trackWidth = 52.dp
    val trackHeight = 28.dp
    val thumbPadding = 4.dp

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
