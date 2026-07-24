@file:OptIn(ExperimentalMaterial3Api::class)

package com.fryfrog.hub.ui.music

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.filled.Shuffle
import androidx.compose.material.icons.filled.SkipNext
import androidx.compose.material.icons.filled.SkipPrevious
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.content.res.Configuration
import androidx.activity.compose.BackHandler
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
    val lyricsState by viewModel.lyricsState.collectAsState()
    var showLyrics by remember { mutableStateOf(false) }

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

            // 底部播放器 - 始终显示
            BottomPlayer(
                track = playbackState.currentTrack,
                isPlaying = playbackState.isPlaying,
                position = playbackState.currentPosition,
                duration = playbackState.duration,
                onPlayPause = { viewModel.togglePlayPause() },
                onSeek = { viewModel.seekTo(it) },
                onPrevious = { viewModel.playPrevious() },
                onNext = { viewModel.playNext() },
                onCoverClick = {
                    playbackState.currentTrack?.let { track ->
                        showLyrics = true
                        viewModel.loadLyrics(track.id)
                    }
                }
            )
        }
    }

    // 当歌曲切换时重新加载歌词
    LaunchedEffect(playbackState.currentTrack?.id) {
        playbackState.currentTrack?.let { track ->
            if (showLyrics) {
                viewModel.loadLyrics(track.id)
            }
        }
    }

    // 歌词页面 - 带滑入滑出动画
    AnimatedVisibility(
        visible = showLyrics && playbackState.currentTrack != null,
        enter = slideInVertically(
            initialOffsetY = { it },
            animationSpec = tween(durationMillis = 300)
        ) + fadeIn(animationSpec = tween(durationMillis = 300)),
        exit = slideOutVertically(
            targetOffsetY = { it },
            animationSpec = tween(durationMillis = 300)
        ) + fadeOut(animationSpec = tween(durationMillis = 300))
    ) {
        playbackState.currentTrack?.let { track ->
            LyricsScreen(
                track = track,
                isPlaying = playbackState.isPlaying,
                position = playbackState.currentPosition,
                duration = playbackState.duration,
                lyricsState = lyricsState,
                onDismiss = { showLyrics = false },
                onPlayPause = { viewModel.togglePlayPause() },
                onPrevious = { viewModel.playPrevious() },
                onNext = { viewModel.playNext() },
                onSeek = { viewModel.seekTo(it) }
            )
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
                .size(40.dp)
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
                        modifier = Modifier.size(16.dp)
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
    track: MusicTrack?,
    isPlaying: Boolean,
    position: Long,
    duration: Long,
    onPlayPause: () -> Unit,
    onSeek: (Long) -> Unit,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
    onCoverClick: () -> Unit
) {
    // 旋转动画
    val infiniteTransition = rememberInfiniteTransition(label = "rotation")
    val rotation by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 3000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "rotationAngle"
    )

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
                // 封面 - 点击显示歌词
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(RoundedCornerShape(Dimens.radiusSm))
                        .background(
                            Brush.linearGradient(
                                colors = listOf(Primary.copy(alpha = 0.3f), Primary.copy(alpha = 0.1f))
                            )
                        )
                        .clickable(enabled = track != null, onClick = onCoverClick),
                    contentAlignment = Alignment.Center
                ) {
                    if (track?.coverUrl != null) {
                        AsyncImage(
                            model = track.coverUrl,
                            contentDescription = null,
                            modifier = Modifier.fillMaxSize().clip(RoundedCornerShape(Dimens.radiusSm)),
                            contentScale = ContentScale.Crop
                        )
                    } else {
                        // 旋转的音乐图标
                        Icon(
                            imageVector = Icons.Default.MusicNote,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                            modifier = Modifier
                                .size(24.dp)
                                .rotate(if (isPlaying && track != null) rotation else 0f)
                        )
                    }
                }

                Spacer(modifier = Modifier.width(Dimens.spacingMd))

                // 曲目信息
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = track?.title ?: stringResource(R.string.section_music),
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        color = if (track != null) MaterialTheme.colorScheme.onSurface
                        else MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        text = track?.artist ?: stringResource(R.string.unknown),
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
                    modifier = Modifier.size(30.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.SkipPrevious,
                        contentDescription = stringResource(R.string.previous),
                        tint = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.size(16.dp)
                    )
                }

                // 播放/暂停
                FilledIconButton(
                    onClick = onPlayPause,
                    modifier = Modifier.size(34.dp),
                    colors = IconButtonDefaults.filledIconButtonColors(
                        containerColor = Primary
                    )
                ) {
                    Icon(
                        imageVector = if (isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                        contentDescription = if (isPlaying) stringResource(R.string.pause) else stringResource(R.string.play),
                        tint = Color.White,
                        modifier = Modifier.size(18.dp)
                    )
                }

                // 下一曲
                IconButton(
                    onClick = onNext,
                    modifier = Modifier.size(30.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.SkipNext,
                        contentDescription = stringResource(R.string.next),
                        tint = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.size(16.dp)
                    )
                }
            }

            // 进度条 - 始终显示
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
                    // 已播放轨道
                    val progress = if (duration > 0) (position.toFloat() / duration.toFloat()).coerceIn(0f, 1f) else 0f
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(fraction = progress)
                            .height(4.dp)
                            .align(Alignment.CenterStart)
                            .clip(RoundedCornerShape(2.dp))
                            .background(Primary)
                    )
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
            modifier = Modifier.size(48.dp),
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

@Composable
private fun LyricsScreen(
    track: MusicTrack,
    isPlaying: Boolean,
    position: Long,
    duration: Long,
    lyricsState: LyricsState,
    onDismiss: () -> Unit,
    onPlayPause: () -> Unit,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
    onSeek: (Long) -> Unit
) {
    // 处理返回键
    BackHandler {
        onDismiss()
    }

    val configuration = LocalConfiguration.current
    val isLandscape = configuration.orientation == Configuration.ORIENTATION_LANDSCAPE

    if (isLandscape) {
        LyricsLandscapeLayout(
            track = track,
            isPlaying = isPlaying,
            position = position,
            duration = duration,
            lyricsState = lyricsState,
            onDismiss = onDismiss,
            onPlayPause = onPlayPause,
            onPrevious = onPrevious,
            onNext = onNext,
            onSeek = onSeek
        )
    } else {
        LyricsPortraitLayout(
            track = track,
            isPlaying = isPlaying,
            position = position,
            duration = duration,
            lyricsState = lyricsState,
            onDismiss = onDismiss,
            onPlayPause = onPlayPause,
            onPrevious = onPrevious,
            onNext = onNext,
            onSeek = onSeek
        )
    }
}

@Composable
private fun LyricsPortraitLayout(
    track: MusicTrack,
    isPlaying: Boolean,
    position: Long,
    duration: Long,
    lyricsState: LyricsState,
    onDismiss: () -> Unit,
    onPlayPause: () -> Unit,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
    onSeek: (Long) -> Unit
) {
    val lazyListState = rememberLazyListState()

    // 旋转动画
    val infiniteTransition = rememberInfiniteTransition(label = "lyricsRotation")
    val rotation by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 20000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "rotationAngle"
    )

    // 当前高亮行索引
    val currentLineIndex by remember(position, lyricsState.parsedLyrics) {
        mutableIntStateOf(
            if (lyricsState.parsedLyrics.isEmpty()) {
                0
            } else {
                var index = 0
                for (i in lyricsState.parsedLyrics.indices) {
                    if (position >= lyricsState.parsedLyrics[i].timeMs) {
                        index = i
                    } else {
                        break
                    }
                }
                index
            }
        )
    }

    // 自动滚动到当前歌词行
    LaunchedEffect(currentLineIndex) {
        if (lyricsState.parsedLyrics.isNotEmpty() && currentLineIndex >= 0) {
            lazyListState.animateScrollToItem(
                index = currentLineIndex,
                scrollOffset = -300
            )
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        // 背景封面 - 渐变遮罩
        if (track.coverUrl != null) {
            Box(modifier = Modifier.fillMaxSize()) {
                AsyncImage(
                    model = track.coverUrl,
                    contentDescription = null,
                    modifier = Modifier
                        .fillMaxSize()
                        .alpha(0.15f),
                    contentScale = ContentScale.Crop
                )
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(
                                    MaterialTheme.colorScheme.background.copy(alpha = 0.9f),
                                    MaterialTheme.colorScheme.background.copy(alpha = 0.7f),
                                    MaterialTheme.colorScheme.background.copy(alpha = 0.9f)
                                )
                            )
                        )
                )
            }
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
        ) {
            // 顶部导航栏
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Dimens.spacingLg, vertical = Dimens.spacingSm),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onDismiss) {
                    Icon(
                        imageVector = Icons.Default.KeyboardArrowDown,
                        contentDescription = "返回",
                        modifier = Modifier.size(22.dp),
                        tint = MaterialTheme.colorScheme.onSurface
                    )
                }
                Text(
                    text = "正在播放",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.size(36.dp))
            }

            // 封面区域
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                contentAlignment = Alignment.Center
            ) {
                AlbumCover(
                    track = track,
                    isPlaying = isPlaying,
                    rotation = rotation,
                    size = 220.dp
                )
            }

            // 歌词区域
            LyricsContent(
                lyricsState = lyricsState,
                currentLineIndex = currentLineIndex,
                lazyListState = lazyListState,
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .padding(horizontal = Dimens.spacingXl)
            )

            // 底部控制栏
            PlayerControls(
                isPlaying = isPlaying,
                position = position,
                duration = duration,
                onPlayPause = onPlayPause,
                onPrevious = onPrevious,
                onNext = onNext,
                onSeek = onSeek,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Dimens.spacingXl, vertical = Dimens.spacingMd)
            )
        }
    }
}

@Composable
private fun LyricsLandscapeLayout(
    track: MusicTrack,
    isPlaying: Boolean,
    position: Long,
    duration: Long,
    lyricsState: LyricsState,
    onDismiss: () -> Unit,
    onPlayPause: () -> Unit,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
    onSeek: (Long) -> Unit
) {
    val lazyListState = rememberLazyListState()

    // 旋转动画
    val infiniteTransition = rememberInfiniteTransition(label = "lyricsRotation")
    val rotation by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 20000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "rotationAngle"
    )

    // 当前高亮行索引
    val currentLineIndex by remember(position, lyricsState.parsedLyrics) {
        mutableIntStateOf(
            if (lyricsState.parsedLyrics.isEmpty()) {
                0
            } else {
                var index = 0
                for (i in lyricsState.parsedLyrics.indices) {
                    if (position >= lyricsState.parsedLyrics[i].timeMs) {
                        index = i
                    } else {
                        break
                    }
                }
                index
            }
        )
    }

    // 自动滚动到当前歌词行
    LaunchedEffect(currentLineIndex) {
        if (lyricsState.parsedLyrics.isNotEmpty() && currentLineIndex >= 0) {
            lazyListState.animateScrollToItem(
                index = currentLineIndex,
                scrollOffset = -300
            )
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        // 背景封面 - 渐变遮罩
        if (track.coverUrl != null) {
            Box(modifier = Modifier.fillMaxSize()) {
                AsyncImage(
                    model = track.coverUrl,
                    contentDescription = null,
                    modifier = Modifier
                        .fillMaxSize()
                        .alpha(0.15f),
                    contentScale = ContentScale.Crop
                )
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(
                                    MaterialTheme.colorScheme.background.copy(alpha = 0.9f),
                                    MaterialTheme.colorScheme.background.copy(alpha = 0.7f),
                                    MaterialTheme.colorScheme.background.copy(alpha = 0.9f)
                                )
                            )
                        )
                )
            }
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
        ) {
            // 顶部导航栏
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Dimens.spacingLg, vertical = Dimens.spacingSm),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onDismiss) {
                    Icon(
                        imageVector = Icons.Default.KeyboardArrowDown,
                        contentDescription = "返回",
                        modifier = Modifier.size(22.dp),
                        tint = MaterialTheme.colorScheme.onSurface
                    )
                }
                Text(
                    text = "正在播放",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.size(36.dp))
            }

            // 横屏布局：左侧封面+控件，右侧歌词
            Row(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = Dimens.spacingLg)
            ) {
                // 左侧：封面 + 控件
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    // 封面
                    AlbumCover(
                        track = track,
                        isPlaying = isPlaying,
                        rotation = rotation,
                        size = 160.dp
                    )

                    Spacer(modifier = Modifier.height(Dimens.spacingLg))

                    // 歌曲信息
                    Text(
                        text = track.title,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.fillMaxWidth()
                    )
                    Text(
                        text = track.artist ?: "",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.fillMaxWidth()
                    )

                    Spacer(modifier = Modifier.height(Dimens.spacingLg))

                    // 进度条和控件
                    PlayerControls(
                        isPlaying = isPlaying,
                        position = position,
                        duration = duration,
                        onPlayPause = onPlayPause,
                        onPrevious = onPrevious,
                        onNext = onNext,
                        onSeek = onSeek,
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                Spacer(modifier = Modifier.width(Dimens.spacingXl))

                // 右侧：歌词
                LyricsContent(
                    lyricsState = lyricsState,
                    currentLineIndex = currentLineIndex,
                    lazyListState = lazyListState,
                    modifier = Modifier
                        .weight(1.5f)
                        .fillMaxHeight()
                )
            }
        }
    }
}

@Composable
private fun AlbumCover(
    track: MusicTrack,
    isPlaying: Boolean,
    rotation: Float,
    size: Dp
) {
    Box(
        modifier = Modifier
            .size(size)
            .clip(CircleShape)
            .background(
                Brush.radialGradient(
                    colors = listOf(
                        Color.Black.copy(alpha = 0.3f),
                        Color.Black.copy(alpha = 0.1f)
                    )
                )
            )
            .shadow(16.dp, CircleShape)
            .rotate(if (isPlaying) rotation else 0f),
        contentAlignment = Alignment.Center
    ) {
        // 唱片中心孔
        Box(
            modifier = Modifier
                .size(size)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.surface)
        )
        // 封面图片
        if (track.coverUrl != null) {
            AsyncImage(
                model = track.coverUrl,
                contentDescription = null,
                modifier = Modifier
                    .size(size - 20.dp)
                    .clip(CircleShape),
                contentScale = ContentScale.Crop
            )
        } else {
            Box(
                modifier = Modifier
                    .size(size - 20.dp)
                    .clip(CircleShape)
                    .background(
                        Brush.linearGradient(
                            colors = listOf(Primary.copy(alpha = 0.4f), Primary.copy(alpha = 0.2f))
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.MusicNote,
                    contentDescription = null,
                    tint = Primary,
                    modifier = Modifier.size(size / 3)
                )
            }
        }
    }
}

@Composable
private fun LyricsContent(
    lyricsState: LyricsState,
    currentLineIndex: Int,
    lazyListState: LazyListState,
    modifier: Modifier = Modifier
) {
    Box(modifier = modifier) {
        if (lyricsState.isLoading) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    CircularProgressIndicator(
                        color = Primary,
                        modifier = Modifier.size(26.dp)
                    )
                    Spacer(modifier = Modifier.height(Dimens.spacingMd))
                    Text(
                        text = "加载歌词中...",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        } else if (lyricsState.parsedLyrics.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        imageVector = Icons.Default.MusicNote,
                        contentDescription = null,
                        modifier = Modifier.size(48.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f)
                    )
                    Spacer(modifier = Modifier.height(Dimens.spacingMd))
                    Text(
                        text = "暂无歌词",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
                    )
                }
            }
        } else {
            LazyColumn(
                state = lazyListState,
                modifier = Modifier.fillMaxSize(),
                horizontalAlignment = Alignment.CenterHorizontally,
                contentPadding = PaddingValues(vertical = Dimens.spacingXxl)
            ) {
                // 顶部留白，用于滚动到居中
                item { Spacer(modifier = Modifier.height(150.dp)) }

                items(lyricsState.parsedLyrics.size) { index ->
                    val lyricLine = lyricsState.parsedLyrics[index]
                    val isCurrentLine = index == currentLineIndex

                    Text(
                        text = lyricLine.text,
                        style = if (isCurrentLine) {
                            MaterialTheme.typography.titleMedium.copy(
                                fontWeight = FontWeight.Bold,
                                letterSpacing = 0.5.sp
                            )
                        } else {
                            MaterialTheme.typography.bodyLarge.copy(
                                letterSpacing = 0.3.sp
                            )
                        },
                        color = if (isCurrentLine) {
                            Primary
                        } else {
                            MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f)
                        },
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = Dimens.spacingSm)
                            .graphicsLayer {
                                alpha = if (isCurrentLine) 1f else 0.6f
                                scaleX = if (isCurrentLine) 1.05f else 1f
                                scaleY = if (isCurrentLine) 1.05f else 1f
                            }
                    )
                }

                // 底部留白，用于滚动到居中
                item { Spacer(modifier = Modifier.height(150.dp)) }
            }
        }
    }
}

@Composable
private fun PlayerControls(
    isPlaying: Boolean,
    position: Long,
    duration: Long,
    onPlayPause: () -> Unit,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
    onSeek: (Long) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier) {
        // 进度条
        if (duration > 0) {
            val progress = if (duration > 0) (position.toFloat() / duration.toFloat()).coerceIn(0f, 1f) else 0f

            Column {
                Slider(
                    value = progress,
                    onValueChange = { newValue ->
                        onSeek((newValue * duration).toLong())
                    },
                    modifier = Modifier.fillMaxWidth(),
                    thumb = {
                        Box(modifier = Modifier.size(1.dp))
                    },
                    track = { sliderState ->
                        val fraction = sliderState.value.coerceIn(0f, 1f)
                        Box(modifier = Modifier.fillMaxWidth()) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(4.dp)
                                    .align(Alignment.Center)
                                    .clip(RoundedCornerShape(2.dp))
                                    .background(MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.2f))
                            )
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth(fraction = fraction)
                                    .height(4.dp)
                                    .align(Alignment.CenterStart)
                                    .clip(RoundedCornerShape(2.dp))
                                    .background(Primary)
                            )
                        }
                    },
                    colors = SliderDefaults.colors(
                        thumbColor = Color.Transparent,
                        activeTrackColor = Color.Transparent,
                        inactiveTrackColor = Color.Transparent
                    )
                )
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

        Spacer(modifier = Modifier.height(Dimens.spacingSm))

        // 播放控制按钮
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onPrevious) {
                Icon(
                    imageVector = Icons.Default.SkipPrevious,
                    contentDescription = stringResource(R.string.previous),
                    tint = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.size(26.dp)
                )
            }

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
                    tint = Color.White,
                    modifier = Modifier.size(22.dp)
                )
            }

            IconButton(onClick = onNext) {
                Icon(
                    imageVector = Icons.Default.SkipNext,
                    contentDescription = stringResource(R.string.next),
                    tint = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.size(26.dp)
                )
            }
        }
    }
}
