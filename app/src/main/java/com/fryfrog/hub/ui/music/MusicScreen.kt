@file:OptIn(ExperimentalMaterial3Api::class)

package com.fryfrog.hub.ui.music

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.AlbumGroup
import com.fryfrog.hub.data.model.MusicTrack
import com.fryfrog.hub.ui.theme.Dimens
import kotlinx.coroutines.delay

@Composable
fun MusicScreen(
    viewModel: MusicViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val playbackState by viewModel.playbackState.collectAsState()

    LaunchedEffect(playbackState.isPlaying) {
        while (playbackState.isPlaying) {
            viewModel.updateProgress()
            delay(500)
        }
    }

    Scaffold(
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.section_music)) },
                modifier = Modifier.statusBarsPadding(),
                actions = {
                    IconButton(onClick = { viewModel.loadMusic() }) {
                        Icon(Icons.Default.Refresh, contentDescription = stringResource(R.string.refresh))
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        },
        bottomBar = {
            // 迷你播放器
            if (playbackState.currentTrack != null) {
                MiniPlayer(
                    track = playbackState.currentTrack!!,
                    isPlaying = playbackState.isPlaying,
                    position = playbackState.currentPosition,
                    duration = playbackState.duration,
                    onPlayPause = { viewModel.togglePlayPause() },
                    onSeek = { viewModel.seekTo(it) }
                )
            }
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
                onRetry = { viewModel.loadMusic() },
                modifier = Modifier.padding(paddingValues)
            )
        } else {
            MusicContent(
                albumGroups = uiState.albumGroups,
                recentlyAdded = uiState.recentlyAdded,
                onTrackClick = { viewModel.playTrack(it) },
                modifier = Modifier.padding(paddingValues)
            )
        }
    }
}

@Composable
private fun MiniPlayer(
    track: MusicTrack,
    isPlaying: Boolean,
    position: Long,
    duration: Long,
    onPlayPause: () -> Unit,
    onSeek: (Long) -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.surfaceVariant,
        tonalElevation = 4.dp
    ) {
        Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // 封面
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(MaterialTheme.colorScheme.surface)
                ) {
                    if (track.coverUrl != null) {
                        AsyncImage(
                            model = track.coverUrl,
                            contentDescription = null,
                            modifier = Modifier.fillMaxSize(),
                            contentScale = ContentScale.Crop
                        )
                    }
                }

                Spacer(modifier = Modifier.width(12.dp))

                // 曲目信息
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = track.title,
                        style = MaterialTheme.typography.bodyMedium,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Text(
                        text = track.artist ?: "",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }

                // 播放/暂停按钮
                IconButton(onClick = onPlayPause) {
                    Icon(
                        imageVector = if (isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                        contentDescription = if (isPlaying) stringResource(R.string.pause) else stringResource(R.string.play),
                        tint = MaterialTheme.colorScheme.primary
                    )
                }
            }

            // 进度条
            if (duration > 0) {
                Slider(
                    value = position.toFloat(),
                    valueRange = 0f..duration.toFloat(),
                    onValueChange = { onSeek(it.toLong()) },
                    modifier = Modifier.fillMaxWidth(),
                    colors = SliderDefaults.colors(
                        thumbColor = MaterialTheme.colorScheme.primary,
                        activeTrackColor = MaterialTheme.colorScheme.primary
                    )
                )
            }
        }
    }
}

@Composable
private fun MusicContent(
    albumGroups: List<AlbumGroup>,
    recentlyAdded: List<MusicTrack>,
    onTrackClick: (MusicTrack) -> Unit,
    modifier: Modifier = Modifier
) {
    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = Dimens.spacingLg)
    ) {
        if (albumGroups.isNotEmpty()) {
            item { SectionHeader(title = stringResource(R.string.section_albums)) }
            items(albumGroups) { album ->
                AlbumCard(album = album, onTrackClick = onTrackClick)
            }
        }

        if (recentlyAdded.isNotEmpty()) {
            item {
                Spacer(modifier = Modifier.height(Dimens.spacingXl))
                SectionHeader(title = stringResource(R.string.section_recently_added))
            }
            item {
                LazyRow(
                    contentPadding = PaddingValues(horizontal = Dimens.spacingLg),
                    horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
                ) {
                    items(recentlyAdded) { track ->
                        MusicCard(track = track, onClick = { onTrackClick(track) })
                    }
                }
            }
        }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleMedium,
        modifier = Modifier.padding(horizontal = Dimens.spacingLg, vertical = Dimens.spacingMd)
    )
}

@Composable
private fun AlbumCard(album: AlbumGroup, onTrackClick: (MusicTrack) -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Dimens.spacingLg, vertical = Dimens.spacingSm)
            .clickable { album.tracks?.firstOrNull()?.let { onTrackClick(it) } },
        shape = RoundedCornerShape(Dimens.radiusMd)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(Dimens.spacingMd),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier.size(80.dp)
                    .clip(RoundedCornerShape(Dimens.radiusSm))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
            ) {
                if (album.coverUrl != null) {
                    AsyncImage(model = album.coverUrl, contentDescription = album.album, modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
                }
            }
            Spacer(modifier = Modifier.width(Dimens.spacingMd))
            Column(modifier = Modifier.weight(1f)) {
                Text(text = album.album ?: stringResource(R.string.unknown_album), style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(text = album.artist ?: stringResource(R.string.unknown), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
                album.year?.let { Text(text = it.toString(), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
            }
            album.tracks?.size?.let { Text(text = "$it ${stringResource(R.string.tracks)}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
    }
}

@Composable
private fun MusicCard(track: MusicTrack, onClick: () -> Unit) {
    Column(
        modifier = Modifier.width(120.dp).clickable(onClick = onClick)
    ) {
        Box(
            modifier = Modifier.fillMaxWidth().aspectRatio(1f)
                .clip(RoundedCornerShape(Dimens.radiusMd))
                .background(MaterialTheme.colorScheme.surfaceVariant)
        ) {
            if (track.coverUrl != null) {
                AsyncImage(model = track.coverUrl, contentDescription = track.title, modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
            } else {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text(text = track.title.take(1), style = MaterialTheme.typography.headlineMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        Spacer(modifier = Modifier.height(Dimens.spacingSm))
        Text(text = track.title, style = MaterialTheme.typography.bodySmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text(text = track.artist ?: stringResource(R.string.unknown), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun ErrorContent(message: String, onRetry: () -> Unit, modifier: Modifier = Modifier) {
    Column(modifier = modifier.fillMaxSize(), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(text = stringResource(R.string.failed_to_load), style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.error)
        Spacer(modifier = Modifier.height(Dimens.spacingSm))
        Text(text = message, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(modifier = Modifier.height(Dimens.spacingLg))
        Button(onClick = onRetry) { Text(stringResource(R.string.retry)) }
    }
}
