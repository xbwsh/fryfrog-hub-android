package com.fryfrog.hub.ui.home

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.viewmodel.compose.viewModel
import com.fryfrog.hub.R
import com.fryfrog.hub.ui.components.MediaCard
import com.fryfrog.hub.ui.components.SectionHeader
import com.fryfrog.hub.ui.components.WideMediaCard
import com.fryfrog.hub.ui.theme.Dimens

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    viewModel: HomeViewModel = viewModel(),
    onVideoClick: (Long) -> Unit = {},
    onMusicClick: (Long) -> Unit = {},
    onComicClick: (Long) -> Unit = {},
    onEbookClick: (Long) -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.app_name)) },
                actions = {
                    IconButton(onClick = { viewModel.loadHomeData() }) {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = stringResource(R.string.refresh)
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        }
    ) { paddingValues ->
        if (uiState.isLoading) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator()
            }
        } else if (uiState.error != null) {
            ErrorContent(
                message = uiState.error ?: stringResource(R.string.unknown_error),
                onRetry = { viewModel.loadHomeData() },
                modifier = Modifier.padding(paddingValues)
            )
        } else {
            HomeContent(
                uiState = uiState,
                onVideoClick = onVideoClick,
                onMusicClick = onMusicClick,
                onComicClick = onComicClick,
                onEbookClick = onEbookClick,
                modifier = Modifier.padding(paddingValues)
            )
        }
    }
}

@Composable
private fun HomeContent(
    uiState: HomeUiState,
    onVideoClick: (Long) -> Unit,
    onMusicClick: (Long) -> Unit,
    onComicClick: (Long) -> Unit,
    onEbookClick: (Long) -> Unit,
    modifier: Modifier = Modifier
) {
    val unknownTitle = stringResource(R.string.unknown)

    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = Dimens.spacingLg)
    ) {
        if (uiState.videoSeries.isNotEmpty()) {
            item {
                SectionHeader(title = stringResource(R.string.section_videos))
            }
            item {
                LazyRow(
                    contentPadding = PaddingValues(horizontal = Dimens.pageHorizontalPadding),
                    horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
                ) {
                    items(uiState.videoSeries) { series ->
                        MediaCard(
                            title = series.title,
                            subtitle = series.year?.toString(),
                            coverUrl = series.coverUrl,
                            onClick = { onVideoClick(series.id) }
                        )
                    }
                }
            }
        }

        if (uiState.videoSeries.isNotEmpty()) {
            item {
                Spacer(modifier = Modifier.height(Dimens.spacingLg))
                SectionHeader(title = stringResource(R.string.section_continue_watching))
            }
            item {
                LazyRow(
                    contentPadding = PaddingValues(horizontal = Dimens.pageHorizontalPadding),
                    horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
                ) {
                    items(uiState.videoSeries) { series ->
                        WideMediaCard(
                            title = series.title,
                            subtitle = series.overview?.take(50),
                            coverUrl = series.fanartUrl ?: series.coverUrl,
                            onClick = { onVideoClick(series.id) }
                        )
                    }
                }
            }
        }

        if (uiState.musicAlbums.isNotEmpty()) {
            item {
                Spacer(modifier = Modifier.height(Dimens.spacingXl))
                SectionHeader(title = stringResource(R.string.section_music))
            }
            item {
                LazyRow(
                    contentPadding = PaddingValues(horizontal = Dimens.pageHorizontalPadding),
                    horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
                ) {
                    items(uiState.musicAlbums) { album ->
                        MediaCard(
                            title = album.album ?: stringResource(R.string.unknown_album),
                            subtitle = album.artist,
                            coverUrl = album.coverUrl,
                            onClick = { album.tracks?.firstOrNull()?.let { onMusicClick(it.id) } }
                        )
                    }
                }
            }
        }

        if (uiState.comicSeries.isNotEmpty()) {
            item {
                Spacer(modifier = Modifier.height(Dimens.spacingXl))
                SectionHeader(title = stringResource(R.string.section_comics))
            }
            item {
                LazyRow(
                    contentPadding = PaddingValues(horizontal = Dimens.pageHorizontalPadding),
                    horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
                ) {
                    items(uiState.comicSeries) { series ->
                        MediaCard(
                            title = series.name ?: unknownTitle,
                            subtitle = series.author,
                            coverUrl = series.coverUrl,
                            onClick = { series.seriesId?.let { onComicClick(it) } }
                        )
                    }
                }
            }
        }

        if (uiState.ebookSeries.isNotEmpty()) {
            item {
                Spacer(modifier = Modifier.height(Dimens.spacingXl))
                SectionHeader(title = stringResource(R.string.section_ebooks))
            }
            item {
                LazyRow(
                    contentPadding = PaddingValues(horizontal = Dimens.pageHorizontalPadding),
                    horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
                ) {
                    items(uiState.ebookSeries) { series ->
                        MediaCard(
                            title = series.name ?: unknownTitle,
                            subtitle = series.author,
                            coverUrl = series.coverUrl,
                            onClick = { series.seriesId?.let { onEbookClick(it) } }
                        )
                    }
                }
            }
        }
    }
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
