@file:OptIn(ExperimentalMaterial3Api::class)

package com.fryfrog.hub.ui.settings

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
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
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.offset
import androidx.lifecycle.viewmodel.compose.viewModel
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.ScrapeProgress
import com.fryfrog.hub.data.model.UserDTO
import com.fryfrog.hub.ui.components.FryfrogDialog
import com.fryfrog.hub.ui.components.FryfrogTextField
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
    onRefreshAllMovieActors: () -> Unit = {},
    onRefreshAllLogos: () -> Unit = {},
    onRefreshAllResolutions: () -> Unit = {},
    onOpenUserManagement: () -> Unit = {},
    onOpenSystemSettings: () -> Unit = {},
    onOpenLogs: () -> Unit = {},
    isAdmin: Boolean = true,
    logoProgress: ScrapeProgress? = null,
    resolutionProgress: ScrapeProgress? = null,
    actorsProgress: ScrapeProgress? = null,
    seasonCoversProgress: ScrapeProgress? = null
) {
    var showLogoutDialog by remember { mutableStateOf(false) }
    var showChangePasswordDialog by remember { mutableStateOf(false) }
    // 待确认的修复操作（二次确认后再执行）
    var pendingRepairAction by remember { mutableStateOf<(() -> Unit)?>(null) }
    val context = androidx.compose.ui.platform.LocalContext.current
    val versionName = remember {
        try {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: "1.0.0"
        } catch (e: Exception) {
            "1.0.0"
        }
    }

    // 当前用户 / 修改密码
    val meViewModel: MeViewModel = viewModel()
    val meUiState by meViewModel.uiState.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }
    val meSnackbarText = meUiState.snackbarResId?.let { resId ->
        meUiState.snackbarArg?.let { stringResource(resId, it) } ?: stringResource(resId)
    }
    LaunchedEffect(meUiState.snackbarResId) {
        meSnackbarText?.let { snackbarHostState.showSnackbar(it) }
        meViewModel.clearSnackbar()
    }

    Box(modifier = Modifier.fillMaxSize()) {
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

            // 修复（新视频入库时自动完成，仅数据缺失/损坏时手动批量修复；仅管理员可见）
            if (isAdmin) {
            item {
                Spacer(Modifier.height(Dimens.spacingSm))
                SectionHeader(
                    title = stringResource(R.string.repair),
                    icon = Icons.Default.Build
                )
            }

            // 批量刷新季海报
            item {
                ModernCard {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { pendingRepairAction = { onRefreshAllSeasonCovers() } }
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
                    if (seasonCoversProgress?.module == "season-covers") {
                        seasonCoversProgress?.let { LogoBatchProgress(progress = it) }
                    }
                }
            }

            // 批量刷新电影演员
            item {
                ModernCard {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { pendingRepairAction = { onRefreshAllMovieActors() } }
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
                    if (actorsProgress?.module == "actors") {
                        actorsProgress?.let { LogoBatchProgress(progress = it) }
                    }
                }
            }

            // 批量补全 Logo（系列 + 电影合并）
            item {
                ModernCard {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { pendingRepairAction = { onRefreshAllLogos() } }
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
                                imageVector = Icons.Default.ImageSearch,
                                contentDescription = null,
                                tint = Primary,
                                modifier = Modifier.size(Dimens.avatarIconSize)
                            )
                        }
                        Spacer(Modifier.width(Dimens.spacingMd))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                stringResource(R.string.refresh_all_logos),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Medium
                            )
                            Text(
                                stringResource(R.string.refresh_all_logos_desc),
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
                    if (logoProgress?.module == "logo:all") {
                        logoProgress?.let { LogoBatchProgress(progress = it) }
                    }
                }
            }

            // 批量补分辨率
            item {
                ModernCard {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { pendingRepairAction = { onRefreshAllResolutions() } }
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
                                imageVector = Icons.Default.HighQuality,
                                contentDescription = null,
                                tint = Primary,
                                modifier = Modifier.size(Dimens.avatarIconSize)
                            )
                        }
                        Spacer(Modifier.width(Dimens.spacingMd))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                stringResource(R.string.refresh_all_resolutions),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Medium
                            )
                            Text(
                                stringResource(R.string.refresh_all_resolutions_desc),
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
                    if (resolutionProgress?.module == "resolution") {
                        resolutionProgress?.let { LogoBatchProgress(progress = it) }
                    }
                }
            }
            } // end admin repair section

            // 账户信息
            item {
                Spacer(Modifier.height(Dimens.spacingSm))
                SectionHeader(
                    title = stringResource(R.string.current_user),
                    icon = Icons.Default.Person
                )
            }

            item {
                ModernCard {
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
                        when {
                            meUiState.isLoadingUser -> {
                                CircularProgressIndicator(
                                    modifier = Modifier.size(Dimens.iconSize),
                                    strokeWidth = 2.dp
                                )
                            }
                            meUiState.currentUser != null -> {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = meUiState.currentUser!!.displayName,
                                        style = MaterialTheme.typography.titleMedium,
                                        fontWeight = FontWeight.Medium
                                    )
                                    Text(
                                        text = "@${meUiState.currentUser!!.username}",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                                Surface(
                                    color = if (meUiState.currentUser!!.isAdmin) Warning.copy(alpha = 0.15f)
                                    else Primary.copy(alpha = 0.1f),
                                    shape = RoundedCornerShape(Dimens.radiusXs)
                                ) {
                                    Text(
                                        text = stringResource(
                                            if (meUiState.currentUser!!.isAdmin) R.string.role_admin else R.string.role_user
                                        ),
                                        modifier = Modifier.padding(horizontal = Dimens.spacingSm, vertical = Dimens.spacingXxs),
                                        style = MaterialTheme.typography.labelSmall,
                                        color = if (meUiState.currentUser!!.isAdmin) Warning else Primary
                                    )
                                }
                            }
                            else -> {
                                Text(
                                    text = stringResource(R.string.not_logged_in),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }

            // 修改密码
            item {
                ModernCard {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { showChangePasswordDialog = true }
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
                                text = stringResource(R.string.change_password),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Medium
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
                    icon = Icons.Default.Lock
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

            // 管理员功能区（仅 ADMIN 角色显示）
            if (isAdmin) {
                item {
                    Spacer(Modifier.height(Dimens.spacingSm))
                    SectionHeader(
                        title = stringResource(R.string.system_settings),
                        icon = Icons.Default.AdminPanelSettings
                    )
                }

                // 用户管理
                item {
                    ModernCard {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { onOpenUserManagement() }
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
                                    imageVector = Icons.Default.Group,
                                    contentDescription = null,
                                    tint = Primary,
                                    modifier = Modifier.size(Dimens.avatarIconSize)
                                )
                            }
                            Spacer(Modifier.width(Dimens.spacingMd))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = stringResource(R.string.user_management),
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Medium
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

                // 系统设置
                item {
                    ModernCard {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { onOpenSystemSettings() }
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
                                    imageVector = Icons.Default.Settings,
                                    contentDescription = null,
                                    tint = Primary,
                                    modifier = Modifier.size(Dimens.avatarIconSize)
                                )
                            }
                            Spacer(Modifier.width(Dimens.spacingMd))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = stringResource(R.string.system_settings),
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Medium
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

                // 服务器日志
                item {
                    ModernCard {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { onOpenLogs() }
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
                                    imageVector = Icons.Default.Description,
                                    contentDescription = null,
                                    tint = Primary,
                                    modifier = Modifier.size(Dimens.avatarIconSize)
                                )
                            }
                            Spacer(Modifier.width(Dimens.spacingMd))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = stringResource(R.string.logs),
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Medium
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

        // 账户/管理员操作反馈
        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(Dimens.spacingLg)
                .padding(bottom = Dimens.bottomNavReserve)
        )
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
                        TextButton(
                            onClick = { showLogoutDialog = false },
                            modifier = Modifier.weight(1f),
                            colors = ButtonDefaults.textButtonColors(
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

    // 修复操作二次确认（批量刷新触发大量后端任务，误触成本高）
    pendingRepairAction?.let { action ->
        FryfrogDialog(
            onDismissRequest = { pendingRepairAction = null },
            icon = Icons.Default.Build,
            iconTint = Primary,
            iconBackground = Primary.copy(alpha = 0.1f),
            title = stringResource(R.string.repair_confirm_title),
            message = stringResource(R.string.repair_confirm_message),
            confirmText = stringResource(R.string.confirm),
            confirmColor = Primary,
            onConfirm = {
                pendingRepairAction = null
                action()
            },
            onDismiss = { pendingRepairAction = null }
        )
    }

    // 修改密码对话框
    if (showChangePasswordDialog) {
        ChangePasswordDialog(
            isSaving = meUiState.isChangingPassword,
            onDismiss = { showChangePasswordDialog = false },
            onSubmit = { oldPassword, newPassword ->
                meViewModel.changePassword(oldPassword, newPassword) {
                    showChangePasswordDialog = false
                }
            }
        )
    }
}

@Composable
private fun ChangePasswordDialog(
    isSaving: Boolean,
    onDismiss: () -> Unit,
    onSubmit: (oldPassword: String, newPassword: String) -> Unit
) {
    var oldPassword by remember { mutableStateOf("") }
    var newPassword by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }
    var oldVisible by remember { mutableStateOf(false) }
    var newVisible by remember { mutableStateOf(false) }
    var confirmVisible by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    val mismatchText = stringResource(R.string.password_mismatch)

    Dialog(onDismissRequest = onDismiss) {
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
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(Dimens.spacingXl),
                verticalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
            ) {
                Text(
                    text = stringResource(R.string.change_password),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface
                )

                FryfrogTextField(
                    value = oldPassword,
                    onValueChange = { oldPassword = it; errorMessage = null },
                    label = { Text(stringResource(R.string.old_password)) },
                    singleLine = true,
                    visualTransformation = if (oldVisible) VisualTransformation.None else PasswordVisualTransformation(),
                    trailingIcon = {
                        IconButton(onClick = { oldVisible = !oldVisible }) {
                            Icon(
                                imageVector = if (oldVisible) Icons.Default.Visibility else Icons.Default.VisibilityOff,
                                contentDescription = null
                            )
                        }
                    },
                    modifier = Modifier.fillMaxWidth()
                )

                FryfrogTextField(
                    value = newPassword,
                    onValueChange = { newPassword = it; errorMessage = null },
                    label = { Text(stringResource(R.string.new_password)) },
                    singleLine = true,
                    visualTransformation = if (newVisible) VisualTransformation.None else PasswordVisualTransformation(),
                    trailingIcon = {
                        IconButton(onClick = { newVisible = !newVisible }) {
                            Icon(
                                imageVector = if (newVisible) Icons.Default.Visibility else Icons.Default.VisibilityOff,
                                contentDescription = null
                            )
                        }
                    },
                    modifier = Modifier.fillMaxWidth()
                )

                FryfrogTextField(
                    value = confirmPassword,
                    onValueChange = { confirmPassword = it; errorMessage = null },
                    label = { Text(stringResource(R.string.confirm_new_password)) },
                    singleLine = true,
                    visualTransformation = if (confirmVisible) VisualTransformation.None else PasswordVisualTransformation(),
                    trailingIcon = {
                        IconButton(onClick = { confirmVisible = !confirmVisible }) {
                            Icon(
                                imageVector = if (confirmVisible) Icons.Default.Visibility else Icons.Default.VisibilityOff,
                                contentDescription = null
                            )
                        }
                    },
                    modifier = Modifier.fillMaxWidth()
                )

                errorMessage?.let {
                    Text(
                        text = it,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error
                    )
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
                ) {
                    TextButton(
                        onClick = onDismiss,
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.textButtonColors(
                            contentColor = MaterialTheme.colorScheme.onSurface
                        )
                    ) {
                        Text(stringResource(R.string.cancel))
                    }

                    Button(
                        onClick = {
                            if (newPassword != confirmPassword) {
                                errorMessage = mismatchText
                                return@Button
                            }
                            onSubmit(oldPassword, newPassword)
                        },
                        modifier = Modifier.weight(1f),
                        enabled = !isSaving && oldPassword.isNotBlank() && newPassword.isNotBlank(),
                        shape = RoundedCornerShape(Dimens.radiusMd)
                    ) {
                        if (isSaving) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(Dimens.iconSize),
                                strokeWidth = 2.dp,
                                color = MaterialTheme.colorScheme.onPrimary
                            )
                        } else {
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
        color = if (selected) Primary.copy(alpha = 0.15f) else Color.Transparent
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
private fun LogoBatchProgress(progress: ScrapeProgress) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = Dimens.spacingLg, end = Dimens.spacingLg, bottom = Dimens.spacingLg)
    ) {
        LinearProgressIndicator(
            progress = { (progress.percent / 100.0).toFloat().coerceIn(0f, 1f) },
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .clip(RoundedCornerShape(Dimens.radiusFull)),
            color = Primary,
            trackColor = MaterialTheme.colorScheme.surfaceVariant
        )
        Spacer(Modifier.height(Dimens.spacingXs))
        val failedText = if (progress.failed > 0) "（失败 ${progress.failed}）" else ""
        Text(
            text = "补全中 ${progress.completed}/${progress.total}$failedText",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        if (!progress.currentItem.isNullOrBlank()) {
            Text(
                text = "正在补全：${progress.currentItem}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis
            )
        }
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
