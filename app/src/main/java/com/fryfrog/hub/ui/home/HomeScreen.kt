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
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.fryfrog.hub.ui.components.MediaCard
import com.fryfrog.hub.ui.components.SectionHeader
import com.fryfrog.hub.ui.components.WideMediaCard

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
                title = { Text("Fryfrog Hub") },
                actions = {
                    IconButton(onClick = { viewModel.loadHomeData() }) {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = "Refresh"
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
                message = uiState.error ?: "Unknown error",
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
    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 16.dp)
    ) {
        // Video Section
        if (uiState.videoSeries.isNotEmpty()) {
            item {
                SectionHeader(title = "Videos")
            }
            item {
                LazyRow(
                    contentPadding = PaddingValues(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
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

        // Featured Video
        if (uiState.videoSeries.isNotEmpty()) {
            item {
                Spacer(modifier = Modifier.height(16.dp))
                SectionHeader(title = "Continue Watching")
            }
            item {
                val featured = uiState.videoSeries.first()
                WideMediaCard(
                    title = featured.title,
                    subtitle = featured.overview?.take(80),
                    coverUrl = featured.fanartUrl ?: featured.coverUrl,
                    onClick = { onVideoClick(featured.id) },
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
            }
        }

        // Music Section
        if (uiState.musicAlbums.isNotEmpty()) {
            item {
                Spacer(modifier = Modifier.height(24.dp))
                SectionHeader(title = "Music")
            }
            item {
                LazyRow(
                    contentPadding = PaddingValues(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(uiState.musicAlbums) { album ->
                        MediaCard(
                            title = album.album ?: "Unknown Album",
                            subtitle = album.artist,
                            coverUrl = album.coverUrl,
                            onClick = { album.tracks?.firstOrNull()?.let { onMusicClick(it.id) } }
                        )
                    }
                }
            }
        }

        // Comic Section
        if (uiState.comicSeries.isNotEmpty()) {
            item {
                Spacer(modifier = Modifier.height(24.dp))
                SectionHeader(title = "Comics")
            }
            item {
                LazyRow(
                    contentPadding = PaddingValues(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(uiState.comicSeries) { series ->
                        MediaCard(
                            title = series.name ?: "Unknown",
                            subtitle = series.author,
                            coverUrl = series.coverUrl,
                            onClick = { series.seriesId?.let { onComicClick(it) } }
                        )
                    }
                }
            }
        }

        // Ebook Section
        if (uiState.ebookSeries.isNotEmpty()) {
            item {
                Spacer(modifier = Modifier.height(24.dp))
                SectionHeader(title = "Ebooks")
            }
            item {
                LazyRow(
                    contentPadding = PaddingValues(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(uiState.ebookSeries) { series ->
                        MediaCard(
                            title = series.name ?: "Unknown",
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
            text = "Failed to load data",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.error
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = message,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.height(16.dp))

        Button(onClick = onRetry) {
            Text("Retry")
        }
    }
}
