package com.fryfrog.hub.ui.settings

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.MediaLibrary
import com.fryfrog.hub.ui.theme.Dimens

private val mediaTypes = listOf("VIDEO", "MUSIC", "COMIC", "EBOOK")
private val videoSubTypes = listOf("MOVIE", "TV", "MIXED")

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    isDarkTheme: Boolean,
    onThemeChange: (Boolean) -> Unit,
    onLogout: () -> Unit = {},
    viewModel: MediaLibrariesViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    var showDeleteDialog by remember { mutableStateOf<MediaLibrary?>(null) }
    var showCreateDialog by remember { mutableStateOf(false) }
    var showLogoutDialog by remember { mutableStateOf(false) }
    val context = androidx.compose.ui.platform.LocalContext.current
    val versionName = remember {
        try {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: "0.0.1"
        } catch (e: Exception) {
            "0.0.1"
        }
    }

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
                title = { Text(stringResource(R.string.section_settings)) },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        }
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(horizontal = Dimens.spacingLg),
            verticalArrangement = Arrangement.spacedBy(Dimens.spacingSm),
            contentPadding = PaddingValues(vertical = Dimens.spacingLg)
        ) {
            // Theme
            item {
                SectionCard {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onThemeChange(!isDarkTheme) }
                            .padding(Dimens.spacingLg),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
                    ) {
                        Icon(
                            imageVector = if (isDarkTheme) Icons.Default.DarkMode else Icons.Default.LightMode,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary
                        )
                        Column(modifier = Modifier.weight(1f)) {
                            Text(stringResource(R.string.theme_mode), style = MaterialTheme.typography.titleMedium)
                            Text(
                                if (isDarkTheme) stringResource(R.string.dark_theme) else stringResource(R.string.light_theme),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Switch(checked = isDarkTheme, onCheckedChange = null)
                    }
                }
            }

            // Media Libraries Header
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = Dimens.spacingSm),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = stringResource(R.string.media_libraries),
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(Dimens.spacingXs)) {
                        FilledTonalButton(
                            onClick = { viewModel.scanAllLibraries() },
                            contentPadding = PaddingValues(horizontal = Dimens.spacingMd, vertical = Dimens.spacingXs),
                            modifier = Modifier.height(32.dp)
                        ) {
                            Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(4.dp))
                            Text(stringResource(R.string.scan_all), style = MaterialTheme.typography.labelMedium)
                        }
                        FilledTonalButton(
                            onClick = { showCreateDialog = true },
                            contentPadding = PaddingValues(horizontal = Dimens.spacingMd, vertical = Dimens.spacingXs),
                            modifier = Modifier.height(32.dp)
                        ) {
                            Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(4.dp))
                            Text(stringResource(R.string.add), style = MaterialTheme.typography.labelMedium)
                        }
                    }
                }
            }

            // Scan message
            uiState.scanMessage?.let { message ->
                item {
                    Snackbar(
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
            }

            // Error
            uiState.error?.let { error ->
                item {
                    Snackbar(
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

            // Loading
            if (uiState.isLoading) {
                item {
                    Box(Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                }
            }

            // Empty state
            if (!uiState.isLoading && uiState.libraries.isEmpty()) {
                item {
                    SectionCard {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(48.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Icon(
                                    Icons.Default.FolderOpen,
                                    contentDescription = null,
                                    modifier = Modifier.size(48.dp),
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
                                )
                                Spacer(Modifier.height(Dimens.spacingSm))
                                Text(
                                    stringResource(R.string.no_libraries),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }

            // Library list
            items(uiState.libraries, key = { it.id }) { library ->
                MediaLibraryItem(
                    library = library,
                    onToggle = { viewModel.toggleLibrary(library) },
                    onScan = { viewModel.scanLibrary(library) },
                    onDelete = { showDeleteDialog = library }
                )
            }

            // Logout
            item {
                Spacer(Modifier.height(Dimens.spacingMd))
                SectionCard {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { showLogoutDialog = true }
                            .padding(Dimens.spacingLg),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Logout,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.error
                        )
                        Text(
                            text = stringResource(R.string.logout),
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.error
                        )
                    }
                }
            }

            // Version
            item {
                Spacer(Modifier.height(Dimens.spacingMd))
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
        AlertDialog(
            onDismissRequest = { showLogoutDialog = false },
            title = { Text(stringResource(R.string.logout)) },
            text = { Text(stringResource(R.string.logout_confirm)) },
            confirmButton = {
                TextButton(onClick = {
                    showLogoutDialog = false
                    onLogout()
                }) {
                    Text(stringResource(R.string.confirm), color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showLogoutDialog = false }) {
                    Text(stringResource(R.string.cancel))
                }
            }
        )
    }

    // Delete dialog
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

    // Create dialog
    if (showCreateDialog) {
        CreateLibraryDialog(
            viewModel = viewModel,
            onDismiss = { showCreateDialog = false },
            onCreate = { name, path, type, subType, desc ->
                viewModel.createLibrary(name, path, type, subType, desc)
                showCreateDialog = false
            }
        )
    }
}

@Composable
private fun SectionCard(content: @Composable ColumnScope.() -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
        )
    ) {
        Column(content = content)
    }
}

@Composable
private fun MediaLibraryItem(
    library: MediaLibrary,
    onToggle: () -> Unit,
    onScan: () -> Unit,
    onDelete: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { onToggle() }
                .padding(Dimens.spacingMd),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
        ) {
            // Type icon
            Icon(
                imageVector = when (library.type) {
                    "VIDEO" -> Icons.Default.VideoLibrary
                    "MUSIC" -> Icons.Default.LibraryMusic
                    "COMIC" -> Icons.Default.Book
                    "EBOOK" -> Icons.Default.ChromeReaderMode
                    else -> Icons.Default.Folder
                },
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(32.dp)
            )

            // Info
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = library.name,
                        style = MaterialTheme.typography.titleSmall,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    if (!library.enabled) {
                        Spacer(Modifier.width(Dimens.spacingXs))
                        Surface(
                            color = MaterialTheme.colorScheme.surfaceVariant,
                            shape = MaterialTheme.shapes.extraSmall
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
                Text(
                    text = library.path,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Row(horizontalArrangement = Arrangement.spacedBy(Dimens.spacingXs)) {
                    SuggestionChip(
                        onClick = {},
                        label = {
                            val label = when (library.type) {
                                "VIDEO" -> stringResource(R.string.type_video)
                                "MUSIC" -> stringResource(R.string.type_music)
                                "COMIC" -> stringResource(R.string.type_comic)
                                "EBOOK" -> stringResource(R.string.type_ebook)
                                else -> library.type
                            }
                            Text(label, style = MaterialTheme.typography.labelSmall)
                        },
                        modifier = Modifier.height(24.dp)
                    )
                    if (library.type == "VIDEO" && library.subType != null) {
                        SuggestionChip(
                            onClick = {},
                            label = {
                                val label = when (library.subType) {
                                    "MOVIE" -> stringResource(R.string.subtype_movie)
                                    "TV" -> stringResource(R.string.subtype_tv)
                                    "MIXED" -> stringResource(R.string.subtype_mixed)
                                    else -> library.subType
                                }
                                Text(label, style = MaterialTheme.typography.labelSmall)
                            },
                            modifier = Modifier.height(24.dp)
                        )
                    }
                }
            }

            // Actions
            IconButton(onClick = onScan, modifier = Modifier.size(32.dp)) {
                Icon(Icons.Default.Refresh, contentDescription = stringResource(R.string.scan), modifier = Modifier.size(18.dp))
            }
            IconButton(onClick = onDelete, modifier = Modifier.size(32.dp)) {
                Icon(Icons.Default.Delete, contentDescription = stringResource(R.string.delete), modifier = Modifier.size(18.dp), tint = MaterialTheme.colorScheme.error)
            }
            Switch(checked = library.enabled, onCheckedChange = null)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CreateLibraryDialog(
    viewModel: MediaLibrariesViewModel,
    onDismiss: () -> Unit,
    onCreate: (name: String, path: String, type: String, subType: String?, description: String?) -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()
    var name by remember { mutableStateOf("") }
    var selectedPath by remember { mutableStateOf("") }
    var type by remember { mutableStateOf("VIDEO") }
    var subType by remember { mutableStateOf("MOVIE") }
    var description by remember { mutableStateOf("") }
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

                // Path selector (click to browse)
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

                // Type selector
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
                        mediaTypes.forEach { t ->
                            val label = when (t) {
                                "VIDEO" -> stringResource(R.string.type_video)
                                "MUSIC" -> stringResource(R.string.type_music)
                                "COMIC" -> stringResource(R.string.type_comic)
                                "EBOOK" -> stringResource(R.string.type_ebook)
                                else -> t
                            }
                            DropdownMenuItem(
                                text = { Text(label) },
                                onClick = { type = t; typeExpanded = false }
                            )
                        }
                    }
                }

                // Sub type for VIDEO
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
                            videoSubTypes.forEach { st ->
                                val label = when (st) {
                                    "MOVIE" -> stringResource(R.string.subtype_movie)
                                    "TV" -> stringResource(R.string.subtype_tv)
                                    "MIXED" -> stringResource(R.string.subtype_mixed)
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
            }
        },
        confirmButton = {
            TextButton(
                onClick = { onCreate(name, selectedPath, type, subType.ifEmpty { null }, description.ifEmpty { null }) },
                enabled = name.isNotBlank() && selectedPath.isNotBlank()
            ) {
                Text(stringResource(R.string.create))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) }
        }
    )

    // Directory picker dialog
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
                // Current path breadcrumb
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant
                    )
                ) {
                    Text(
                        text = uiState.currentPath ?: "/",
                        modifier = Modifier.padding(Dimens.spacingSm),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                Spacer(Modifier.height(Dimens.spacingSm))

                // Back button (if not at root)
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

                // Directory list
                if (uiState.isLoadingDirectories) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(200.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator()
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier.heightIn(max = 300.dp)
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