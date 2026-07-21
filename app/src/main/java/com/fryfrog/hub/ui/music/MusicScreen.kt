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
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.AlbumGroup
import com.fryfrog.hub.data.model.MusicTrack
import com.fryfrog.hub.ui.theme.*
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
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Dimens.spacingLg, vertical = Dimens.spacingSm)
            .shadow(
                elevation = 8.dp,
                shape = RoundedCornerShape(Dimens.radiusLg),
                ambientColor = Primary.copy(alpha = 0.2f)
            ),
        shape = RoundedCornerShape(Dimens.radiusLg),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        )
    ) {
        Column(modifier = Modifier.padding(Dimens.spacingMd)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // 封面 - 带品牌色渐变背景
                Box(
                    modifier = Modifier
                        .size(52.dp)
                        .clip(RoundedCornerShape(Dimens.radiusMd))
                        .background(
                            Brush.linearGradient(
                                colors = listOf(Primary.copy(alpha = 0.3f), Primary.copy(alpha = 0.1f))
                            )
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    if (track.coverUrl != null) {
                        AsyncImage(
                            model = track.coverUrl,
                            contentDescription = null,
                            modifier = Modifier.fillMaxSize().clip(RoundedCornerShape(Dimens.radiusMd)),
                            contentScale = ContentScale.Crop
                        )
                    } else {
                        Icon(
                            imageVector = Icons.Default.MusicNote,
                            contentDescription = null,
                            tint = Primary,
                            modifier = Modifier.size(24.dp)
                        )
                    }
                }

                Spacer(modifier = Modifier.width(Dimens.spacingMd))

                // 曲目信息
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = track.title,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Medium,
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
                FilledIconButton(
                    onClick = onPlayPause,
                    modifier = Modifier.size(44.dp),
                    colors = IconButtonDefaults.filledIconButtonColors(
                        containerColor = Primary
                    )
                ) {
                    Icon(
                        imageVector = if (isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                        contentDescription = if (isPlaying) stringResource(R.string.pause) else stringResource(R.string.play),
                        tint = Color.White
                    )
                }
            }

            // 进度条
            if (duration > 0) {
                Spacer(modifier = Modifier.height(Dimens.spacingSm))
                Slider(
                    value = position.toFloat(),
                    valueRange = 0f..duration.toFloat(),
                    onValueChange = { onSeek(it.toLong()) },
                    modifier = Modifier.fillMaxWidth(),
                    colors = SliderDefaults.colors(
                        thumbColor = Primary,
                        activeTrackColor = Primary,
                        inactiveTrackColor = Primary.copy(alpha = 0.2f)
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
            item { SectionTitle(title = stringResource(R.string.section_albums)) }
            items(albumGroups) { album ->
                AlbumCard(album = album, onTrackClick = onTrackClick)
            }
        }

        if (recentlyAdded.isNotEmpty()) {
            item {
                Spacer(modifier = Modifier.height(Dimens.spacingXl))
                SectionTitle(title = stringResource(R.string.section_recently_added))
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
private fun SectionTitle(title: String) {
    Row(
        modifier = Modifier.padding(horizontal = Dimens.spacingLg, vertical = Dimens.spacingMd),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .width(4.dp)
                .height(16.dp)
                .clip(RoundedCornerShape(2.dp))
                .background(Primary)
        )
        Spacer(modifier = Modifier.width(Dimens.spacingSm))
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold
        )
    }
}

@Composable
private fun AlbumCard(album: AlbumGroup, onTrackClick: (MusicTrack) -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Dimens.spacingLg, vertical = Dimens.spacingSm)
            .shadow(
                elevation = 2.dp,
                shape = RoundedCornerShape(Dimens.radiusMd),
                ambientColor = Primary.copy(alpha = 0.05f)
            )
            .clickable { album.tracks?.firstOrNull()?.let { onTrackClick(it) } },
        shape = RoundedCornerShape(Dimens.radiusMd),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Dimens.spacingMd),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // 封面 - 带品牌色渐变背景
            Box(
                modifier = Modifier
                    .size(80.dp)
                    .clip(RoundedCornerShape(Dimens.radiusMd))
                    .background(
                        Brush.linearGradient(
                            colors = listOf(Primary.copy(alpha = 0.2f), Success.copy(alpha = 0.1f))
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                if (album.coverUrl != null) {
                    AsyncImage(
                        model = album.coverUrl,
                        contentDescription = album.album,
                        modifier = Modifier.fillMaxSize().clip(RoundedCornerShape(Dimens.radiusMd)),
                        contentScale = ContentScale.Crop
                    )
                } else {
                    Icon(
                        imageVector = Icons.Default.MusicNote,
                        contentDescription = null,
                        tint = Primary,
                        modifier = Modifier.size(32.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.width(Dimens.spacingMd))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = album.album ?: stringResource(R.string.unknown_album),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Medium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = album.artist ?: stringResource(R.string.unknown),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                album.year?.let {
                    Text(
                        text = it.toString(),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            // 曲目数量标签
            album.tracks?.size?.let { count ->
                Surface(
                    color = Primary.copy(alpha = 0.1f),
                    shape = RoundedCornerShape(Dimens.radiusSm)
                ) {
                    Text(
                        text = "$count ${stringResource(R.string.tracks)}",
                        modifier = Modifier.padding(horizontal = Dimens.spacingSm, vertical = Dimens.spacingXs),
                        style = MaterialTheme.typography.labelSmall,
                        color = Primary
                    )
                }
            }
        }
    }
}

@Composable
private fun MusicCard(track: MusicTrack, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .width(120.dp)
            .clickable(onClick = onClick)
    ) {
        // 封面 - 带品牌色渐变背景
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(1f)
                .clip(RoundedCornerShape(Dimens.radiusMd))
                .shadow(
                    elevation = 4.dp,
                    shape = RoundedCornerShape(Dimens.radiusMd),
                    ambientColor = Primary.copy(alpha = 0.1f)
                )
                .background(
                    Brush.linearGradient(
                        colors = listOf(Primary.copy(alpha = 0.2f), Success.copy(alpha = 0.1f))
                    )
                ),
            contentAlignment = Alignment.Center
        ) {
            if (track.coverUrl != null) {
                AsyncImage(
                    model = track.coverUrl,
                    contentDescription = track.title,
                    modifier = Modifier.fillMaxSize().clip(RoundedCornerShape(Dimens.radiusMd)),
                    contentScale = ContentScale.Crop
                )
            } else {
                Text(
                    text = track.title.take(1),
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = Primary
                )
            }
        }

        Spacer(modifier = Modifier.height(Dimens.spacingSm))

        Text(
            text = track.title,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.Medium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        Text(
            text = track.artist ?: stringResource(R.string.unknown),
            style = MaterialTheme.typography.labelSmall,
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
        Icon(
            imageVector = Icons.Default.MusicNote,
            contentDescription = null,
            modifier = Modifier.size(64.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
        )
        Spacer(modifier = Modifier.height(Dimens.spacingMd))
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
