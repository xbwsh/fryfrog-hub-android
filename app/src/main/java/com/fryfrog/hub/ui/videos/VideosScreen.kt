package com.fryfrog.hub.ui.videos

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
import androidx.compose.material.icons.filled.BrokenImage
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.SortByAlpha
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.SeriesDTO
import com.fryfrog.hub.ui.theme.Dimens
import com.fryfrog.hub.ui.theme.Primary

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VideosScreen(
    viewModel: VideosViewModel = viewModel(),
    isAdultContentHidden: Boolean = true,
    onVideoClick: (Long, String) -> Unit = { _, _ -> }
) {
    val uiState by viewModel.uiState.collectAsState()
    var showSortMenu by remember { mutableStateOf(false) }

    LaunchedEffect(isAdultContentHidden) {
        viewModel.setAdultContentHidden(isAdultContentHidden)
    }

    val filteredSeries by remember(uiState.series, isAdultContentHidden) {
        derivedStateOf {
            if (isAdultContentHidden) {
                uiState.series.filter { it.isAdult != true }
            } else {
                uiState.series
            }
        }
    }

    Scaffold(
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        topBar = {
            Column(modifier = Modifier.statusBarsPadding()) {
                TopAppBar(
                    title = {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(stringResource(R.string.section_videos))
                            if (isAdultContentHidden) {
                                Spacer(modifier = Modifier.width(Dimens.spacingMd))
                                PrivacyModeBadge()
                            }
                        }
                    },
                    actions = {
                        // Sort menu
                        Box {
                            IconButton(onClick = { showSortMenu = true }) {
                                Icon(
                                    imageVector = Icons.Default.SortByAlpha,
                                    contentDescription = stringResource(R.string.sort),
                                    tint = if (uiState.sortOption != SortOption.DEFAULT) Primary
                                    else MaterialTheme.colorScheme.onBackground
                                )
                            }

                            DropdownMenu(
                                expanded = showSortMenu,
                                onDismissRequest = { showSortMenu = false },
                                modifier = Modifier
                                    .width(200.dp)
                                    .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(Dimens.radiusMd))
                            ) {
                                SortOption.entries.forEachIndexed { index, option ->
                                    if (index > 0 && index % 2 == 0) {
                                        HorizontalDivider(
                                            modifier = Modifier.padding(horizontal = Dimens.spacingMd),
                                            color = MaterialTheme.colorScheme.outlineVariant
                                        )
                                    }
                                    SortMenuItem(
                                        label = stringResource(option.labelResId),
                                        isSelected = option == uiState.sortOption,
                                        onClick = {
                                            viewModel.setSortOption(option)
                                            showSortMenu = false
                                        }
                                    )
                                }
                                HorizontalDivider(
                                    modifier = Modifier.padding(horizontal = Dimens.spacingMd),
                                    color = MaterialTheme.colorScheme.outlineVariant
                                )
                                DropdownMenuItem(
                                    text = {
                                        Text(
                                            text = stringResource(R.string.scrape_adult),
                                            style = MaterialTheme.typography.bodyMedium
                                        )
                                    },
                                    onClick = {
                                        viewModel.scrapeAdultOnly()
                                        showSortMenu = false
                                    },
                                    leadingIcon = {
                                        Icon(
                                            Icons.Default.Warning,
                                            contentDescription = null,
                                            modifier = Modifier.size(20.dp)
                                        )
                                    }
                                )
                            }
                        }

                        IconButton(onClick = { viewModel.loadVideos() }) {
                            Icon(
                                imageVector = Icons.Default.Refresh,
                                contentDescription = stringResource(R.string.refresh)
                            )
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = MaterialTheme.colorScheme.background
                    )
                )

                // Search bar
                TextField(
                    value = uiState.searchQuery,
                    onValueChange = viewModel::setSearchQuery,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = Dimens.spacingLg, vertical = Dimens.spacingSm),
                    placeholder = {
                        Text(
                            text = stringResource(R.string.search_videos),
                            style = MaterialTheme.typography.bodySmall
                        )
                    },
                    singleLine = true,
                    leadingIcon = {
                        Icon(
                            Icons.Default.Search,
                            contentDescription = null,
                            modifier = Modifier.size(Dimens.smallIconSize)
                        )
                    },
                    trailingIcon = {
                        if (uiState.searchQuery.isNotEmpty()) {
                            Icon(
                                Icons.Default.Close,
                                contentDescription = stringResource(R.string.clear_search),
                                modifier = Modifier
                                    .size(Dimens.smallIconSize)
                                    .clickable { viewModel.setSearchQuery("") }
                            )
                        }
                    },
                    colors = TextFieldDefaults.colors(
                        focusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
                        unfocusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent,
                        cursorColor = Primary,
                        focusedTextColor = MaterialTheme.colorScheme.onSurface,
                        unfocusedTextColor = MaterialTheme.colorScheme.onSurface,
                        focusedPlaceholderColor = MaterialTheme.colorScheme.onSurfaceVariant,
                        unfocusedPlaceholderColor = MaterialTheme.colorScheme.onSurfaceVariant,
                        focusedLeadingIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
                        unfocusedLeadingIconColor = MaterialTheme.colorScheme.onSurfaceVariant
                    ),
                    shape = RoundedCornerShape(Dimens.radiusSm),
                    textStyle = MaterialTheme.typography.bodySmall
                )
            }
        }
    ) { paddingValues ->
        Box(modifier = Modifier.fillMaxSize().padding(paddingValues)) {
            if (uiState.isLoading) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator()
                }
            } else if (uiState.error != null) {
                ErrorContent(
                    message = uiState.error ?: stringResource(R.string.unknown_error),
                    onRetry = { viewModel.loadVideos() },
                    modifier = Modifier.fillMaxSize()
                )
            } else if (filteredSeries.isEmpty() && uiState.isLoadingMore) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator()
                }
            } else if (filteredSeries.isEmpty() && uiState.currentPage >= uiState.totalPages - 1) {
                EmptyVideosContent(
                    message = if (uiState.searchQuery.isBlank()) {
                        stringResource(R.string.no_videos)
                    } else {
                        stringResource(R.string.no_search_results)
                    },
                    modifier = Modifier.fillMaxSize()
                )
            } else {
                VideosGrid(
                    series = filteredSeries,
                    isLoadingMore = uiState.isLoadingMore,
                    hasMore = uiState.currentPage < uiState.totalPages - 1,
                    onLoadMore = { viewModel.loadNextPage() },
                    onVideoClick = onVideoClick,
                    modifier = Modifier.fillMaxSize()
                )
            }
        }
    }
}



@Composable
private fun PrivacyModeBadge() {
    Surface(
        shape = RoundedCornerShape(Dimens.radiusFull),
        color = Primary.copy(alpha = 0.14f),
        contentColor = Primary
    ) {
        Row(
            modifier = Modifier.padding(
                horizontal = Dimens.spacingSm,
                vertical = Dimens.spacingXxs
            ),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Dimens.spacingXs)
        ) {
            Icon(
                imageVector = Icons.Default.VisibilityOff,
                contentDescription = null,
                modifier = Modifier.size(Dimens.chipIconSize)
            )
            Text(
                text = stringResource(R.string.privacy_mode),
                style = MaterialTheme.typography.labelSmall,
                maxLines = 1
            )
        }
    }
}

@Composable
private fun VideosGrid(
    series: List<SeriesDTO>,
    isLoadingMore: Boolean,
    hasMore: Boolean,
    onLoadMore: () -> Unit,
    onVideoClick: (Long, String) -> Unit,
    modifier: Modifier = Modifier
) {
    val gridState = rememberLazyGridState()

    LaunchedEffect(gridState, hasMore, isLoadingMore) {
        snapshotFlow {
            val lastVisible = gridState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            val totalItems = gridState.layoutInfo.totalItemsCount
            lastVisible >= totalItems - 5
        }.collect { shouldLoadMore ->
            if (shouldLoadMore && hasMore && !isLoadingMore) {
                onLoadMore()
            }
        }
    }

    LazyVerticalGrid(
        state = gridState,
        columns = GridCells.Adaptive(minSize = Dimens.gridMinCardWidth),
        contentPadding = PaddingValues(Dimens.spacingLg),
        horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd),
        verticalArrangement = Arrangement.spacedBy(Dimens.spacingLg),
        modifier = modifier.fillMaxSize()
    ) {
        items(
            items = series,
            key = { "${it.id}_${it.type}" },
            contentType = { "video_card" }
        ) { item ->
            VideoCard(
                series = item,
                onClick = { onVideoClick(item.id, item.type ?: "series") }
            )
        }

        if (isLoadingMore) {
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

@Composable
private fun EmptyVideosContent(
    message: String,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = message,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun VideoCard(
    series: SeriesDTO,
    onClick: () -> Unit
) {
    val placeholderPainter = rememberVectorPainter(
        Icons.Default.Image
    )
    val errorPainter = rememberVectorPainter(
        Icons.Default.BrokenImage
    )

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
            if (series.coverUrl != null) {
                AsyncImage(
                    model = series.coverUrl,
                    contentDescription = series.title,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop,
                    alignment = Alignment.TopCenter,
                    placeholder = placeholderPainter,
                    error = errorPainter
                )
            } else {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = series.title.take(1),
                        style = MaterialTheme.typography.headlineMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            // 类型标签 - 右上角
            val typeLabel = when (series.mediaType) {
                "movie" -> "电影"
                "tv" -> "剧集"
                else -> null
            }
            typeLabel?.let { label ->
                Surface(
                    modifier = Modifier
                        .padding(Dimens.spacingSm)
                        .align(Alignment.TopEnd),
                    color = MaterialTheme.colorScheme.primary,
                    shape = RoundedCornerShape(Dimens.radiusSm)
                ) {
                    Text(
                        text = label,
                        modifier = Modifier.padding(horizontal = Dimens.spacingXs, vertical = Dimens.spacingXxs),
                        style = MaterialTheme.typography.labelSmall,
                        color = Color.White
                    )
                }
            }

            // R-18 标签 - 类型标签下方
            if (series.isAdult == true) {
                Surface(
                    modifier = Modifier
                        .padding(start = Dimens.spacingSm, end = Dimens.spacingSm, top = 32.dp)
                        .align(Alignment.TopEnd),
                    color = Color(0xFFFF4D4F),
                    shape = RoundedCornerShape(Dimens.radiusSm)
                ) {
                    Text(
                        text = "R-18",
                        modifier = Modifier.padding(horizontal = Dimens.spacingXs, vertical = Dimens.spacingXxs),
                        style = MaterialTheme.typography.labelSmall,
                        color = Color.White
                    )
                }
            }

            // 分辨率徽标 - 右下角（如 "4K" 或 "4K · 1080p"）
            if (!series.resolutions.isNullOrEmpty()) {
                Surface(
                    modifier = Modifier
                        .padding(Dimens.spacingSm)
                        .align(Alignment.BottomEnd),
                    color = Color.Black.copy(alpha = Dimens.alphaOverlay),
                    shape = RoundedCornerShape(Dimens.radiusSm)
                ) {
                    Text(
                        text = series.resolutions.joinToString(" · "),
                        modifier = Modifier.padding(horizontal = Dimens.spacingXs, vertical = Dimens.spacingXxs),
                        style = MaterialTheme.typography.labelSmall,
                        color = Color.White,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(Dimens.spacingSm))

        Text(
            text = series.title,
            style = MaterialTheme.typography.bodyMedium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.fillMaxWidth()
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = series.year?.toString() ?: "",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            series.rating?.let { rating ->
                Text(
                    text = String.format("%.1f", rating),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.primary
                )
            }
        }
    }
}

@Composable
private fun SortMenuItem(
    label: String,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    DropdownMenuItem(
        text = {
            Text(
                text = label,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = if (isSelected) FontWeight.Medium else FontWeight.Normal,
                color = if (isSelected) Primary else MaterialTheme.colorScheme.onSurface
            )
        },
        onClick = onClick,
        leadingIcon = {
            if (isSelected) {
                Icon(
                    Icons.Default.Check,
                    contentDescription = null,
                    tint = Primary,
                    modifier = Modifier.size(20.dp)
                )
            } else {
                Spacer(modifier = Modifier.size(20.dp))
            }
        },
        contentPadding = PaddingValues(horizontal = Dimens.spacingMd, vertical = Dimens.spacingSm)
    )
}

@Composable
private fun ErrorContent(
    message: String,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = stringResource(R.string.failed_to_load),
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.error
        )

        Spacer(modifier = Modifier.height(Dimens.spacingSm))

        Text(
            text = message,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.height(Dimens.spacingLg))

        Button(onClick = onRetry) {
            Text(stringResource(R.string.retry))
        }
    }
}
