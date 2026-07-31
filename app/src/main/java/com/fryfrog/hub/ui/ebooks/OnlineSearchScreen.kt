package com.fryfrog.hub.ui.ebooks

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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.OnlineBookResult
import com.fryfrog.hub.ui.theme.Dimens

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OnlineSearchScreen(
    onBack: () -> Unit,
    onBookAdded: (Long) -> Unit,
    viewModel: OnlineSearchViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    var searchQuery by remember { mutableStateOf("") }
    var showSourceMenu by remember { mutableStateOf(false) }

    LaunchedEffect(uiState.addedBookUrl) {
        uiState.addedBookUrl?.let {
            kotlinx.coroutines.delay(1500)
            viewModel.clearMessages()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.online_search)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            // Search Bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(Dimens.spacingSm),
                verticalAlignment = Alignment.CenterVertically
            ) {
                OutlinedTextField(
                    value = searchQuery,
                    onValueChange = { searchQuery = it },
                    modifier = Modifier
                        .weight(1f)
                        .height(56.dp),
                    placeholder = { Text(stringResource(R.string.search_hint)) },
                    singleLine = true,
                    leadingIcon = {
                        Icon(Icons.Default.Search, contentDescription = null)
                    },
                    trailingIcon = {
                        if (searchQuery.isNotEmpty()) {
                            IconButton(onClick = {
                                searchQuery = ""
                                viewModel.search("")
                            }) {
                                Icon(Icons.Default.Clear, contentDescription = stringResource(R.string.clear_search))
                            }
                        }
                    }
                )

                Spacer(modifier = Modifier.width(Dimens.spacingXs))

                // Source Filter
                Box {
                    IconButton(onClick = { showSourceMenu = true }) {
                        Icon(
                            Icons.Default.FilterList,
                            contentDescription = stringResource(R.string.select_source)
                        )
                    }
                    DropdownMenu(
                        expanded = showSourceMenu,
                        onDismissRequest = { showSourceMenu = false }
                    ) {
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.all_sources)) },
                            onClick = {
                                viewModel.selectSource(null)
                                showSourceMenu = false
                            },
                            leadingIcon = {
                                Icon(Icons.Default.AllInclusive, contentDescription = null)
                            }
                        )
                        uiState.sources.forEach { source ->
                            DropdownMenuItem(
                                text = { Text(source.name) },
                                onClick = {
                                    viewModel.selectSource(source.id)
                                    showSourceMenu = false
                                },
                                leadingIcon = {
                                    Icon(Icons.Default.Language, contentDescription = null)
                                }
                            )
                        }
                    }
                }

                IconButton(onClick = { viewModel.search(searchQuery) }) {
                    Icon(
                        Icons.Default.Search,
                        contentDescription = stringResource(R.string.search_hint)
                    )
                }
            }

            // Results
            Box(
                modifier = Modifier.fillMaxSize()
            ) {
                if (uiState.isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.align(Alignment.Center)
                    )
                } else if (uiState.results.isEmpty() && searchQuery.isNotEmpty()) {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(Dimens.spacingLg),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        Icon(
                            Icons.Default.SearchOff,
                            contentDescription = null,
                            modifier = Modifier.size(64.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(Dimens.spacingMd))
                        Text(
                            text = stringResource(R.string.no_search_results_ebook),
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(Dimens.spacingSm),
                        verticalArrangement = Arrangement.spacedBy(Dimens.spacingXs)
                    ) {
                        items(uiState.results) { book ->
                            OnlineBookItem(
                                book = book,
                                isAdded = uiState.addedBookUrl == book.bookUrl,
                                onAddToShelf = { viewModel.addToShelf(book) },
                                onClick = {
                                    // TODO: Navigate to book detail or add to shelf
                                }
                            )
                        }
                    }
                }

                // Snackbar for success/error
                uiState.addedBookUrl?.let {
                    Snackbar(
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .padding(Dimens.spacingMd),
                        containerColor = MaterialTheme.colorScheme.primaryContainer
                    ) {
                        Text(stringResource(R.string.added_to_shelf))
                    }
                }
                uiState.error?.let { error ->
                    Snackbar(
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .padding(Dimens.spacingMd)
                    ) {
                        Text(error)
                    }
                }
            }
        }
    }
}

@Composable
fun OnlineBookItem(
    book: OnlineBookResult,
    isAdded: Boolean,
    onAddToShelf: () -> Unit,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Dimens.spacingSm),
            verticalAlignment = Alignment.Top
        ) {
            // Cover Image
            AsyncImage(
                model = book.coverUrl,
                contentDescription = book.name,
                modifier = Modifier
                    .width(80.dp)
                    .height(110.dp)
                    .clip(MaterialTheme.shapes.small),
                contentScale = ContentScale.Crop
            )

            Spacer(modifier = Modifier.width(Dimens.spacingSm))

            // Book Info
            Column(
                modifier = Modifier
                    .weight(1f)
                    .heightIn(min = 110.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = book.name,
                        style = MaterialTheme.typography.titleMedium,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f)
                    )
                    Spacer(modifier = Modifier.width(Dimens.spacingXs))
                    Surface(
                        color = MaterialTheme.colorScheme.secondaryContainer,
                        shape = MaterialTheme.shapes.extraSmall
                    ) {
                        Text(
                            text = stringResource(R.string.online_book_badge),
                            style = MaterialTheme.typography.labelSmall,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                    }
                }

                if (book.author != null) {
                    Text(
                        text = book.author,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1
                    )
                }

                if (book.kind != null) {
                    Text(
                        text = book.kind,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.primary,
                        maxLines = 1
                    )
                }

                Spacer(modifier = Modifier.height(Dimens.spacingXs))

                if (book.intro != null) {
                    Text(
                        text = book.intro,
                        style = MaterialTheme.typography.bodySmall,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                Spacer(modifier = Modifier.weight(1f))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        if (book.wordCount != null) {
                            Text(
                                text = stringResource(R.string.word_count, book.wordCount),
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        if (book.lastChapter != null) {
                            Text(
                                text = stringResource(R.string.last_chapter, book.lastChapter),
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }

                    if (!isAdded) {
                        FilledTonalButton(
                            onClick = onAddToShelf,
                            modifier = Modifier.height(32.dp),
                            contentPadding = PaddingValues(horizontal = 12.dp)
                        ) {
                            Icon(
                                Icons.Default.Add,
                                contentDescription = null,
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = stringResource(R.string.add_to_shelf),
                                style = MaterialTheme.typography.labelSmall
                            )
                        }
                    } else {
                        Icon(
                            Icons.Default.CheckCircle,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(24.dp)
                        )
                    }
                }
            }
        }
    }
}
