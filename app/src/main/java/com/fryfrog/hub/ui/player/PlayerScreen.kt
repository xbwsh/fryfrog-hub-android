package com.fryfrog.hub.ui.player

import android.app.Activity
import android.content.Context
import android.content.pm.ActivityInfo
import android.view.SurfaceHolder
import android.view.SurfaceView
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import com.fryfrog.hub.data.remote.ApiClient
import com.fryfrog.hub.player.VlcPlayer
import kotlinx.coroutines.delay

class PlayerViewModel(private val videoId: Long) : ViewModel() {

    private var player: VlcPlayer? = null
    private var _isPlaying = mutableStateOf(false)
    private var _isLoading = mutableStateOf(true)
    private var _currentPos = mutableStateOf(0L)
    private var _totalDuration = mutableStateOf(0L)
    private var hasStartedPlayback = false

    val isPlaying: Boolean by _isPlaying
    val isLoading: Boolean by _isLoading
    val currentPos: Long by _currentPos
    val totalDuration: Long by _totalDuration

    fun init(context: Context) {
        if (player == null) {
            hasStartedPlayback = false
            player = VlcPlayer(context).apply {
                setOnEventListener { eventType ->
                    when (eventType) {
                        VlcPlayer.EVENT_PLAYING -> {
                            _isPlaying.value = true
                            _isLoading.value = false
                        }
                        VlcPlayer.EVENT_PAUSED -> _isPlaying.value = false
                        VlcPlayer.EVENT_END_REACHED -> {
                            _isPlaying.value = false
                            _isLoading.value = false
                        }
                        VlcPlayer.EVENT_BUFFERING -> _isLoading.value = true
                        VlcPlayer.EVENT_ERROR -> _isLoading.value = false
                    }
                }
            }
        }
    }

    fun attachSurface(surfaceView: SurfaceView) {
        surfaceView.post {
            val w = surfaceView.width
            val h = surfaceView.height
            if (w > 0 && h > 0) {
                player?.attachSurface(surfaceView, w, h)
            }
        }
    }

    fun startPlaybackIfNeeded() {
        if (!hasStartedPlayback) {
            hasStartedPlayback = true
            val url = "${ApiClient.getBaseUrl()}/api/v1/video/$videoId/stream"
            player?.open(url)
        }
    }

    fun detachSurface() {
        player?.detachSurface()
    }

    fun togglePlayPause() {
        player?.togglePlayPause()
    }

    fun seekTo(ms: Long) {
        player?.seekTo(ms)
    }

    fun tick() {
        player?.let {
            _currentPos.value = it.getPosition()
            _totalDuration.value = it.getDuration()
        }
    }

    fun release() {
        player?.release()
        player = null
    }
}

class PlayerVMFactory(private val videoId: Long) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T = PlayerViewModel(videoId) as T
}

@Composable
fun PlayerScreen(
    videoId: Long,
    title: String,
    onBackClick: () -> Unit
) {
    val vm: PlayerViewModel = viewModel(factory = PlayerVMFactory(videoId))
    val activity = LocalContext.current as Activity
    var showControls by remember { mutableStateOf(true) }

    DisposableEffect(Unit) {
        val orig = activity.requestedOrientation
        activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR
        val window = activity.window
        WindowCompat.setDecorFitsSystemWindows(window, false)
        val ctrl = WindowInsetsControllerCompat(window, window.decorView)
        ctrl.hide(WindowInsetsCompat.Type.systemBars())
        ctrl.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        vm.init(activity)

        onDispose {
            ctrl.show(WindowInsetsCompat.Type.systemBars())
            WindowCompat.setDecorFitsSystemWindows(window, true)
            activity.requestedOrientation = orig
            vm.release()
        }
    }

    // 进度更新
    LaunchedEffect(vm.isPlaying) {
        while (vm.isPlaying) {
            vm.tick()
            delay(500)
        }
    }

    // 控件自动隐藏
    LaunchedEffect(showControls, vm.isPlaying) {
        if (showControls && vm.isPlaying) {
            delay(3000)
            showControls = false
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .clickable { showControls = !showControls }
    ) {
        // 视频 Surface
        AndroidView(
            factory = { ctx ->
                SurfaceView(ctx).apply {
                    holder.addCallback(object : SurfaceHolder.Callback {
                        override fun surfaceCreated(holder: SurfaceHolder) {
                            vm.init(ctx)
                            vm.attachSurface(this@apply)
                            vm.startPlaybackIfNeeded()
                        }
                        override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
                            vm.attachSurface(this@apply)
                        }
                        override fun surfaceDestroyed(holder: SurfaceHolder) {
                            vm.detachSurface()
                        }
                    })
                }
            },
            modifier = Modifier.fillMaxSize()
        )

        // 控件
        if (showControls) {
            // 顶栏
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color.Black.copy(alpha = 0.6f))
                    .statusBarsPadding()
                    .padding(16.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(
                        onClick = onBackClick,
                        modifier = Modifier
                            .size(40.dp)
                            .background(Color.Black.copy(alpha = 0.3f), CircleShape)
                    ) {
                        Icon(Icons.Default.ArrowBack, contentDescription = null, tint = Color.White, modifier = Modifier.size(24.dp))
                    }
                    Spacer(modifier = Modifier.width(12.dp))
                    Text(title, color = Color.White, style = MaterialTheme.typography.titleMedium, maxLines = 1)
                }
            }

            // 底栏
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .align(Alignment.BottomCenter)
                    .background(Color.Black.copy(alpha = 0.6f))
                    .navigationBarsPadding()
                    .padding(horizontal = 16.dp, vertical = 12.dp)
            ) {
                if (vm.totalDuration > 0) {
                    Slider(
                        value = vm.currentPos.toFloat(),
                        valueRange = 0f..vm.totalDuration.toFloat(),
                        onValueChange = { vm.seekTo(it.toLong()) },
                        modifier = Modifier.fillMaxWidth(),
                        colors = SliderDefaults.colors(
                            thumbColor = MaterialTheme.colorScheme.primary,
                            activeTrackColor = MaterialTheme.colorScheme.primary,
                            inactiveTrackColor = Color.White.copy(alpha = 0.3f)
                        )
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(fmtTime(vm.currentPos), color = Color.White, style = MaterialTheme.typography.bodySmall)
                        Text(fmtTime(vm.totalDuration), color = Color.White, style = MaterialTheme.typography.bodySmall)
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))

                Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    IconButton(
                        onClick = { vm.togglePlayPause() },
                        modifier = Modifier
                            .size(56.dp)
                            .background(Color.White.copy(alpha = 0.2f), CircleShape)
                    ) {
                        Icon(
                            imageVector = if (vm.isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(32.dp)
                        )
                    }
                }
            }
        }

        // 加载指示
        if (vm.isLoading && vm.totalDuration == 0L) {
            CircularProgressIndicator(color = Color.White, modifier = Modifier.align(Alignment.Center))
        }
    }
}

private fun fmtTime(ms: Long): String {
    val s = ms / 1000
    val h = s / 3600
    val m = (s % 3600) / 60
    val sec = s % 60
    return if (h > 0) String.format("%d:%02d:%02d", h, m, sec) else String.format("%02d:%02d", m, sec)
}
