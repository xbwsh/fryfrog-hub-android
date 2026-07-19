package com.fryfrog.hub.ui.player

import android.view.SurfaceView
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import com.fryfrog.hub.R
import com.fryfrog.hub.data.remote.ApiClient
import com.fryfrog.hub.player.ExoPlayerImpl
import com.fryfrog.hub.player.VideoPlayer
import com.fryfrog.hub.ui.theme.Dimens
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class PlayerUiState(
    val isLoading: Boolean = true,
    val isPlaying: Boolean = false,
    val currentPosition: Long = 0L,
    val duration: Long = 0L,
    val title: String = "",
    val error: String? = null
)

@OptIn(UnstableApi::class)
class PlayerViewModel(
    private val videoId: Long,
    private val title: String
) : ViewModel() {

    private val _uiState = MutableStateFlow(PlayerUiState(title = title))
    val uiState: StateFlow<PlayerUiState> = _uiState.asStateFlow()

    private var videoPlayer: VideoPlayer? = null

    fun initializePlayer(surfaceView: SurfaceView) {
        val player = ExoPlayerImpl()
        videoPlayer = player
        player.initialize(surfaceView.context, surfaceView)

        player.player?.addListener(object : Player.Listener {
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                _uiState.value = _uiState.value.copy(isPlaying = isPlaying)
            }

            override fun onPlaybackStateChanged(playbackState: Int) {
                when (playbackState) {
                    Player.STATE_READY -> {
                        _uiState.value = _uiState.value.copy(
                            isLoading = false,
                            duration = player.getDuration()
                        )
                    }
                    Player.STATE_ENDED -> {
                        _uiState.value = _uiState.value.copy(isPlaying = false)
                    }
                    Player.STATE_BUFFERING -> {
                        _uiState.value = _uiState.value.copy(isLoading = true)
                    }
                    Player.STATE_IDLE -> {}
                }
            }

            override fun onPlayerError(error: androidx.media3.common.PlaybackException) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = error.message
                )
            }
        })

        val streamUrl = "${ApiClient.getBaseUrl()}/api/v1/video/$videoId/stream"
        player.play(streamUrl)
    }

    fun togglePlayPause() {
        videoPlayer?.let { player ->
            if (player.isPlaying()) {
                player.pause()
            } else {
                player.resume()
            }
        }
    }

    fun seekTo(position: Long) {
        videoPlayer?.seekTo(position)
    }

    fun updateProgress() {
        videoPlayer?.let { player ->
            _uiState.value = _uiState.value.copy(
                currentPosition = player.getCurrentPosition(),
                duration = player.getDuration()
            )
        }
    }

    fun release() {
        videoPlayer?.release()
        videoPlayer = null
    }

    fun getPlayer(): VideoPlayer? = videoPlayer
}

class PlayerViewModelFactory(
    private val videoId: Long,
    private val title: String
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        return PlayerViewModel(videoId, title) as T
    }
}

@Composable
fun PlayerScreen(
    videoId: Long,
    title: String,
    onBackClick: () -> Unit
) {
    val viewModel: PlayerViewModel = viewModel(
        factory = PlayerViewModelFactory(videoId, title)
    )
    val uiState by viewModel.uiState.collectAsState()

    DisposableEffect(Unit) {
        onDispose {
            viewModel.release()
        }
    }

    // Progress update
    LaunchedEffect(uiState.isPlaying) {
        while (uiState.isPlaying) {
            viewModel.updateProgress()
            delay(500)
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        // Video surface
        AndroidView(
            factory = { ctx ->
                SurfaceView(ctx).apply {
                    viewModel.initializePlayer(this)
                }
            },
            modifier = Modifier.fillMaxSize()
        )

        // Controls overlay
        Column(
            modifier = Modifier.fillMaxSize()
        ) {
            // Top bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .statusBarsPadding()
                    .padding(Dimens.spacingMd),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(
                    onClick = onBackClick,
                    modifier = Modifier.background(
                        Color.Black.copy(alpha = Dimens.alphaOverlay),
                        CircleShape
                    )
                ) {
                    Icon(
                        imageVector = Icons.Default.ArrowBack,
                        contentDescription = stringResource(R.string.back),
                        tint = Color.White
                    )
                }

                Spacer(modifier = Modifier.width(Dimens.spacingMd))

                Text(
                    text = uiState.title,
                    style = MaterialTheme.typography.titleMedium,
                    color = Color.White,
                    modifier = Modifier.weight(1f)
                )
            }

            Spacer(modifier = Modifier.weight(1f))

            // Bottom controls
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .navigationBarsPadding()
                    .padding(Dimens.spacingLg)
            ) {
                // Progress bar
                if (uiState.duration > 0) {
                    Slider(
                        value = uiState.currentPosition.toFloat(),
                        valueRange = 0f..uiState.duration.toFloat(),
                        onValueChange = { viewModel.seekTo(it.toLong()) },
                        modifier = Modifier.fillMaxWidth(),
                        colors = SliderDefaults.colors(
                            thumbColor = MaterialTheme.colorScheme.primary,
                            activeTrackColor = MaterialTheme.colorScheme.primary
                        )
                    )

                    // Time display
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = formatTime(uiState.currentPosition),
                            style = MaterialTheme.typography.bodySmall,
                            color = Color.White
                        )
                        Text(
                            text = formatTime(uiState.duration),
                            style = MaterialTheme.typography.bodySmall,
                            color = Color.White
                        )
                    }
                }

                Spacer(modifier = Modifier.height(Dimens.spacingMd))

                // Play/Pause button
                Box(
                    modifier = Modifier.fillMaxWidth(),
                    contentAlignment = Alignment.Center
                ) {
                    IconButton(
                        onClick = { viewModel.togglePlayPause() },
                        modifier = Modifier
                            .size(64.dp)
                            .background(Color.White.copy(alpha = Dimens.alphaOverlay), CircleShape)
                    ) {
                        Icon(
                            imageVector = if (uiState.isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                            contentDescription = if (uiState.isPlaying) "Pause" else "Play",
                            tint = Color.White,
                            modifier = Modifier.size(36.dp)
                        )
                    }
                }
            }
        }

        // Loading indicator
        if (uiState.isLoading) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = Color.White)
            }
        }
    }
}

private fun formatTime(ms: Long): String {
    val totalSeconds = ms / 1000
    val hours = totalSeconds / 3600
    val minutes = (totalSeconds % 3600) / 60
    val seconds = totalSeconds % 60

    return if (hours > 0) {
        String.format("%d:%02d:%02d", hours, minutes, seconds)
    } else {
        String.format("%02d:%02d", minutes, seconds)
    }
}
