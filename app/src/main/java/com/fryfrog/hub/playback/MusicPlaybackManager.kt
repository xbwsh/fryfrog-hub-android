package com.fryfrog.hub.playback

import android.content.ComponentName
import android.content.Context
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.fryfrog.hub.data.repository.MusicRepository
import com.fryfrog.hub.data.model.MusicSongDTO
import com.google.common.util.concurrent.MoreExecutors
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * 音乐播放单例：UI 通过它操作 MediaController。
 * - 播放/暂停/上下曲/跳转
 * - 队列状态流供迷你条与全屏播放器共享
 * - scrobble：切歌上报"正在播放"，播放超 90% 上报一次"提交"
 * - 播放队列变更防抖持久化到后端 play-queue
 */
object MusicPlaybackManager {

    data class PlaybackUiState(
        val songs: List<MusicSongDTO> = emptyList(),
        val currentIndex: Int = -1,
        val currentSong: MusicSongDTO? = null,
        val isPlaying: Boolean = false,
        val isLoading: Boolean = false,
        val positionMs: Long = 0L,
        val durationMs: Long = 0L
    ) {
        val hasQueue: Boolean get() = songs.isNotEmpty()
    }

    private val _state = MutableStateFlow(PlaybackUiState())
    val state: StateFlow<PlaybackUiState> = _state.asStateFlow()

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private var controller: MediaController? = null
    private var connecting = false
    private var positionTicker: Job? = null
    private var saveQueueJob: Job? = null

    // scrobble 去重：每首歌每次播放只提交一次
    private var scrobbledSongId: Long = -1
    private var lastSongId: Long = -1

    /** 应用启动后调用一次；重复调用安全 */
    @androidx.annotation.OptIn(androidx.media3.common.util.UnstableApi::class)
    fun connect(context: Context) {
        if (controller != null || connecting) return
        connecting = true
        val appContext = context.applicationContext
        val token = SessionToken(appContext, ComponentName(appContext, MusicPlaybackService::class.java))
        val future = MediaController.Builder(appContext, token).buildAsync()
        future.addListener({
            try {
                controller = future.get()
                attachListener()
                startPositionTicker()
                _state.update { it.copy(isLoading = false) }
            } catch (e: Exception) {
                android.util.Log.e("MusicPlaybackManager", "MediaController connect failed", e)
            } finally {
                connecting = false
            }
        }, MoreExecutors.directExecutor())
    }

    private fun submitScrobble(songId: Long, submission: Boolean) {
        scope.launch(Dispatchers.IO) {
            MusicRepository().scrobble(songId, submission)
        }
    }

    private fun attachListener() {
        val player = controller ?: return
        player.addListener(object : Player.Listener {
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                _state.update { it.copy(isPlaying = isPlaying) }
            }

            override fun onIsLoadingChanged(isLoading: Boolean) {
                _state.update { it.copy(isLoading = isLoading) }
            }

            override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
                refreshCurrentIndex()
                // 切歌：上一曲补提交 scrobble，当前曲上报"正在播放"
                val previousId = lastSongId
                if (previousId > 0 && previousId != scrobbledSongId) {
                    submitScrobble(previousId, submission = true)
                }
                lastSongId.takeIf { it > 0 }?.let { submitScrobble(it, submission = false) }
                scheduleSaveQueue()
            }

            override fun onPlaybackStateChanged(playbackState: Int) {
                if (playbackState == Player.STATE_ENDED) {
                    val id = _state.value.currentSong?.id ?: -1
                    if (id > 0 && id != scrobbledSongId) {
                        scrobbledSongId = id
                        submitScrobble(id, submission = true)
                    }
                }
                syncDuration()
            }
        })
        refreshCurrentIndex()
        syncDuration()
    }

    private fun startPositionTicker() {
        positionTicker?.cancel()
        positionTicker = scope.launch {
            while (isActive) {
                val player = controller
                if (player != null) {
                    _state.update {
                        it.copy(
                            positionMs = player.currentPosition.coerceAtLeast(0L),
                            durationMs = if (player.duration > 0) player.duration else it.durationMs
                        )
                    }
                    // 播放进度超过 90% 且未提交 → 提交 scrobble
                    val song = _state.value.currentSong
                    val duration = player.duration
                    if (song != null && player.isPlaying && duration > 0 &&
                        song.id != scrobbledSongId &&
                        player.currentPosition >= duration * SCROBBLE_THRESHOLD
                    ) {
                        scrobbledSongId = song.id
                        submitScrobble(song.id, submission = true)
                    }
                }
                delay(POSITION_POLL_MS)
            }
        }
    }

    private fun refreshCurrentIndex() {
        val player = controller ?: return
        val index = player.currentMediaItemIndex
        val songs = _state.value.songs
        val song = songs.getOrNull(index)
        _state.update { it.copy(currentIndex = index, currentSong = song) }
        lastSongId = song?.id ?: -1
    }

    private fun syncDuration() {
        val player = controller ?: return
        val duration = player.duration
        if (duration > 0) {
            _state.update { it.copy(durationMs = duration) }
        }
    }

    // ===== 对外控制 =====

    /**
     * 播放一组歌曲。songs 内 streamUrl 应为刚刷新过的预签名地址。
     */
    fun playSongs(songs: List<MusicSongDTO>, startIndex: Int = 0, startPositionMs: Long = 0L) {
        val player = controller ?: return
        if (songs.isEmpty()) return
        val items = songs.map { it.toMediaItem() }
        player.setMediaItems(items, startIndex.coerceIn(0, songs.lastIndex), startPositionMs)
        player.prepare()
        player.play()
        scrobbledSongId = -1
        _state.update { it.copy(songs = songs, currentIndex = startIndex, currentSong = songs[startIndex]) }
        lastSongId = songs[startIndex].id
        scheduleSaveQueue()
    }

    /** 追加到队尾 */
    fun addToQueue(songs: List<MusicSongDTO>) {
        val player = controller ?: return
        if (songs.isEmpty()) return
        player.addMediaItems(songs.map { it.toMediaItem() })
        _state.update { it.copy(songs = it.songs + songs) }
        scheduleSaveQueue()
    }

    /** 若目标歌曲已在队列则跳转，否则替换整个队列播放 */
    fun playOrSeek(song: MusicSongDTO, queue: List<MusicSongDTO>) {
        val existingIndex = _state.value.songs.indexOfFirst { it.id == song.id }
        if (existingIndex >= 0 && controller != null) {
            seekToIndex(existingIndex)
        } else {
            playSongs(queue, queue.indexOfFirst { it.id == song.id }.coerceAtLeast(0))
        }
    }

    fun togglePlayPause() {
        val player = controller ?: return
        if (player.isPlaying) player.pause() else player.play()
    }

    fun seekNext(): Boolean {
        val player = controller ?: return false
        return if (player.hasNextMediaItem()) {
            player.seekToNextMediaItem()
            player.play()
            true
        } else false
    }

    fun seekPrevious(): Boolean {
        val player = controller ?: return false
        return if (player.hasPreviousMediaItem()) {
            player.seekToPreviousMediaItem()
            player.play()
            true
        } else false
    }

    fun seekTo(positionMs: Long) {
        controller?.seekTo(positionMs)
        scheduleSaveQueue()
    }

    fun seekToIndex(index: Int, positionMs: Long = 0L) {
        controller?.seekTo(index, positionMs)
        controller?.play()
    }

    /** 停止并清空（登出时） */
    fun stopAndClear() {
        controller?.run {
            stop()
            clearMediaItems()
        }
        _state.value = PlaybackUiState()
        scrobbledSongId = -1
        lastSongId = -1
    }

    // ===== 本地状态同步（收藏/评分乐观更新） =====

    fun updateCurrentSong(transform: (MusicSongDTO) -> MusicSongDTO) {
        _state.update { st ->
            val idx = st.currentIndex
            if (idx < 0 || idx >= st.songs.size) st
            else {
                val newSongs = st.songs.toMutableList()
                newSongs[idx] = transform(newSongs[idx])
                st.copy(songs = newSongs, currentSong = newSongs[idx])
            }
        }
    }

    // ===== 播放队列持久化 =====

    private fun scheduleSaveQueue() {
        saveQueueJob?.cancel()
        saveQueueJob = scope.launch {
            delay(SAVE_QUEUE_DEBOUNCE_MS)
            persistQueue()
        }
    }

    private suspend fun persistQueue() {
        val st = _state.value
        if (st.songs.isEmpty()) return
        MusicRepository().savePlayQueue(
            songIds = st.songs.map { it.id },
            currentSongId = st.currentSong?.id,
            positionSeconds = st.positionMs / 1000.0
        )
    }

    private fun MusicSongDTO.toMediaItem(): MediaItem = MediaItem.Builder()
        .setUri(streamUrl)
        .setMediaId(id.toString())
        .setMediaMetadata(
            MediaMetadata.Builder()
                .setTitle(title)
                .setArtist(artistName)
                .setAlbumTitle(albumName)
                .build()
        )
        .build()

    private const val POSITION_POLL_MS = 500L
    private const val SCROBBLE_THRESHOLD = 0.9
    private const val SAVE_QUEUE_DEBOUNCE_MS = 2000L
}
