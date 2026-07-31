@file:OptIn(ExperimentalMaterial3Api::class)

package com.fryfrog.hub.ui.ebooks

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.snapshotFlow
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
import com.fryfrog.hub.data.model.EbookSeries
import com.fryfrog.hub.ui.theme.Dimens

@Composable
fun EbooksScreen(
    viewModel: EbooksViewModel = viewModel(),
    onEbookClick: (Long) -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()

    Scaffold(
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.section_ebooks)) },
                modifier = Modifier.statusBarsPadding(),
                actions = {
                    IconButton(onClick = { viewModel.loadEbooks() }) {
                        Icon(Icons.Default.Refresh, contentDescription = stringResource(R.string.refresh))
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        }
    ) { paddingValues ->
        if (uiState.isLoading) {
            Box(
                modifier = Modifier.fillMaxSize().padding(paddingValues),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator()
            }
        } else if (uiState.error != null) {
            ErrorContent(
                message = uiState.error ?: stringResource(R.string.unknown_error),
                onRetry = { viewModel.loadEbooks() },
                modifier = Modifier.padding(paddingValues)
            )
        } else {
            val gridState = rememberLazyGridState()

            LaunchedEffect(gridState) {
                snapshotFlow {
                    val lastVisible = gridState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
                    val totalItems = gridState.layoutInfo.totalItemsCount
                    lastVisible >= totalItems - 5
                }.collect { shouldLoadMore ->
                    if (shouldLoadMore && uiState.currentPage < uiState.totalPages - 1 && !uiState.isLoadingMore) {
                        viewModel.loadNextPage()
                    }
                }
            }

            LazyVerticalGrid(
                state = gridState,
                columns = GridCells.Adaptive(minSize = Dimens.gridMinCardWidth),
                contentPadding = PaddingValues(Dimens.spacingLg),
                horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd),
                verticalArrangement = Arrangement.spacedBy(Dimens.spacingLg),
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
            ) {
                items(uiState.series) { ebook ->
                    EbookCard(
                        ebook = ebook,
                        onClick = {
                            val id = ebook.seriesId ?: ebook.books?.firstOrNull()?.id
                            id?.let { onEbookClick(it) }
                        }
                    )
                }

                if (uiState.isLoadingMore) {
                    item {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(Dimens.spacingLg),
                            contentAlignment = Alignment.Center
                        ) {
                            CircularProgressIndicator(modifier = Modifier.size(24.dp))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun EbookCard(ebook: EbookSeries, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .clip(RoundedCornerShape(Dimens.radiusMd))
            .clickable(onClick = onClick)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(0.7f)
                .clip(RoundedCornerShape(Dimens.radiusMd))
                .background(MaterialTheme.colorScheme.surfaceVariant)
        ) {
            if (ebook.coverUrl != null) {
                AsyncImage(
                    model = ebook.coverUrl,
                    contentDescription = ebook.name,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop,
                    alignment = Alignment.TopCenter
                )
            } else {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = ebook.name?.take(1) ?: "?",
                        style = MaterialTheme.typography.headlineMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            if (ebook.volumeCount != null && ebook.volumeCount > 0) {
                Surface(
                    modifier = Modifier
                        .padding(Dimens.spacingSm)
                        .align(Alignment.TopEnd),
                    color = MaterialTheme.colorScheme.primary,
                    shape = RoundedCornerShape(Dimens.radiusSm)
                ) {
                    Text(
                        text = "${ebook.volumeCount}本",
                        modifier = Modifier.padding(horizontal = Dimens.spacingXs, vertical = Dimens.spacingXxs),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onPrimary
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(Dimens.spacingSm))

        Text(
            text = ebook.name ?: stringResource(R.string.unknown),
            style = MaterialTheme.typography.bodyMedium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.fillMaxWidth()
        )

        Text(
            text = ebook.author ?: stringResource(R.string.unknown),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
private fun ErrorContent(message: String, onRetry: () -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(text = stringResource(R.string.failed_to_load), style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.error)
        Spacer(modifier = Modifier.height(Dimens.spacingSm))
        Text(text = message, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(modifier = Modifier.height(Dimens.spacingLg))
        Button(onClick = onRetry) { Text(stringResource(R.string.retry)) }
    }
}
