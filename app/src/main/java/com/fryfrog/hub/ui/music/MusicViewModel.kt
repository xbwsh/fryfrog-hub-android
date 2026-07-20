package com.fryfrog.hub.ui.music

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.AlbumGroup
import com.fryfrog.hub.data.model.MusicTrack
import com.fryfrog.hub.data.remote.ApiClient
import com.fryfrog.hub.data.repository.MediaRepository
import com.fryfrog.hub.player.MusicPlayer
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

class MusicViewModel(application: Application) : AndroidViewModel(application) {

    private val repository = MediaRepository()
    private var musicPlayer: MusicPlayer? = null

    private val _uiState = MutableStateFlow(MusicUiState())
    val uiState: StateFlow<MusicUiState> = _uiState.asStateFlow()

    private val _playbackState = MutableStateFlow(MusicPlaybackState())
    val playbackState: StateFlow<MusicPlaybackState> = _playbackState.asStateFlow()

    init {
        loadMusic()
        initPlayer()
    }

    private fun initPlayer() {
        musicPlayer = MusicPlayer(getApplication()).apply {
            setOnEventListener { eventType ->
                when (eventType) {
                    MusicPlayer.EVENT_PLAYING -> {
                        _playbackState.value = _playbackState.value.copy(isPlaying = true)
                    }
                    MusicPlayer.EVENT_PAUSED -> {
                        _playbackState.value = _playbackState.value.copy(isPlaying = false)
                    }
                    MusicPlayer.EVENT_END_REACHED -> {
                        _playbackState.value = _playbackState.value.copy(isPlaying = false)
                    }
                }
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
        val url = "${ApiClient.getBaseUrl()}/api/v1/music/${track.id}/stream"
        musicPlayer?.play(url)
        _playbackState.value = _playbackState.value.copy(
            currentTrack = track,
            isPlaying = true
        )
    }

    fun togglePlayPause() {
        musicPlayer?.togglePlayPause()
    }

    fun seekTo(position: Long) {
        musicPlayer?.seekTo(position)
    }

    fun updateProgress() {
        musicPlayer?.let { player ->
            _playbackState.value = _playbackState.value.copy(
                currentPosition = player.getPosition(),
                duration = player.getDuration()
            )
        }
    }

    override fun onCleared() {
        super.onCleared()
        musicPlayer?.release()
        musicPlayer = null
    }
}

class MusicViewModelFactory(private val application: Application) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        return MusicViewModel(application) as T
    }
}
