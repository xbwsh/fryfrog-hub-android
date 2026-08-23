package com.fryfrog.hub.ui.music

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BookmarkAdd
import androidx.compose.material.icons.filled.BookmarkRemove
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.QueueMusic
import androidx.compose.material.icons.filled.SkipNext
import androidx.compose.material.icons.filled.SkipPrevious
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.MusicBookmark
import com.fryfrog.hub.data.repository.MusicRepository
import com.fryfrog.hub.playback.MusicPlaybackManager
import com.fryfrog.hub.ui.theme.Dimens
import com.fryfrog.hub.ui.theme.Gold
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

// ==================== ViewModel ====================

data class MusicPlayerUiState(
    // 歌词
    val lyricLines: List<LyricLine> = emptyList(),
    val lyricsLoaded: Boolean = false,
    val lyricsAvailable: Boolean = false,
    // 书签（当前歌曲）
    val bookmark: MusicBookmark? = null,
    val notice: String? = null
)

class MusicPlayerViewModel : ViewModel() {

    private val repository = MusicRepository()

    private val _uiState = MutableStateFlow(MusicPlayerUiState())
    val uiState: StateFlow<MusicPlayerUiState> = _uiState.asStateFlow()

    private var loadedSongId: Long = -1

    /** 当前歌曲变化：刷新详情（预签名 URL/收藏状态）+ 歌词 + 书签 */
    fun onSongChanged(songId: Long?) {
        if (songId == null || songId == loadedSongId) return
        loadedSongId = songId
        _uiState.update {
            it.copy(lyricLines = emptyList(), lyricsLoaded = false, lyricsAvailable = false, bookmark = null)
        }

        viewModelScope.launch {
            // 详情刷新（乐观合并，不打断播放）
            repository.getSong(songId).onSuccess { fresh ->
                if (loadedSongId == songId) {
                    MusicPlaybackManager.updateCurrentSong { current ->
                        current.copy(
                            title = fresh.title,
                            artistName = fresh.artistName,
                            albumName = fresh.albumName,
                            coverUrl = fresh.coverUrl ?: current.coverUrl,
                            starred = fresh.starred,
                            rating = fresh.rating,
                            playCount = fresh.playCount
                        )
                    }
                }
            }
        }

        viewModelScope.launch {
            val raw = repository.getLyrics(songId).getOrNull().orEmpty()
            val lines = LyricsParser.parse(raw)
            _uiState.update {
                it.copy(
                    lyricLines = lines,
                    lyricsLoaded = true,
                    lyricsAvailable = lines.isNotEmpty()
                )
            }
        }

        viewModelScope.launch {
            val bookmark = repository.getBookmarks().getOrNull()
                ?.firstOrNull { it.songId == songId }
            _uiState.update { it.copy(bookmark = bookmark) }
        }
    }

    fun toggleStar() {
        val song = MusicPlaybackManager.state.value.currentSong ?: return
        val newStatus = !(song.starred ?: false)
        MusicPlaybackManager.updateCurrentSong { it.copy(starred = newStatus) }
        viewModelScope.launch {
            repository.setStar("songs", song.id, newStatus)
        }
    }

    fun setRating(rating: Int) {
        val song = MusicPlaybackManager.state.value.currentSong ?: return
        MusicPlaybackManager.updateCurrentSong { it.copy(rating = rating) }
        viewModelScope.launch {
            repository.setRating("songs", song.id, rating)
        }
    }

    fun addBookmarkAt(positionSeconds: Double) {
        val song = MusicPlaybackManager.state.value.currentSong ?: return
        viewModelScope.launch {
            repository.createBookmark(song.id, positionSeconds).fold(
                onSuccess = { bookmark ->
                    _uiState.update { it.copy(bookmark = bookmark, notice = null) }
                },
                onFailure = { e -> _uiState.update { it.copy(notice = e.message ?: "") } }
            )
        }
    }

    fun deleteBookmark() {
        val song = MusicPlaybackManager.state.value.currentSong ?: return
        viewModelScope.launch {
            repository.deleteBookmark(song.id).fold(
                onSuccess = { _uiState.update { it.copy(bookmark = null) } },
                onFailure = { e -> _uiState.update { it.copy(notice = e.message ?: "") } }
            )
        }
    }

    fun clearNotice() {
        _uiState.update { it.copy(notice = null) }
    }
}

// ==================== Screen ====================

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MusicPlayerScreen(
    onBackClick: () -> Unit,
    viewModel: MusicPlayerViewModel = viewModel()
) {
    val playbackState by MusicPlaybackManager.state.collectAsState()
    val uiState by viewModel.uiState.collectAsState()

    val song = playbackState.currentSong
    var showLyrics by remember { mutableStateOf(false) }
    var showQueue by remember { mutableStateOf(false) }

    // 切歌联动
    LaunchedEffect(song?.id) {
        viewModel.onSongChanged(song?.id)
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        MaterialTheme.colorScheme.surfaceVariant,
                        MaterialTheme.colorScheme.surface,
                        MaterialTheme.colorScheme.background
                    )
                )
            )
            .statusBarsPadding()
            .navigationBarsPadding()
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = Dimens.spacingXxl),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // 顶部栏
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onBackClick) {
                    Icon(Icons.Default.ExpandMore, contentDescription = stringResource(R.string.back))
                }
                Text(
                    text = stringResource(R.string.music_now_playing),
                    style = MaterialTheme.typography.titleSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.weight(1f),
                    textAlign = TextAlign.Center
                )
                IconButton(onClick = { showQueue = true }) {
                    Icon(Icons.Default.QueueMusic, contentDescription = stringResource(R.string.music_queue))
                }
            }

            if (song == null) {
                // 空态：尚未开始播放
                Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                    Text(
                        text = stringResource(R.string.music_nothing_playing),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else {
                // 封面 / 歌词
                val activeLine = LyricsParser.activeIndex(uiState.lyricLines, playbackState.positionMs)
                val listState = rememberLazyListState()
                LaunchedEffect(activeLine) {
                    if (showLyrics && activeLine >= 0 && uiState.lyricLines.isNotEmpty()) {
                        listState.animateScrollToItem((activeLine - 2).coerceAtLeast(0))
                    }
                }

                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(Dimens.radiusXl))
                        .clickable { showLyrics = !showLyrics },
                    contentAlignment = Alignment.Center
                ) {
                    if (showLyrics && uiState.lyricsAvailable) {
                        LazyColumn(
                            state = listState,
                            modifier = Modifier.fillMaxSize().padding(vertical = Dimens.spacingXxl),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            items(uiState.lyricLines.size) { index ->
                                val line = uiState.lyricLines[index]
                                val isActive = index == activeLine
                                Text(
                                    text = line.text,
                                    style = if (isActive) MaterialTheme.typography.titleMedium else MaterialTheme.typography.bodyLarge,
                                    fontWeight = if (isActive) FontWeight.SemiBold else FontWeight.Normal,
                                    color = if (isActive) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f),
                                    textAlign = TextAlign.Center,
                                    maxLines = 2,
                                    overflow = TextOverflow.Ellipsis,
                                    modifier = Modifier.padding(
                                        horizontal = Dimens.spacingMd,
                                        vertical = Dimens.spacingSm
                                    )
                                )
                            }
                        }
                    } else {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            MusicCover(
                                url = song.coverUrl,
                                modifier = Modifier.size(Dimens.carouselHeight * 0.85f),
                                shape = RoundedCornerShape(Dimens.radiusXl)
                            )
                            if (!uiState.lyricsAvailable && uiState.lyricsLoaded && showLyrics) {
                                Spacer(Modifier.height(Dimens.spacingLg))
                                Text(
                                    text = stringResource(R.string.music_no_lyrics),
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }

                Spacer(Modifier.height(Dimens.spacingLg))

                // 标题区 + 收藏
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = song.displayTitle,
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.SemiBold,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        Spacer(Modifier.height(Dimens.spacingXxs))
                        Text(
                            text = listOfNotNull(
                                song.displayArtist.takeIf { it.isNotBlank() },
                                song.albumName?.takeIf { it.isNotBlank() }
                            ).joinToString(" · ").ifBlank { stringResource(R.string.unknown) },
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                    StarButton(starred = song.starred == true, onToggle = viewModel::toggleStar)
                }

                Spacer(Modifier.height(Dimens.spacingXxs))

                // 评分
                RatingStars(rating = song.rating, onRate = viewModel::setRating)

                Spacer(Modifier.height(Dimens.spacingSm))

                // 进度条
                Slider(
                    value = if (playbackState.durationMs > 0) {
                        playbackState.positionMs.toFloat() / playbackState.durationMs
                    } else 0f,
                    onValueChange = { fraction ->
                        if (playbackState.durationMs > 0) {
                            MusicPlaybackManager.seekTo((fraction * playbackState.durationMs).toLong())
                        }
                    },
                    modifier = Modifier.fillMaxWidth()
                )
                Row(modifier = Modifier.fillMaxWidth()) {
                    Text(
                        text = formatDurationMs(playbackState.positionMs),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(Modifier.weight(1f))
                    Text(
                        text = formatDurationMs(playbackState.durationMs),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                Spacer(Modifier.height(Dimens.spacingSm))

                // 控制按钮
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(onClick = { MusicPlaybackManager.seekPrevious() }) {
                        Icon(
                            Icons.Default.SkipPrevious,
                            contentDescription = stringResource(R.string.previous),
                            modifier = Modifier.size(Dimens.avatarSize * 2)
                        )
                    }
                    Spacer(Modifier.width(Dimens.spacingLg))
                    Surface(
                        shape = CircleShape,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(Dimens.carouselHeight / 3)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            IconButton(onClick = MusicPlaybackManager::togglePlayPause) {
                                Icon(
                                    imageVector = if (playbackState.isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                                    contentDescription = stringResource(if (playbackState.isPlaying) R.string.pause else R.string.play),
                                    tint = MaterialTheme.colorScheme.onPrimary,
                                    modifier = Modifier.size(Dimens.carouselHeight / 6)
                                )
                            }
                        }
                    }
                    Spacer(Modifier.width(Dimens.spacingLg))
                    IconButton(onClick = { MusicPlaybackManager.seekNext() }) {
                        Icon(
                            Icons.Default.SkipNext,
                            contentDescription = stringResource(R.string.next),
                            modifier = Modifier.size(Dimens.avatarSize * 2)
                        )
                    }
                }

                Spacer(Modifier.height(Dimens.spacingMd))

                // 书签行
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center
                ) {
                    val bookmark = uiState.bookmark
                    if (bookmark != null) {
                        Surface(
                            shape = RoundedCornerShape(Dimens.radiusFull),
                            color = MaterialTheme.colorScheme.secondaryContainer,
                            modifier = Modifier.clickable {
                                MusicPlaybackManager.seekTo(bookmark.positionMs)
                            }
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = Dimens.spacingMd, vertical = Dimens.spacingXs),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    Icons.Default.BookmarkRemove,
                                    contentDescription = stringResource(R.string.music_delete_bookmark),
                                    tint = MaterialTheme.colorScheme.onSecondaryContainer,
                                    modifier = Modifier.size(Dimens.smallIconSize)
                                )
                                Spacer(Modifier.width(Dimens.spacingXs))
                                Text(
                                    text = formatDuration(bookmark.positionSeconds),
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.onSecondaryContainer
                                )
                            }
                        }
                        Spacer(Modifier.width(Dimens.spacingMd))
                        IconButton(onClick = viewModel::deleteBookmark) {
                            Icon(
                                Icons.Default.Close,
                                contentDescription = stringResource(R.string.delete),
                                tint = MaterialTheme.colorScheme.error,
                                modifier = Modifier.size(Dimens.iconSize)
                            )
                        }
                    } else {
                        IconButton(onClick = {
                            viewModel.addBookmarkAt(playbackState.positionMs / 1000.0)
                        }) {
                            Icon(
                                Icons.Default.BookmarkAdd,
                                contentDescription = stringResource(R.string.music_add_bookmark),
                                tint = Gold,
                                modifier = Modifier.size(Dimens.dialogIconSize)
                            )
                        }
                    }
                }

                Spacer(Modifier.height(Dimens.bottomNavReserve / 2))
            }
        }
    }

    // 播放队列底部弹层
    if (showQueue) {
        ModalBottomSheet(onDismissRequest = { showQueue = false }) {
            QueueSheetContent(
                songs = playbackState.songs,
                currentIndex = playbackState.currentIndex,
                onSelect = { index ->
                    MusicPlaybackManager.seekToIndex(index)
                }
            )
        }
    }
}

@Composable
private fun QueueSheetContent(
    songs: List<com.fryfrog.hub.data.model.MusicSongDTO>,
    currentIndex: Int,
    onSelect: (Int) -> Unit
) {
    Text(
        text = stringResource(R.string.music_queue_count, songs.size),
        style = MaterialTheme.typography.titleSmall,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier.padding(horizontal = Dimens.spacingXxl, vertical = Dimens.spacingMd)
    )
    LazyColumn(
        modifier = Modifier.fillMaxWidth(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = Dimens.bottomNavReserve * 2)
    ) {
        itemsIndexed(songs) { index, item ->
            SongRow(
                song = item,
                index = index + 1,
                isCurrent = index == currentIndex,
                onClick = { onSelect(index) }
            )
        }
    }
}
