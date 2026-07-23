package com.fryfrog.hub.ui.music

import android.app.Application
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.AlbumGroup
import com.fryfrog.hub.data.model.MusicTrack
import com.fryfrog.hub.data.remote.ApiClient
import com.fryfrog.hub.data.repository.MediaRepository
import com.fryfrog.hub.service.MusicService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class MusicUiState(
    val isLoading: Boolean = true,
    val albumGroups: List<AlbumGroup> = emptyList(),
    val recentlyAdded: List<MusicTrack> = emptyList(),
    val error: String? = null
)

data class MusicPlaybackState(
    val isPlaying: Boolean = false,
    val currentTrack: MusicTrack? = null,
    val currentPosition: Long = 0L,
    val duration: Long = 0L
)

data class LyricsState(
    val isLoading: Boolean = false,
    val lyrics: String? = null,
    val parsedLyrics: List<LyricLine> = emptyList(),
    val error: String? = null
)

data class LyricLine(
    val timeMs: Long,
    val text: String
)

class MusicViewModel(application: Application) : AndroidViewModel(application) {

    private val repository = MediaRepository()
    private var musicService: MusicService? = null
    private var isServiceBound = false

    private val _uiState = MutableStateFlow(MusicUiState())
    val uiState: StateFlow<MusicUiState> = _uiState.asStateFlow()

    private val _playbackState = MutableStateFlow(MusicPlaybackState())
    val playbackState: StateFlow<MusicPlaybackState> = _playbackState.asStateFlow()

    private val _lyricsState = MutableStateFlow(LyricsState())
    val lyricsState: StateFlow<LyricsState> = _lyricsState.asStateFlow()

    // 接收下一曲/上一曲广播
    private val nextReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            playNext()
        }
    }

    private val previousReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            playPrevious()
        }
    }

    init {
        loadMusic()
        registerReceivers()
    }

    private fun startMusicService() {
        // 不在这里启动前台服务，而是在实际播放音乐时启动
        // 这样可以避免 ForegroundServiceDidNotStartInTimeException
    }

    private fun registerReceivers() {
        val context = getApplication<Application>()
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(nextReceiver, IntentFilter("com.fryfrog.hub.ACTION_PLAY_NEXT"), android.content.Context.RECEIVER_NOT_EXPORTED)
            context.registerReceiver(previousReceiver, IntentFilter("com.fryfrog.hub.ACTION_PLAY_PREVIOUS"), android.content.Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(nextReceiver, IntentFilter("com.fryfrog.hub.ACTION_PLAY_NEXT"))
            context.registerReceiver(previousReceiver, IntentFilter("com.fryfrog.hub.ACTION_PLAY_PREVIOUS"))
        }
    }

    fun setMusicService(service: MusicService) {
        musicService = service
        isServiceBound = true
        
        // 同步服务状态
        viewModelScope.launch {
            service.currentTrack.collect { track ->
                track?.let {
                    _playbackState.value = _playbackState.value.copy(
                        currentTrack = MusicTrack(
                            id = it.id,
                            title = it.title,
                            artist = it.artist,
                            album = null,
                            duration = null,
                            filePath = null,
                            coverUrl = it.coverUrl,
                            trackNumber = null,
                            year = null,
                            genre = null,
                            favorite = null
                        )
                    )
                }
            }
        }

        viewModelScope.launch {
            service.isPlaying.collect { playing ->
                _playbackState.value = _playbackState.value.copy(isPlaying = playing)
            }
        }

        viewModelScope.launch {
            service.position.collect { pos ->
                _playbackState.value = _playbackState.value.copy(currentPosition = pos)
            }
        }

        viewModelScope.launch {
            service.duration.collect { dur ->
                _playbackState.value = _playbackState.value.copy(duration = dur)
            }
        }
    }

    fun loadMusic() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            val albumsResult = repository.getMusicByAlbum()
            val recentlyResult = repository.getRecentlyAddedMusic()

            _uiState.value = MusicUiState(
                isLoading = false,
                albumGroups = albumsResult.getOrElse { emptyList() },
                recentlyAdded = recentlyResult.getOrElse { emptyList() },
                error = albumsResult.exceptionOrNull()?.message
                    ?: recentlyResult.exceptionOrNull()?.message
            )
        }
    }

    fun playTrack(track: MusicTrack) {
        // 启动前台服务
        val context = getApplication<Application>()
        val intent = Intent(context, MusicService::class.java)
        context.startForegroundService(intent)
        
        // 绑定服务
        context.bindService(intent, object : android.content.ServiceConnection {
            override fun onServiceConnected(name: android.content.ComponentName?, service: android.os.IBinder?) {
                val binder = service as? MusicService.MusicBinder
                binder?.getService()?.let { musicService ->
                    setMusicService(musicService)
                    musicService.playTrack(track.id, track.title, track.artist, track.coverUrl)
                }
            }

            override fun onServiceDisconnected(name: android.content.ComponentName?) {
                musicService = null
            }
        }, android.content.Context.BIND_AUTO_CREATE)
        
        _playbackState.value = _playbackState.value.copy(
            currentTrack = track,
            isPlaying = true
        )
    }

    fun playPrevious() {
        val allTracks = _uiState.value.albumGroups.flatMap { it.tracks ?: emptyList() }
        val currentIndex = allTracks.indexOfFirst { it.id == _playbackState.value.currentTrack?.id }
        if (currentIndex > 0) {
            playTrack(allTracks[currentIndex - 1])
        } else if (allTracks.isNotEmpty()) {
            playTrack(allTracks.last())
        }
    }

    fun playNext() {
        val allTracks = _uiState.value.albumGroups.flatMap { it.tracks ?: emptyList() }
        val currentIndex = allTracks.indexOfFirst { it.id == _playbackState.value.currentTrack?.id }
        if (currentIndex < allTracks.size - 1) {
            playTrack(allTracks[currentIndex + 1])
        } else if (allTracks.isNotEmpty()) {
            playTrack(allTracks.first())
        }
    }

    fun togglePlayPause() {
        musicService?.togglePlayPause()
    }

    fun seekTo(position: Long) {
        musicService?.seekTo(position)
    }

    fun updateProgress() {
        musicService?.updateProgress()
    }

    fun loadLyrics(trackId: Long) {
        viewModelScope.launch {
            _lyricsState.value = LyricsState(isLoading = true)
            try {
                // 优先使用内嵌歌词（从音频文件元数据中提取）
                val embeddedResult = repository.getMusicEmbeddedLyrics(trackId)
                var lyrics: String? = null

                embeddedResult.fold(
                    onSuccess = { embeddedLyrics ->
                        if (!embeddedLyrics.isNullOrBlank()) {
                            lyrics = embeddedLyrics
                        }
                    },
                    onFailure = { /* 忽略错误，继续尝试外挂歌词 */ }
                )

                // 如果没有内嵌歌词，使用外挂歌词（.lrc文件）
                if (lyrics == null) {
                    val externalResult = repository.getMusicExternalLyrics(trackId)
                    externalResult.fold(
                        onSuccess = { externalLyrics ->
                            lyrics = externalLyrics
                        },
                        onFailure = { /* 忽略错误 */ }
                    )
                }

                val parsedLyrics = parseLrcLyrics(lyrics)
                _lyricsState.value = LyricsState(
                    isLoading = false,
                    lyrics = lyrics,
                    parsedLyrics = parsedLyrics
                )
            } catch (e: Exception) {
                _lyricsState.value = LyricsState(
                    isLoading = false,
                    lyrics = null,
                    parsedLyrics = emptyList(),
                    error = null
                )
            }
        }
    }

    private fun parseLrcLyrics(lrcContent: String?): List<LyricLine> {
        if (lrcContent.isNullOrBlank()) return emptyList()

        val lyrics = mutableListOf<LyricLine>()
        val regex = Regex("""\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)""")

        lrcContent.lines().forEach { line ->
            regex.find(line)?.let { match ->
                val minutes = match.groupValues[1].toLongOrNull() ?: 0L
                val seconds = match.groupValues[2].toLongOrNull() ?: 0L
                val millisStr = match.groupValues[3]
                val millis = if (millisStr.length == 2) {
                    millisStr.toLongOrNull()?.times(10) ?: 0L
                } else {
                    millisStr.toLongOrNull() ?: 0L
                }
                val timeMs = minutes * 60 * 1000 + seconds * 1000 + millis
                val text = match.groupValues[4].trim()
                if (text.isNotEmpty()) {
                    lyrics.add(LyricLine(timeMs, text))
                }
            }
        }

        return lyrics.sortedBy { it.timeMs }
    }

    override fun onCleared() {
        super.onCleared()
        try {
            val context = getApplication<Application>()
            context.unregisterReceiver(nextReceiver)
            context.unregisterReceiver(previousReceiver)
        } catch (e: Exception) {
            // Receiver already unregistered
        }
    }
}

class MusicViewModelFactory(private val application: Application) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        return MusicViewModel(application) as T
    }
}
