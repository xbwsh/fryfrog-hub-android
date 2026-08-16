@file:OptIn(ExperimentalMaterial3Api::class)

package com.fryfrog.hub.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.MediaLibrary
import com.fryfrog.hub.data.model.PipelineProgress
import com.fryfrog.hub.ui.components.FryfrogDialog
import com.fryfrog.hub.ui.components.FryfrogTextField
import com.fryfrog.hub.ui.theme.*

private val mediaTypes = listOf("VIDEO", "MUSIC", "COMIC", "EBOOK")
private val videoSubTypes = listOf("MOVIE", "TV", "MIXED")

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MediaLibrariesScreen(
    onBackClick: (() -> Unit)? = null,
    viewModel: MediaLibrariesViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    var showDeleteDialog by remember { mutableStateOf<MediaLibrary?>(null) }
    var showCreateDialog by remember { mutableStateOf(false) }
    var showEditDialog by remember { mutableStateOf<MediaLibrary?>(null) }
    var showRescrapeDialog by remember { mutableStateOf<MediaLibrary?>(null) }

    LaunchedEffect(uiState.error) {
        uiState.error?.let {
            kotlinx.coroutines.delay(3000)
            viewModel.clearError()
        }
    }

    LaunchedEffect(uiState.noticeResId) {
        uiState.noticeResId?.let {
            kotlinx.coroutines.delay(3000)
            viewModel.clearNotice()
        }
    }

    Scaffold(
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.media_libraries)) },
                navigationIcon = {
                    if (onBackClick != null) {
                        IconButton(onClick = onBackClick) {
                            Icon(Icons.Default.ArrowBack, contentDescription = stringResource(R.string.back))
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            Column(modifier = Modifier.fillMaxSize()) {
                // 标题下的功能行：新增媒体库 + 排序
                LibraryActionRow(
                    isSorting = uiState.isSorting,
                    onAddClick = { showCreateDialog = true },
                    onSortClick = {
                        if (uiState.isSorting) {
                            viewModel.stopSorting()
                        } else {
                            viewModel.startSorting()
                        }
                    }
                )

                if (uiState.isLoading) {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator()
                    }
                } else if (uiState.libraries.isEmpty()) {
                    // 空状态
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(Dimens.spacingLg),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        Icon(
                            Icons.Default.FolderOpen,
                            contentDescription = null,
                            modifier = Modifier.size(Dimens.emptyStateIconSize),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
                        )
                        Spacer(Modifier.height(Dimens.spacingMd))
                        Text(
                            stringResource(R.string.no_libraries),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize().navigationBarsPadding(),
                        contentPadding = PaddingValues(
                            start = Dimens.spacingLg,
                            top = Dimens.spacingSm,
                            end = Dimens.spacingLg,
                            bottom = Dimens.bottomNavReserve
                        ),
                        verticalArrangement = Arrangement.spacedBy(Dimens.spacingSm)
                    ) {
                        val displayLibraries = if (uiState.isSorting) uiState.sortingLibraries else uiState.libraries
                        itemsIndexed(displayLibraries, key = { _, library -> library.id }) { index, library ->
                            MediaLibraryItem(
                                library = library,
                                isScanning = library.id in uiState.scanningLibraryIds,
                                pipelineProgress = uiState.pipelineProgress[library.id],
                                isSorting = uiState.isSorting,
                                canMoveUp = index > 0,
                                canMoveDown = index < displayLibraries.lastIndex,
                                onMoveUp = { viewModel.moveLibrary(index, -1) },
                                onMoveDown = { viewModel.moveLibrary(index, 1) },
                                onScan = { viewModel.scanLibrary(library) },
                                onRescrape = { showRescrapeDialog = library },
                                onDelete = { showDeleteDialog = library },
                                onEdit = { showEditDialog = library }
                            )
                        }
                    }
                }
            }

            // 错误消息
            uiState.error?.let { error ->
                Snackbar(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(Dimens.spacingLg),
                    containerColor = MaterialTheme.colorScheme.errorContainer,
                    contentColor = MaterialTheme.colorScheme.onErrorContainer
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Error, contentDescription = null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.error)
                        Spacer(Modifier.width(Dimens.spacingSm))
                        Text(error, style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }

            // 操作成功提示
            uiState.noticeResId?.let { noticeResId ->
                val noticeText = uiState.noticeArg?.let { stringResource(noticeResId, it) }
                    ?: stringResource(noticeResId)
                Snackbar(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(Dimens.spacingLg)
                        .padding(bottom = if (uiState.error != null) Dimens.spacingXxl else 0.dp),
                    containerColor = MaterialTheme.colorScheme.tertiaryContainer,
                    contentColor = MaterialTheme.colorScheme.onTertiaryContainer
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.CheckCircle, contentDescription = null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.tertiary)
                        Spacer(Modifier.width(Dimens.spacingSm))
                        Text(noticeText, style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }
        }
    }

    // 删除对话框
    showDeleteDialog?.let { library ->
        FryfrogDialog(
            onDismissRequest = { showDeleteDialog = null },
            icon = Icons.Default.Delete,
            title = stringResource(R.string.delete_library),
            message = stringResource(R.string.delete_library_confirm, library.name),
            confirmText = stringResource(R.string.delete),
            confirmColor = MaterialTheme.colorScheme.error,
            onConfirm = {
                viewModel.deleteLibrary(library)
                showDeleteDialog = null
            },
            onDismiss = { showDeleteDialog = null }
        )
    }

    // 创建对话框
    if (showCreateDialog) {
        CreateLibraryDialog(
            viewModel = viewModel,
            onDismiss = { showCreateDialog = false },
            onCreate = { name, path, type, subType, desc, enableScraping, isAdult ->
                viewModel.createLibrary(name, path, type, subType, desc, enableScraping, isAdult)
                showCreateDialog = false
            }
        )
    }

    // 编辑对话框
    showEditDialog?.let { library ->
        EditLibraryDialog(
            library = library,
            viewModel = viewModel,
            onDismiss = { showEditDialog = null },
            onSave = { name, path, type, subType, desc, enableScraping, isAdult, enabled ->
                viewModel.updateLibrary(library, name, path, type, subType, desc, enableScraping, isAdult, enabled)
                showEditDialog = null
            }
        )
    }

    // 按库重新刮削确认对话框
    showRescrapeDialog?.let { library ->
        FryfrogDialog(
            onDismissRequest = { showRescrapeDialog = null },
            icon = Icons.Default.AutoAwesome,
            title = stringResource(R.string.rescrape_library),
            message = stringResource(R.string.rescrape_library_confirm, library.name),
            confirmText = stringResource(R.string.confirm),
            confirmColor = Primary,
            onConfirm = {
                viewModel.rescrapeLibrary(library)
                showRescrapeDialog = null
            },
            onDismiss = { showRescrapeDialog = null }
        )
    }
}

@Composable
private fun LibraryActionRow(
    isSorting: Boolean,
    onAddClick: () -> Unit,
    onSortClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Dimens.spacingLg, vertical = Dimens.spacingSm),
        horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm)
    ) {
        FilledTonalButton(
            onClick = onAddClick,
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(vertical = Dimens.spacingSm),
            shape = RoundedCornerShape(Dimens.radiusSm)
        ) {
            Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(Dimens.spacingXs))
            Text(stringResource(R.string.add_library), style = MaterialTheme.typography.labelMedium)
        }

        FilledTonalButton(
            onClick = onSortClick,
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(vertical = Dimens.spacingSm),
            shape = RoundedCornerShape(Dimens.radiusSm)
        ) {
            Icon(
                imageVector = if (isSorting) Icons.Default.Check else Icons.Default.Sort,
                contentDescription = null,
                modifier = Modifier.size(18.dp)
            )
            Spacer(Modifier.width(Dimens.spacingXs))
            Text(
                text = stringResource(if (isSorting) R.string.done else R.string.sort),
                style = MaterialTheme.typography.labelMedium
            )
        }
    }
}

@Composable
private fun MediaLibraryItem(
    library: MediaLibrary,
    isScanning: Boolean,
    pipelineProgress: PipelineProgress? = null,
    isSorting: Boolean = false,
    canMoveUp: Boolean = true,
    canMoveDown: Boolean = true,
    onMoveUp: () -> Unit = {},
    onMoveDown: () -> Unit = {},
    onScan: () -> Unit,
    onRescrape: () -> Unit = {},
    onDelete: () -> Unit,
    onEdit: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(Dimens.radiusMd),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(
            modifier = Modifier.padding(Dimens.spacingMd)
        ) {
            // 第一行：图标 + 名称/路径
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // 类型图标
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(RoundedCornerShape(Dimens.radiusMd))
                        .background(
                            when (library.type) {
                                "VIDEO" -> Primary.copy(alpha = 0.1f)
                                "MUSIC" -> Success.copy(alpha = 0.1f)
                                "COMIC" -> Warning.copy(alpha = 0.1f)
                                "EBOOK" -> Info.copy(alpha = 0.1f)
                                else -> MaterialTheme.colorScheme.surfaceVariant
                            }
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = when (library.type) {
                            "VIDEO" -> Icons.Default.VideoLibrary
                            "MUSIC" -> Icons.Default.LibraryMusic
                            "COMIC" -> Icons.Default.Book
                            "EBOOK" -> Icons.Default.ChromeReaderMode
                            else -> Icons.Default.Folder
                        },
                        contentDescription = null,
                        tint = when (library.type) {
                            "VIDEO" -> Primary
                            "MUSIC" -> Success
                            "COMIC" -> Warning
                            "EBOOK" -> Info
                            else -> MaterialTheme.colorScheme.onSurfaceVariant
                        },
                        modifier = Modifier.size(22.dp)
                    )
                }

                Spacer(Modifier.width(Dimens.spacingMd))

                // 名称、路径
                Column(modifier = Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = library.name,
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.SemiBold,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        if (library.isAdult == true) {
                            Spacer(Modifier.width(Dimens.spacingXs))
                            Surface(
                                color = Color(0xFFFF4D4F),
                                shape = RoundedCornerShape(Dimens.radiusXs)
                            ) {
                                Text(
                                    text = stringResource(R.string.adult_library_badge),
                                    modifier = Modifier.padding(horizontal = 4.dp, vertical = 1.dp),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = Color.White,
                                    fontWeight = FontWeight.Medium
                                )
                            }
                        }
                        if (!library.enabled) {
                            Spacer(Modifier.width(Dimens.spacingXs))
                            Surface(
                                color = MaterialTheme.colorScheme.surfaceVariant,
                                shape = RoundedCornerShape(Dimens.radiusXs)
                            ) {
                                Text(
                                    text = stringResource(R.string.disabled),
                                    modifier = Modifier.padding(horizontal = 4.dp, vertical = 1.dp),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                    Spacer(Modifier.height(2.dp))
                    Text(
                        text = library.path,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }

                // 排序模式下显示上/下移按钮，否则显示编辑按钮
                if (isSorting) {
                    IconButton(onClick = onMoveUp, enabled = canMoveUp) {
                        Icon(
                            imageVector = Icons.Default.ArrowUpward,
                            contentDescription = stringResource(R.string.move_up),
                            tint = if (canMoveUp) MaterialTheme.colorScheme.onSurfaceVariant
                            else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f)
                        )
                    }
                    IconButton(onClick = onMoveDown, enabled = canMoveDown) {
                        Icon(
                            imageVector = Icons.Default.ArrowDownward,
                            contentDescription = stringResource(R.string.move_down),
                            tint = if (canMoveDown) MaterialTheme.colorScheme.onSurfaceVariant
                            else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f)
                        )
                    }
                } else {
                    // 扫描 / 编辑 / 删除 图标（一行）
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        IconButton(onClick = onScan, enabled = !isScanning) {
                            if (isScanning) {
                                CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp, color = Primary)
                            } else {
                                Icon(
                                    imageVector = Icons.Default.Refresh,
                                    contentDescription = stringResource(R.string.scan),
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                        // 按库重新刮削（仅视频库，替代已删除的 supplement 接口）
                        if (library.type == "VIDEO") {
                            IconButton(onClick = onRescrape, enabled = !isScanning) {
                                Icon(
                                    imageVector = Icons.Default.AutoAwesome,
                                    contentDescription = stringResource(R.string.rescrape_library),
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                        IconButton(onClick = onEdit) {
                            Icon(
                                imageVector = Icons.Default.Edit,
                                contentDescription = stringResource(R.string.edit),
                                tint = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        IconButton(onClick = onDelete, enabled = !isScanning) {
                            Icon(
                                imageVector = Icons.Default.Delete,
                                contentDescription = stringResource(R.string.delete),
                                tint = MaterialTheme.colorScheme.error
                            )
                        }
                    }
                }
            }

            Spacer(Modifier.height(Dimens.spacingMd))

            // 扫描流水线进度
            if (isScanning && pipelineProgress != null) {
                LinearProgressIndicator(
                    progress = { (pipelineProgress.percent / 100.0).toFloat().coerceIn(0f, 1f) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(Dimens.radiusXs)),
                    drawStopIndicator = {}
                )
                Spacer(Modifier.height(Dimens.spacingXs))
                val stageLabel = when (pipelineProgress.stage) {
                    "scan" -> stringResource(R.string.stage_scan)
                    "scrape" -> stringResource(R.string.stage_scrape)
                    "actors" -> stringResource(R.string.stage_actors)
                    "assets" -> stringResource(R.string.stage_assets)
                    "done" -> stringResource(R.string.stage_done)
                    else -> null
                }
                if (stageLabel != null) {
                    Text(
                        text = stageLabel,
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Spacer(Modifier.height(Dimens.spacingXxs))
                }
                Text(
                    text = pipelineProgress.currentItem ?: "",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CreateLibraryDialog(
    viewModel: MediaLibrariesViewModel,
    onDismiss: () -> Unit,
    onCreate: (name: String, path: String, type: String, subType: String?, description: String?, enableScraping: Boolean, isAdult: Boolean) -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()
    var name by remember { mutableStateOf("") }
    var selectedPath by remember { mutableStateOf("") }
    var type by remember { mutableStateOf("VIDEO") }
    var subType by remember { mutableStateOf("MOVIE") }
    var description by remember { mutableStateOf("") }
    var enableScraping by remember { mutableStateOf(true) }
    var isAdult by remember { mutableStateOf(false) }
    var typeExpanded by remember { mutableStateOf(false) }
    var subTypeExpanded by remember { mutableStateOf(false) }
    var showDirectoryPicker by remember { mutableStateOf(false) }

    FryfrogDialog(
        onDismissRequest = onDismiss,
        title = stringResource(R.string.create_library),
        content = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
            ) {
                FryfrogTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text(stringResource(R.string.library_name)) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )

                FryfrogTextField(
                    value = selectedPath,
                    onValueChange = {},
                    label = { Text(stringResource(R.string.library_path)) },
                    readOnly = true,
                    trailingIcon = {
                        IconButton(onClick = {
                            showDirectoryPicker = true
                            viewModel.browseDirectory()
                        }) {
                            Icon(Icons.Default.Folder, contentDescription = stringResource(R.string.browse))
                        }
                    },
                    modifier = Modifier.fillMaxWidth()
                )

                ExposedDropdownMenuBox(
                    expanded = typeExpanded,
                    onExpandedChange = { typeExpanded = it }
                ) {
                    val typeLabel = when (type) {
                        "VIDEO" -> stringResource(R.string.type_video)
                        "MUSIC" -> stringResource(R.string.type_music)
                        "COMIC" -> stringResource(R.string.type_comic)
                        "EBOOK" -> stringResource(R.string.type_ebook)
                        else -> type
                    }
                    FryfrogTextField(
                        value = typeLabel,
                        onValueChange = {},
                        label = { Text(stringResource(R.string.library_type)) },
                        readOnly = true,
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = typeExpanded) },
                        modifier = Modifier.menuAnchor().fillMaxWidth()
                    )
                    ExposedDropdownMenu(expanded = typeExpanded, onDismissRequest = { typeExpanded = false }) {
                        val videoLabel = stringResource(R.string.type_video)
                        val musicLabel = stringResource(R.string.type_music)
                        val comicLabel = stringResource(R.string.type_comic)
                        val ebookLabel = stringResource(R.string.type_ebook)
                        mediaTypes.forEach { t ->
                            val label = when (t) {
                                "VIDEO" -> videoLabel
                                "MUSIC" -> musicLabel
                                "COMIC" -> comicLabel
                                "EBOOK" -> ebookLabel
                                else -> t
                            }
                            DropdownMenuItem(
                                text = { Text(label) },
                                onClick = { type = t; typeExpanded = false }
                            )
                        }
                    }
                }

                if (type == "VIDEO") {
                    ExposedDropdownMenuBox(
                        expanded = subTypeExpanded,
                        onExpandedChange = { subTypeExpanded = it }
                    ) {
                        val subTypeLabel = when (subType) {
                            "MOVIE" -> stringResource(R.string.subtype_movie)
                            "TV" -> stringResource(R.string.subtype_tv)
                            "MIXED" -> stringResource(R.string.subtype_mixed)
                            else -> subType
                        }
                        FryfrogTextField(
                            value = subTypeLabel,
                            onValueChange = {},
                            label = { Text(stringResource(R.string.video_sub_type)) },
                            readOnly = true,
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = subTypeExpanded) },
                            modifier = Modifier.menuAnchor().fillMaxWidth()
                        )
                        ExposedDropdownMenu(expanded = subTypeExpanded, onDismissRequest = { subTypeExpanded = false }) {
                            val movieLabel = stringResource(R.string.subtype_movie)
                            val tvLabel = stringResource(R.string.subtype_tv)
                            val mixedLabel = stringResource(R.string.subtype_mixed)
                            videoSubTypes.forEach { st ->
                                val label = when (st) {
                                    "MOVIE" -> movieLabel
                                    "TV" -> tvLabel
                                    "MIXED" -> mixedLabel
                                    else -> st
                                }
                                DropdownMenuItem(
                                    text = { Text(label) },
                                    onClick = { subType = st; subTypeExpanded = false }
                                )
                            }
                        }
                    }
                }

                FryfrogTextField(
                    value = description,
                    onValueChange = { description = it },
                    label = { Text(stringResource(R.string.description)) },
                    maxLines = 2,
                    modifier = Modifier.fillMaxWidth()
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Default.AutoAwesome,
                        contentDescription = null,
                        modifier = Modifier.size(20.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(Modifier.width(Dimens.spacingSm))
                    Text(
                        text = stringResource(R.string.enable_scraping),
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.weight(1f)
                    )
                    UniformSwitch(
                        checked = enableScraping,
                        onCheckedChange = { enableScraping = it }
                    )
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Default.Warning,
                        contentDescription = null,
                        modifier = Modifier.size(20.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(Modifier.width(Dimens.spacingSm))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = stringResource(R.string.adult_library),
                            style = MaterialTheme.typography.bodyMedium
                        )
                        Text(
                            text = stringResource(R.string.adult_library_desc),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    UniformSwitch(
                        checked = isAdult,
                        onCheckedChange = { isAdult = it }
                    )
                }
            }
        },
        confirmText = stringResource(R.string.create),
        confirmEnabled = name.isNotBlank() && selectedPath.isNotBlank(),
        onConfirm = { onCreate(name, selectedPath, type, subType.ifEmpty { null }, description.ifEmpty { null }, enableScraping, isAdult) },
        onDismiss = onDismiss
    )

    if (showDirectoryPicker) {
        DirectoryPickerDialog(
            uiState = uiState,
            viewModel = viewModel,
            onDismiss = { showDirectoryPicker = false },
            onSelect = { path ->
                selectedPath = path
                showDirectoryPicker = false
            }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EditLibraryDialog(
    library: MediaLibrary,
    viewModel: MediaLibrariesViewModel,
    onDismiss: () -> Unit,
    onSave: (name: String, path: String, type: String, subType: String?, description: String?, enableScraping: Boolean, isAdult: Boolean, enabled: Boolean) -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()
    var name by remember(library.id) { mutableStateOf(library.name) }
    var selectedPath by remember(library.id) { mutableStateOf(library.path) }
    var type by remember(library.id) { mutableStateOf(library.type) }
    var subType by remember(library.id) { mutableStateOf(library.subType ?: "MOVIE") }
    var description by remember(library.id) { mutableStateOf(library.description ?: "") }
    var enableScraping by remember(library.id) { mutableStateOf(library.enableScraping != false) }
    var isAdult by remember(library.id) { mutableStateOf(library.isAdult == true) }
    var enabled by remember(library.id) { mutableStateOf(library.enabled) }
    var typeExpanded by remember { mutableStateOf(false) }
    var subTypeExpanded by remember { mutableStateOf(false) }
    var showDirectoryPicker by remember { mutableStateOf(false) }

    FryfrogDialog(
        onDismissRequest = onDismiss,
        title = stringResource(R.string.edit_library),
        content = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Default.PowerSettingsNew,
                        contentDescription = null,
                        modifier = Modifier.size(20.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(Modifier.width(Dimens.spacingSm))
                    Text(
                        text = stringResource(R.string.enable_library),
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.weight(1f)
                    )
                    UniformSwitch(
                        checked = enabled,
                        onCheckedChange = { enabled = it }
                    )
                }

                FryfrogTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text(stringResource(R.string.library_name)) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )

                FryfrogTextField(
                    value = selectedPath,
                    onValueChange = {},
                    label = { Text(stringResource(R.string.library_path)) },
                    readOnly = true,
                    trailingIcon = {
                        IconButton(onClick = {
                            showDirectoryPicker = true
                            viewModel.browseDirectory()
                        }) {
                            Icon(Icons.Default.Folder, contentDescription = stringResource(R.string.browse))
                        }
                    },
                    modifier = Modifier.fillMaxWidth()
                )

                ExposedDropdownMenuBox(
                    expanded = typeExpanded,
                    onExpandedChange = { typeExpanded = it }
                ) {
                    val typeLabel = when (type) {
                        "VIDEO" -> stringResource(R.string.type_video)
                        "MUSIC" -> stringResource(R.string.type_music)
                        "COMIC" -> stringResource(R.string.type_comic)
                        "EBOOK" -> stringResource(R.string.type_ebook)
                        else -> type
                    }
                    FryfrogTextField(
                        value = typeLabel,
                        onValueChange = {},
                        label = { Text(stringResource(R.string.library_type)) },
                        readOnly = true,
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = typeExpanded) },
                        modifier = Modifier.menuAnchor().fillMaxWidth()
                    )
                    ExposedDropdownMenu(expanded = typeExpanded, onDismissRequest = { typeExpanded = false }) {
                        val videoLabel = stringResource(R.string.type_video)
                        val musicLabel = stringResource(R.string.type_music)
                        val comicLabel = stringResource(R.string.type_comic)
                        val ebookLabel = stringResource(R.string.type_ebook)
                        mediaTypes.forEach { t ->
                            val label = when (t) {
                                "VIDEO" -> videoLabel
                                "MUSIC" -> musicLabel
                                "COMIC" -> comicLabel
                                "EBOOK" -> ebookLabel
                                else -> t
                            }
                            DropdownMenuItem(
                                text = { Text(label) },
                                onClick = { type = t; typeExpanded = false }
                            )
                        }
                    }
                }

                if (type == "VIDEO") {
                    ExposedDropdownMenuBox(
                        expanded = subTypeExpanded,
                        onExpandedChange = { subTypeExpanded = it }
                    ) {
                        val subTypeLabel = when (subType) {
                            "MOVIE" -> stringResource(R.string.subtype_movie)
                            "TV" -> stringResource(R.string.subtype_tv)
                            "MIXED" -> stringResource(R.string.subtype_mixed)
                            else -> subType
                        }
                        FryfrogTextField(
                            value = subTypeLabel,
                            onValueChange = {},
                            label = { Text(stringResource(R.string.video_sub_type)) },
                            readOnly = true,
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = subTypeExpanded) },
                            modifier = Modifier.menuAnchor().fillMaxWidth()
                        )
                        ExposedDropdownMenu(expanded = subTypeExpanded, onDismissRequest = { subTypeExpanded = false }) {
                            val movieLabel = stringResource(R.string.subtype_movie)
                            val tvLabel = stringResource(R.string.subtype_tv)
                            val mixedLabel = stringResource(R.string.subtype_mixed)
                            videoSubTypes.forEach { st ->
                                val label = when (st) {
                                    "MOVIE" -> movieLabel
                                    "TV" -> tvLabel
                                    "MIXED" -> mixedLabel
                                    else -> st
                                }
                                DropdownMenuItem(
                                    text = { Text(label) },
                                    onClick = { subType = st; subTypeExpanded = false }
                                )
                            }
                        }
                    }
                }

                FryfrogTextField(
                    value = description,
                    onValueChange = { description = it },
                    label = { Text(stringResource(R.string.description)) },
                    maxLines = 2,
                    modifier = Modifier.fillMaxWidth()
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Default.AutoAwesome,
                        contentDescription = null,
                        modifier = Modifier.size(20.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(Modifier.width(Dimens.spacingSm))
                    Text(
                        text = stringResource(R.string.enable_scraping),
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.weight(1f)
                    )
                    UniformSwitch(
                        checked = enableScraping,
                        onCheckedChange = { enableScraping = it }
                    )
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Default.Warning,
                        contentDescription = null,
                        modifier = Modifier.size(20.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(Modifier.width(Dimens.spacingSm))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = stringResource(R.string.adult_library),
                            style = MaterialTheme.typography.bodyMedium
                        )
                        Text(
                            text = stringResource(R.string.adult_library_desc),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    UniformSwitch(
                        checked = isAdult,
                        onCheckedChange = { isAdult = it }
                    )
                }
            }
        },
        confirmText = stringResource(R.string.save),
        confirmEnabled = name.isNotBlank() && selectedPath.isNotBlank(),
        onConfirm = { onSave(name, selectedPath, type, subType.ifEmpty { null }, description.ifEmpty { null }, enableScraping, isAdult, enabled) },
        onDismiss = onDismiss
    )

    if (showDirectoryPicker) {
        DirectoryPickerDialog(
            uiState = uiState,
            viewModel = viewModel,
            onDismiss = { showDirectoryPicker = false },
            onSelect = { path ->
                selectedPath = path
                showDirectoryPicker = false
            }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DirectoryPickerDialog(
    uiState: MediaLibrariesUiState,
    viewModel: MediaLibrariesViewModel,
    onDismiss: () -> Unit,
    onSelect: (String) -> Unit
) {
    FryfrogDialog(
        onDismissRequest = onDismiss,
        title = stringResource(R.string.select_directory),
        content = {
            Column(modifier = Modifier.fillMaxWidth()) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant
                    ),
                    shape = RoundedCornerShape(Dimens.radiusMd)
                ) {
                    Text(
                        text = uiState.currentPath ?: "/",
                        modifier = Modifier.padding(Dimens.spacingSm),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                Spacer(Modifier.height(Dimens.spacingSm))

                if (uiState.currentPath != null) {
                    ListItem(
                        headlineContent = { Text("..") },
                        leadingContent = { Icon(Icons.Default.ArrowUpward, contentDescription = null) },
                        modifier = Modifier.clickable {
                            val parentPath = uiState.currentPath?.substringBeforeLast("/")
                            viewModel.browseDirectory(parentPath?.ifEmpty { null })
                        }
                    )
                }

                if (uiState.isLoadingDirectories) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(Dimens.listMaxHeight),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator()
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier.heightIn(max = Dimens.listMaxHeight)
                    ) {
                        items(uiState.directories.filter { it.isDirectory }) { dir ->
                            ListItem(
                                headlineContent = { Text(dir.name) },
                                leadingContent = { Icon(Icons.Default.Folder, contentDescription = null) },
                                trailingContent = {
                                    IconButton(onClick = { onSelect(dir.path) }) {
                                        Icon(Icons.Default.Check, contentDescription = stringResource(R.string.select))
                                    }
                                },
                                modifier = Modifier.clickable {
                                    viewModel.browseDirectory(dir.path)
                                }
                            )
                        }
                    }
                }
            }
        },
        confirmText = null,
        onDismiss = onDismiss
    )
}
