@file:OptIn(ExperimentalMaterial3Api::class)

package com.fryfrog.hub.ui.settings

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
import com.fryfrog.hub.ui.theme.*

private val mediaTypes = listOf("VIDEO", "MUSIC", "COMIC", "EBOOK")
private val videoSubTypes = listOf("MOVIE", "TV", "MIXED")

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MediaLibrariesScreen(
    onBackClick: () -> Unit,
    viewModel: MediaLibrariesViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    var showDeleteDialog by remember { mutableStateOf<MediaLibrary?>(null) }
    var showCreateDialog by remember { mutableStateOf(false) }

    LaunchedEffect(uiState.scanMessage) {
        uiState.scanMessage?.let {
            kotlinx.coroutines.delay(2000)
            viewModel.clearScanMessage()
        }
    }

    LaunchedEffect(uiState.error) {
        uiState.error?.let {
            kotlinx.coroutines.delay(3000)
            viewModel.clearError()
        }
    }

    Scaffold(
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.media_libraries)) },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(Icons.Default.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                },
                actions = {
                    if (uiState.libraries.isNotEmpty() && uiState.scanningLibraryIds.isEmpty()) {
                        IconButton(onClick = { viewModel.scanAllLibraries() }) {
                            Icon(
                                Icons.Default.PlayCircle,
                                contentDescription = stringResource(R.string.scan_all),
                                tint = Primary
                            )
                        }
                    }
                    if (uiState.scanningLibraryIds.isNotEmpty()) {
                        CircularProgressIndicator(
                            modifier = Modifier
                                .size(24.dp)
                                .padding(2.dp),
                            strokeWidth = 2.dp,
                            color = Primary
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = { showCreateDialog = true },
                containerColor = Primary,
                contentColor = androidx.compose.ui.graphics.Color.White
            ) {
                Icon(Icons.Default.Add, contentDescription = null)
                Spacer(Modifier.width(Dimens.spacingSm))
                Text(stringResource(R.string.add))
            }
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            if (uiState.isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.align(Alignment.Center)
                )
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
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(
                        start = Dimens.spacingLg,
                        top = Dimens.spacingLg,
                        end = Dimens.spacingLg,
                        bottom = 88.dp
                    ),
                    verticalArrangement = Arrangement.spacedBy(Dimens.spacingSm)
                ) {
                    items(uiState.libraries, key = { it.id }) { library ->
                        MediaLibraryItem(
                            library = library,
                            isScanning = library.id in uiState.scanningLibraryIds,
                            onToggle = { viewModel.toggleLibrary(library) },
                            onScan = { viewModel.scanLibrary(library) },
                            onDelete = { showDeleteDialog = library },
                            onScrapingToggle = { viewModel.updateLibraryScraping(library, it) },
                            onIsAdultToggle = { viewModel.updateLibraryIsAdult(library, it) }
                        )
                    }
                }
            }

            // 扫描消息
            uiState.scanMessage?.let { message ->
                Snackbar(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(Dimens.spacingLg),
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                    contentColor = MaterialTheme.colorScheme.onPrimaryContainer
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                        Spacer(Modifier.width(Dimens.spacingSm))
                        Text(message, style = MaterialTheme.typography.bodyMedium)
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
        }
    }

    // 删除对话框
    showDeleteDialog?.let { library ->
        AlertDialog(
            onDismissRequest = { showDeleteDialog = null },
            title = { Text(stringResource(R.string.delete_library)) },
            text = { Text(stringResource(R.string.delete_library_confirm, library.name)) },
            confirmButton = {
                TextButton(onClick = { viewModel.deleteLibrary(library); showDeleteDialog = null }) {
                    Text(stringResource(R.string.delete), color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = null }) { Text(stringResource(R.string.cancel)) }
            }
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
}

@Composable
private fun MediaLibraryItem(
    library: MediaLibrary,
    isScanning: Boolean,
    onToggle: () -> Unit,
    onScan: () -> Unit,
    onDelete: () -> Unit,
    onScrapingToggle: (Boolean) -> Unit,
    onIsAdultToggle: (Boolean) -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(Dimens.radiusMd),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        )
    ) {
        Column {
            // 第一行：图标 + 信息 + 启用开关 + 操作按钮
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onToggle() }
                    .padding(Dimens.spacingMd),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // 类型图标
                Box(
                    modifier = Modifier
                        .size(Dimens.avatarSize)
                        .clip(CircleShape)
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
                        modifier = Modifier.size(Dimens.avatarIconSize)
                    )
                }

                // 信息
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .padding(horizontal = Dimens.spacingMd)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = library.name,
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.Medium,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        if (library.isAdult == true) {
                            Spacer(Modifier.width(Dimens.spacingXs))
                            Surface(
                                color = Color(0xFFFF4D4F),
                                shape = RoundedCornerShape(Dimens.radiusSm)
                            ) {
                                Text(
                                    text = stringResource(R.string.adult_library_badge),
                                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = Color.White
                                )
                            }
                        }
                        if (!library.enabled) {
                            Spacer(Modifier.width(Dimens.spacingXs))
                            Surface(
                                color = MaterialTheme.colorScheme.surfaceVariant,
                                shape = RoundedCornerShape(Dimens.radiusSm)
                            ) {
                                Text(
                                    text = stringResource(R.string.disabled),
                                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                    Text(
                        text = library.path,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }

                // 操作
                Column(
                    horizontalAlignment = Alignment.End,
                    verticalArrangement = Arrangement.spacedBy(Dimens.spacingXs)
                ) {
                    Switch(
                        checked = library.enabled,
                        onCheckedChange = null
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(Dimens.spacingXs)) {
                        IconButton(
                            onClick = onScan,
                            enabled = !isScanning,
                            modifier = Modifier.size(Dimens.smallButtonSize),
                            colors = IconButtonDefaults.iconButtonColors(
                                containerColor = Primary.copy(alpha = 0.1f),
                                contentColor = Primary,
                                disabledContainerColor = Primary.copy(alpha = 0.05f),
                                disabledContentColor = Primary.copy(alpha = 0.5f)
                            )
                        ) {
                            if (isScanning) {
                                CircularProgressIndicator(
                                    modifier = Modifier.size(Dimens.smallIconSize),
                                    strokeWidth = 2.dp,
                                    color = Primary
                                )
                            } else {
                                Icon(Icons.Default.Refresh, contentDescription = stringResource(R.string.scan), modifier = Modifier.size(Dimens.smallIconSize))
                            }
                        }
                        IconButton(
                            onClick = onDelete,
                            modifier = Modifier.size(Dimens.smallButtonSize),
                            colors = IconButtonDefaults.iconButtonColors(
                                containerColor = MaterialTheme.colorScheme.errorContainer,
                                contentColor = MaterialTheme.colorScheme.error
                            )
                        ) {
                            Icon(Icons.Default.Delete, contentDescription = stringResource(R.string.delete), modifier = Modifier.size(Dimens.smallIconSize))
                        }
                    }
                }
            }

            // 第二行：刮削开关
            HorizontalDivider(
                modifier = Modifier.padding(horizontal = Dimens.spacingMd),
                color = MaterialTheme.colorScheme.outlineVariant
            )
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Dimens.spacingMd, vertical = Dimens.spacingSm),
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
                Text(
                    text = if (library.enableScraping != false) stringResource(R.string.scraping_on) else stringResource(R.string.scraping_off),
                    style = MaterialTheme.typography.bodySmall,
                    color = if (library.enableScraping != false) Primary else MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(Modifier.width(Dimens.spacingSm))
                Switch(
                    checked = library.enableScraping != false,
                    onCheckedChange = onScrapingToggle
                )
            }

            // 第三行：成人内容开关
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Dimens.spacingMd, vertical = Dimens.spacingSm),
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
                Spacer(Modifier.width(Dimens.spacingSm))
                Switch(
                    checked = library.isAdult == true,
                    onCheckedChange = onIsAdultToggle
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

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.create_library)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(Dimens.spacingMd)) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text(stringResource(R.string.library_name)) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )

                OutlinedTextField(
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
                    OutlinedTextField(
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
                        OutlinedTextField(
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

                OutlinedTextField(
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
                    Switch(
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
                    Switch(
                        checked = isAdult,
                        onCheckedChange = { isAdult = it }
                    )
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = { onCreate(name, selectedPath, type, subType.ifEmpty { null }, description.ifEmpty { null }, enableScraping, isAdult) },
                enabled = name.isNotBlank() && selectedPath.isNotBlank()
            ) {
                Text(stringResource(R.string.create))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) }
        }
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
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.select_directory)) },
        text = {
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
        confirmButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) }
        }
    )
}
