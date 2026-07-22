@file:OptIn(ExperimentalMaterial3Api::class)

package com.fryfrog.hub.ui.music

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.SkipNext
import androidx.compose.material.icons.filled.SkipPrevious
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.MusicTrack
import com.fryfrog.hub.ui.theme.*
import kotlinx.coroutines.delay
import kotlin.math.roundToInt

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

    // 收集所有曲目
    val allTracks = remember(uiState.albumGroups) {
        uiState.albumGroups.flatMap { it.tracks ?: emptyList() }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        // 顶部栏
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

        // 内容区域
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
                onRetry = { viewModel.loadMusic() }
            )
        } else {
            // 曲目列表
            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(bottom = Dimens.spacingLg)
            ) {
                itemsIndexed(allTracks) { index, track ->
                    TrackListItem(
                        track = track,
                        isPlaying = playbackState.isPlaying && playbackState.currentTrack?.id == track.id,
                        isCurrentTrack = playbackState.currentTrack?.id == track.id,
                        onClick = { viewModel.playTrack(track) }
                    )
                }
            }

            // 底部播放器 - 在内容区域内
            if (playbackState.currentTrack != null) {
                BottomPlayer(
                    track = playbackState.currentTrack!!,
                    isPlaying = playbackState.isPlaying,
                    position = playbackState.currentPosition,
                    duration = playbackState.duration,
                    onPlayPause = { viewModel.togglePlayPause() },
                    onSeek = { viewModel.seekTo(it) },
                    onPrevious = { viewModel.playPrevious() },
                    onNext = { viewModel.playNext() }
                )
            }
        }
    }
}

@Composable
private fun TrackListItem(
    track: MusicTrack,
    isPlaying: Boolean,
    isCurrentTrack: Boolean,
    onClick: () -> Unit
) {
    val backgroundColor by animateColorAsState(
        targetValue = if (isCurrentTrack) Primary.copy(alpha = 0.08f) else Color.Transparent,
        animationSpec = tween(durationMillis = 200),
        label = "trackBg"
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(backgroundColor)
            .clickable(onClick = onClick)
            .padding(horizontal = Dimens.spacingLg, vertical = Dimens.spacingMd),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // 封面
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(RoundedCornerShape(Dimens.radiusSm))
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
                    contentDescription = null,
                    modifier = Modifier.fillMaxSize().clip(RoundedCornerShape(Dimens.radiusSm)),
                    contentScale = ContentScale.Crop
                )
            } else {
                if (isPlaying) {
                    Icon(
                        imageVector = Icons.Default.MusicNote,
                        contentDescription = null,
                        tint = Primary,
                        modifier = Modifier.size(20.dp)
                    )
                } else {
                    Text(
                        text = track.title.take(1),
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = Primary
                    )
                }
            }
        }

        Spacer(modifier = Modifier.width(Dimens.spacingMd))

        // 曲目信息
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = track.title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = if (isCurrentTrack) FontWeight.SemiBold else FontWeight.Medium,
                color = if (isCurrentTrack) Primary else MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = track.artist ?: stringResource(R.string.unknown),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }

        // 时长
        track.duration?.let { duration ->
            Text(
                text = formatDuration(duration),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        // 播放指示器
        if (isCurrentTrack && isPlaying) {
            Spacer(modifier = Modifier.width(Dimens.spacingSm))
            PlayingIndicator()
        }
    }
}

@Composable
private fun PlayingIndicator() {
    Row(
        modifier = Modifier.height(16.dp),
        verticalAlignment = Alignment.Bottom,
        horizontalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        repeat(3) { index ->
            val height by animateFloatAsState(
                targetValue = when (index) {
                    0 -> 8f
                    1 -> 14f
                    2 -> 10f
                    else -> 8f
                },
                animationSpec = tween(
                    durationMillis = 400,
                    delayMillis = index * 100
                ),
                label = "bar$index"
            )
            Box(
                modifier = Modifier
                    .width(3.dp)
                    .height(height.dp)
                    .clip(RoundedCornerShape(1.5.dp))
                    .background(Primary)
            )
        }
    }
}

@Composable
private fun BottomPlayer(
    track: MusicTrack,
    isPlaying: Boolean,
    position: Long,
    duration: Long,
    onPlayPause: () -> Unit,
    onSeek: (Long) -> Unit,
    onPrevious: () -> Unit,
    onNext: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Dimens.spacingLg, vertical = Dimens.spacingSm),
        shape = RoundedCornerShape(Dimens.radiusXl),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
    ) {
        Column(
            modifier = Modifier.padding(Dimens.spacingLg)
        ) {
            // 封面 + 曲目信息 + 控制按钮（同一行）
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // 封面
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .clip(RoundedCornerShape(Dimens.radiusSm))
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
                            modifier = Modifier.fillMaxSize().clip(RoundedCornerShape(Dimens.radiusSm)),
                            contentScale = ContentScale.Crop
                        )
                    } else {
                        Icon(
                            imageVector = Icons.Default.MusicNote,
                            contentDescription = null,
                            tint = Primary,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }

                Spacer(modifier = Modifier.width(Dimens.spacingMd))

                // 曲目信息
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = track.title,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Text(
                        text = track.artist ?: stringResource(R.string.unknown),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }

                Spacer(modifier = Modifier.width(Dimens.spacingSm))

                // 控制按钮
                // 上一曲
                IconButton(
                    onClick = onPrevious,
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.SkipPrevious,
                        contentDescription = stringResource(R.string.previous),
                        tint = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.size(20.dp)
                    )
                }

                // 播放/暂停
                FilledIconButton(
                    onClick = onPlayPause,
                    modifier = Modifier.size(40.dp),
                    colors = IconButtonDefaults.filledIconButtonColors(
                        containerColor = Primary
                    )
                ) {
                    Icon(
                        imageVector = if (isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                        contentDescription = if (isPlaying) stringResource(R.string.pause) else stringResource(R.string.play),
                        tint = Color.White,
                        modifier = Modifier.size(22.dp)
                    )
                }

                // 下一曲
                IconButton(
                    onClick = onNext,
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.SkipNext,
                        contentDescription = stringResource(R.string.next),
                        tint = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }

            // 进度条
            if (duration > 0) {
                Spacer(modifier = Modifier.height(Dimens.spacingSm))
                Column {
                    // 自定义进度条
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(20.dp)
                            .pointerInput(Unit) {
                                detectTapGestures { offset ->
                                    val progress = offset.x / size.width
                                    onSeek((progress * duration).toLong())
                                }
                            }
                    ) {
                        // 背景轨道
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(4.dp)
                                .align(Alignment.Center)
                                .clip(RoundedCornerShape(2.dp))
                                .background(MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.2f))
                        )
                        // 已播放轨道 + 拖动指示器
                        val progress = if (duration > 0) (position.toFloat() / duration.toFloat()).coerceIn(0f, 1f) else 0f
                        Box(
                            modifier = Modifier
                                .fillMaxWidth(fraction = progress)
                                .height(4.dp)
                                .align(Alignment.CenterStart)
                                .clip(RoundedCornerShape(2.dp))
                                .background(Primary)
                        )
                        // 小圆点指示器
                        if (progress > 0f) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth(fraction = progress)
                                    .height(4.dp)
                                    .align(Alignment.CenterStart)
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(10.dp)
                                        .align(Alignment.CenterEnd)
                                        .offset(x = 5.dp)
                                        .clip(CircleShape)
                                        .background(Primary)
                                )
                            }
                        }
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = formatDuration(position),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = formatDuration(duration),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
    }
}

private fun formatDuration(millis: Long): String {
    val totalSeconds = millis / 1000
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60
    return "%d:%02d".format(minutes, seconds)
}

@Composable
private fun ErrorContent(message: String, onRetry: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize(),
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
