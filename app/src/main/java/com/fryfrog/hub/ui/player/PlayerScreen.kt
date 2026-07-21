package com.fryfrog.hub.ui.player

import android.app.Activity
import android.content.Context
import android.content.pm.ActivityInfo
import android.media.AudioManager
import android.provider.Settings
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.TextureView
import android.view.WindowManager
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.VolumeDown
import androidx.compose.material.icons.automirrored.filled.VolumeOff
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import android.util.Log
import com.fryfrog.hub.data.model.WatchProgressRequest
import com.fryfrog.hub.data.remote.ApiClient
import com.fryfrog.hub.player.MpvPlayer
import com.fryfrog.hub.ui.theme.Dimens
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

class PlayerViewModel(private val videoId: Long) : ViewModel() {

    companion object {
        private const val TAG = "PlayerViewModel"
    }

    private var player: MpvPlayer? = null
    private var _isPlaying = mutableStateOf(false)
    private var _isLoading = mutableStateOf(true)
    private var _currentPos = mutableStateOf(0L)
    private var _totalDuration = mutableStateOf(0L)
    private var _isBuffering = mutableStateOf(false)
    private var hasStartedPlayback = false
    private var savedProgressPosition = 0L // Position loaded from server
    private val _showResumeHint = mutableStateOf(false)
    val showResumeHint: Boolean by _showResumeHint
    private val _resumePosition = mutableStateOf(0L)
    val resumePosition: Long by _resumePosition

    val isPlaying: Boolean by _isPlaying
    val isLoading: Boolean by _isLoading
    val currentPos: Long by _currentPos
    val totalDuration: Long by _totalDuration
    val isBuffering: Boolean by _isBuffering

    // Volume & Brightness
    private var audioManager: AudioManager? = null
    private var activityRef: Activity? = null
    private val _currentVolume = mutableIntStateOf(0)
    private val _maxVolume = mutableIntStateOf(100)
    private val _currentBrightness = mutableFloatStateOf(0.5f)
    private val _showVolumeIndicator = mutableStateOf(false)
    private val _showBrightnessIndicator = mutableStateOf(false)
    private val _indicatorType = mutableStateOf(IndicatorType.NONE)
    private var volumeAccumulator = 0f
    private var brightnessAccumulator = 0f
    private val volumeSensitivity = 50f
    private val brightnessSensitivity = 60f

    val currentVolume: Int by _currentVolume
    val maxVolume: Int by _maxVolume
    val currentBrightness: Float by _currentBrightness
    val showVolumeIndicator: Boolean by _showVolumeIndicator
    val showBrightnessIndicator: Boolean by _showBrightnessIndicator
    val indicatorType: IndicatorType by _indicatorType

    fun init(context: Context) {
        if (player == null) {
            hasStartedPlayback = false
            audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            activityRef = context as? Activity
            _maxVolume.intValue = audioManager?.getStreamMaxVolume(AudioManager.STREAM_MUSIC) ?: 15
            _currentVolume.intValue = audioManager?.getStreamVolume(AudioManager.STREAM_MUSIC) ?: 0
            _currentBrightness.floatValue = getScreenBrightness(context)

            player = MpvPlayer(context).apply {
                setOnEventListener { eventType ->
                    when (eventType) {
                        MpvPlayer.EVENT_PLAYING -> {
                            _isPlaying.value = true
                            _isLoading.value = false
                            _isBuffering.value = false
                            // Seek to saved position when playback starts
                            seekToSavedPosition()
                        }
                        MpvPlayer.EVENT_PAUSED -> _isPlaying.value = false
                        MpvPlayer.EVENT_END_REACHED -> {
                            _isPlaying.value = false
                            _isLoading.value = false
                            _isBuffering.value = false
                            // Mark as completed
                            saveProgress()
                        }
                        MpvPlayer.EVENT_BUFFERING -> _isBuffering.value = true
                        MpvPlayer.EVENT_ERROR -> {
                            _isLoading.value = false
                            _isBuffering.value = false
                        }
                    }
                }
            }
        }
    }

    private fun getScreenBrightness(context: Context): Float {
        val window = (context as? Activity)?.window
        val layoutParams = window?.attributes
        val brightness = layoutParams?.screenBrightness
        return if (brightness != null && brightness >= 0) {
            brightness.coerceIn(0f, 1f)
        } else {
            // Read from system settings
            try {
                val value = Settings.System.getInt(
                    context.contentResolver,
                    Settings.System.SCREEN_BRIGHTNESS
                )
                value / 255f
            } catch (e: Exception) {
                0.5f
            }
        }
    }

    fun adjustVolume(delta: Float) {
        audioManager?.let { am ->
            volumeAccumulator += delta
            val max = _maxVolume.intValue
            val stepsToChange = (volumeAccumulator / volumeSensitivity).toInt()
            if (stepsToChange != 0) {
                volumeAccumulator -= stepsToChange * volumeSensitivity
                val current = _currentVolume.intValue
                val newVolume = (current - stepsToChange).coerceIn(0, max)
                if (newVolume != current) {
                    am.setStreamVolume(AudioManager.STREAM_MUSIC, newVolume, 0)
                    _currentVolume.intValue = newVolume
                }
            }
            _showVolumeIndicator.value = true
            _indicatorType.value = IndicatorType.VOLUME
        }
    }

    fun adjustBrightness(delta: Float) {
        activityRef?.window?.let { window ->
            brightnessAccumulator += delta
            val stepsToChange = (brightnessAccumulator / brightnessSensitivity).toInt()
            if (stepsToChange != 0) {
                brightnessAccumulator -= stepsToChange * brightnessSensitivity
                val current = _currentBrightness.floatValue
                val stepSize = 0.03f
                val newBrightness = (current - stepsToChange * stepSize).coerceIn(0.01f, 1f)
                val layoutParams = window.attributes
                layoutParams.screenBrightness = newBrightness
                window.attributes = layoutParams
                _currentBrightness.floatValue = newBrightness
            }
            _showBrightnessIndicator.value = true
            _indicatorType.value = IndicatorType.BRIGHTNESS
        }
    }

    fun resetAccumulators() {
        volumeAccumulator = 0f
        brightnessAccumulator = 0f
    }

    fun hideIndicators() {
        _showVolumeIndicator.value = false
        _showBrightnessIndicator.value = false
        _indicatorType.value = IndicatorType.NONE
    }

    fun initPlayer(context: Context) {
        Log.d(TAG, "initPlayer()")
        player?.init()
    }

    fun attachSurface(surface: android.view.Surface, width: Int, height: Int) {
        Log.d(TAG, "attachSurface($width x $height)")
        player?.attachSurface(surface, width, height)
    }

    fun startPlaybackIfNeeded() {
        Log.d(TAG, "startPlaybackIfNeeded() hasStarted=$hasStartedPlayback")
        if (!hasStartedPlayback) {
            hasStartedPlayback = true
            // Load progress first
            viewModelScope.launch {
                loadProgress()
                // Start playback
                val url = "${ApiClient.getBaseUrl()}/api/v1/video/$videoId/stream"
                Log.d(TAG, "Opening: $url")
                player?.open(url)
            }
        }
    }

    private suspend fun loadProgress() {
        try {
            val api = ApiClient.getApi()
            val response = api.getVideoProgress(videoId)
            if (response.success && response.data != null) {
                val progress = response.data
                savedProgressPosition = (progress.positionSeconds * 1000).toLong()
                Log.d(TAG, "Loaded progress: ${progress.positionSeconds}s, ${progress.progressPercent}%")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load progress", e)
        }
    }

    fun seekToSavedPosition() {
        if (savedProgressPosition > 0) {
            Log.d(TAG, "Seeking to saved position: $savedProgressPosition ms")
            _resumePosition.value = savedProgressPosition
            _showResumeHint.value = true
            player?.seekTo(savedProgressPosition)
            savedProgressPosition = 0L
            // Hide hint after 2 seconds
            viewModelScope.launch {
                delay(2000)
                _showResumeHint.value = false
            }
        }
    }

    fun saveProgress() {
        viewModelScope.launch(Dispatchers.IO) {
            try {
                val pos = player?.getPosition() ?: return@launch
                val dur = player?.getDuration() ?: return@launch
                if (pos <= 0 || dur <= 0) return@launch

                val api = ApiClient.getApi()
                val request = WatchProgressRequest(
                    position = pos / 1000.0,
                    duration = dur / 1000.0,
                    completed = pos >= dur * 0.95 // Consider 95% as completed
                )
                api.saveVideoProgress(videoId, request)
                Log.d(TAG, "Progress saved: ${pos / 1000}s / ${dur / 1000}s")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to save progress", e)
            }
        }
    }

    fun detachSurface() {
        Log.d(TAG, "detachSurface()")
        player?.detachSurface()
    }

    fun togglePlayPause() {
        player?.togglePlayPause()
    }

    fun seekTo(ms: Long) {
        player?.seekTo(ms)
    }

    fun seekForward(seconds: Int = 10) {
        player?.let {
            val newPos = minOf(it.getPosition() + seconds * 1000, it.getDuration())
            it.seekTo(newPos)
        }
    }

    fun seekBackward(seconds: Int = 10) {
        player?.let {
            val newPos = maxOf(it.getPosition() - seconds * 1000, 0L)
            it.seekTo(newPos)
        }
    }

    fun seekRelative(deltaMs: Long) {
        player?.let {
            val current = it.getPosition()
            val duration = it.getDuration()
            val newPos = (current + deltaMs).coerceIn(0, duration)
            it.seekTo(newPos)
            _currentPos.value = newPos
        }
    }

    private val _seekDelta = mutableLongStateOf(0L)
    val seekDelta: Long by _seekDelta

    fun showSeekIndicator(deltaMs: Long) {
        _seekDelta.longValue = deltaMs
        _showSeekIndicator.value = true
        _indicatorType.value = IndicatorType.SEEK
    }

    private val _showSeekIndicator = mutableStateOf(false)
    val showSeekIndicator: Boolean by _showSeekIndicator

    fun hideAllIndicators() {
        _showVolumeIndicator.value = false
        _showBrightnessIndicator.value = false
        _showSeekIndicator.value = false
        _indicatorType.value = IndicatorType.NONE
    }

    // Playback info
    private val _showPlaybackInfo = mutableStateOf(false)
    val showPlaybackInfo: Boolean by _showPlaybackInfo
    private val _playbackInfo = mutableStateOf<MpvPlayer.PlaybackInfo?>(null)
    val playbackInfo: MpvPlayer.PlaybackInfo? by _playbackInfo

    fun togglePlaybackInfo() {
        _showPlaybackInfo.value = !_showPlaybackInfo.value
        if (_showPlaybackInfo.value) {
            _playbackInfo.value = player?.getPlaybackInfo()
        }
    }

    fun tick() {
        player?.let {
            val pos = it.getPosition()
            val dur = it.getDuration()
            _currentPos.value = pos
            _totalDuration.value = dur
            if (pos > 0 && dur > 0 && it.isPlaying()) {
                _isBuffering.value = false
            }
        }
    }

    // Quality
    private val _currentQuality = mutableStateOf("original")
    val currentQuality: String by _currentQuality
    private val _showQualityMenu = mutableStateOf(false)
    val showQualityMenu: Boolean by _showQualityMenu

    val qualities = listOf("original", "1080p", "720p", "480p", "360p")

    fun toggleQualityMenu() {
        _showQualityMenu.value = !_showQualityMenu.value
    }

    fun changeQuality(quality: String) {
        if (quality == _currentQuality.value) {
            _showQualityMenu.value = false
            return
        }
        _currentQuality.value = quality
        _showQualityMenu.value = false
        // Reload with new quality
        val currentPosition = player?.getPosition() ?: 0L
        val url = buildStreamUrl()
        Log.d(TAG, "Changing quality to $quality, reloading: $url")
        player?.open(url)
        // Seek to previous position after quality change
        if (currentPosition > 0) {
            player?.seekTo(currentPosition)
        }
    }

    private fun buildStreamUrl(): String {
        val baseUrl = "${ApiClient.getBaseUrl()}/api/v1/video/$videoId/stream"
        return if (_currentQuality.value == "original") {
            baseUrl
        } else {
            "$baseUrl/transcode?quality=${_currentQuality.value}"
        }
    }

    fun release() {
        // Save progress before releasing
        viewModelScope.launch(Dispatchers.IO) {
            saveProgress()
        }
        player?.release()
        player = null
        activityRef = null
    }
}

enum class IndicatorType {
    NONE, VOLUME, BRIGHTNESS, SEEK
}

class PlayerVMFactory(private val videoId: Long) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T = PlayerViewModel(videoId) as T
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PlayerScreen(
    videoId: Long,
    title: String,
    onBackClick: () -> Unit
) {
    val vm: PlayerViewModel = viewModel(factory = PlayerVMFactory(videoId))
    val activity = LocalContext.current as Activity
    var showControls by remember { mutableStateOf(true) }
    var isSeeking by remember { mutableStateOf(false) }
    var seekPosition by remember { mutableStateOf(0f) }
    var lastTapTime by remember { mutableLongStateOf(0L) }

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

    LaunchedEffect(vm.isPlaying) {
        while (vm.isPlaying) {
            vm.tick()
            delay(250)
        }
    }

    LaunchedEffect(showControls, vm.isPlaying, vm.showQualityMenu) {
        if (showControls && vm.isPlaying && !vm.showQualityMenu) {
            delay(4000)
            showControls = false
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .pointerInput(vm.showPlaybackInfo) {
                if (vm.showPlaybackInfo) return@pointerInput
                detectTapGestures(
                    onTap = {
                        showControls = !showControls
                    },
                    onDoubleTap = { offset ->
                        val width = size.width
                        when {
                            offset.x < width / 3f -> vm.seekBackward(10)
                            offset.x > width * 2 / 3f -> vm.seekForward(10)
                            else -> vm.togglePlayPause()
                        }
                    }
                )
            }
            .pointerInput(vm.showPlaybackInfo) {
                if (vm.showPlaybackInfo) return@pointerInput
                awaitEachGesture {
                    val down = awaitFirstDown(requireUnconsumed = false)
                    vm.resetAccumulators()
                    var swipeAccumulator = 0f
                    var isSwiping = false
                    do {
                        val event = awaitPointerEvent()
                        val dragChange = event.changes.firstOrNull()
                        if (dragChange != null && dragChange.pressed) {
                            val pos = dragChange.position
                            val prevPos = dragChange.previousPosition
                            val deltaX = pos.x - prevPos.x
                            val deltaY = pos.y - prevPos.y

                            // Detect horizontal swipe
                            if (!isSwiping && (kotlin.math.abs(deltaX) > 5f || kotlin.math.abs(deltaY) > 5f)) {
                                isSwiping = kotlin.math.abs(deltaX) > kotlin.math.abs(deltaY)
                            }

                            if (isSwiping) {
                                swipeAccumulator += deltaX
                                val seekDelta = (swipeAccumulator / 100f * 5000f).toLong()
                                vm.showSeekIndicator(seekDelta)
                            } else if (deltaY != 0f) {
                                val width = size.width
                                val x = pos.x
                                if (x < width / 3f) {
                                    vm.adjustBrightness(deltaY)
                                } else if (x > width * 2 / 3f) {
                                    vm.adjustVolume(deltaY)
                                }
                            }
                        }
                    } while (event.changes.any { it.pressed })
                    // Seek on release
                    if (isSwiping) {
                        val seekDelta = (swipeAccumulator / 100f * 5000f).toLong()
                        if (kotlin.math.abs(seekDelta) >= 500L) {
                            vm.seekRelative(seekDelta)
                        }
                    }
                    vm.hideAllIndicators()
                }
            }
    ) {
        AndroidView(
            factory = { ctx ->
                TextureView(ctx).apply {
                    surfaceTextureListener = object : TextureView.SurfaceTextureListener {
                        override fun onSurfaceTextureAvailable(surface: android.graphics.SurfaceTexture, width: Int, height: Int) {
                            vm.initPlayer(ctx)
                            val androidSurface = android.view.Surface(surface)
                            vm.attachSurface(androidSurface, width, height)
                            vm.startPlaybackIfNeeded()
                        }
                        override fun onSurfaceTextureSizeChanged(surface: android.graphics.SurfaceTexture, width: Int, height: Int) {
                            val androidSurface = android.view.Surface(surface)
                            vm.attachSurface(androidSurface, width, height)
                        }
                        override fun onSurfaceTextureDestroyed(surface: android.graphics.SurfaceTexture): Boolean {
                            vm.detachSurface()
                            return true
                        }
                        override fun onSurfaceTextureUpdated(surface: android.graphics.SurfaceTexture) {}
                    }
                }
            },
            modifier = Modifier.fillMaxSize()
        )

        // Volume / Brightness / Seek indicator
        if (vm.indicatorType != IndicatorType.NONE) {
            Box(
                modifier = Modifier
                    .align(Alignment.Center)
                    .background(Color.Black.copy(alpha = 0.7f), RoundedCornerShape(12.dp))
                    .padding(horizontal = 24.dp, vertical = 16.dp),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    when (vm.indicatorType) {
                        IndicatorType.SEEK -> {
                            val seconds = vm.seekDelta / 1000
                            val icon = if (seconds > 0) Icons.Default.FastForward else Icons.Default.FastRewind
                            Icon(
                                imageVector = icon,
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(36.dp)
                            )
                            Text(
                                text = "${if (seconds > 0) "+" else ""}${seconds}s",
                                color = Color.White,
                                style = MaterialTheme.typography.titleLarge
                            )
                        }
                        else -> {
                            Icon(
                                imageVector = when (vm.indicatorType) {
                                    IndicatorType.VOLUME -> if (vm.currentVolume == 0) Icons.AutoMirrored.Filled.VolumeOff
                                        else if (vm.currentVolume < vm.maxVolume / 2) Icons.AutoMirrored.Filled.VolumeDown
                                        else Icons.AutoMirrored.Filled.VolumeUp
                                    IndicatorType.BRIGHTNESS -> Icons.Default.Brightness6
                                    else -> Icons.Default.Info
                                },
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(28.dp)
                            )
                            LinearProgressIndicator(
                                progress = {
                                    when (vm.indicatorType) {
                                        IndicatorType.VOLUME -> vm.currentVolume.toFloat() / vm.maxVolume.toFloat()
                                        IndicatorType.BRIGHTNESS -> vm.currentBrightness
                                        else -> 0f
                                    }
                                },
                                modifier = Modifier
                                    .width(120.dp)
                                    .height(4.dp)
                                    .clip(RoundedCornerShape(2.dp)),
                                color = Color.White,
                                trackColor = Color.White.copy(alpha = 0.3f)
                            )
                            Text(
                                text = when (vm.indicatorType) {
                                    IndicatorType.VOLUME -> "${(vm.currentVolume * 100 / vm.maxVolume)}%"
                                    IndicatorType.BRIGHTNESS -> "${(vm.currentBrightness * 100).toInt()}%"
                                    else -> ""
                                },
                                color = Color.White,
                                style = MaterialTheme.typography.labelMedium
                            )
                        }
                    }
                }
            }
        }

        AnimatedVisibility(
            visible = showControls,
            enter = fadeIn(),
            exit = fadeOut()
        ) {
            Column(modifier = Modifier.fillMaxSize()) {
                // Top bar
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Color.Transparent)
                        .statusBarsPadding()
                        .padding(horizontal = 12.dp, vertical = 8.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        IconButton(onClick = onBackClick, modifier = Modifier.size(40.dp)) {
                            Icon(
                                Icons.AutoMirrored.Filled.ArrowBack,
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(24.dp)
                            )
                        }
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            title,
                            color = Color.White,
                            style = MaterialTheme.typography.titleMedium,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.weight(1f)
                        )
                        IconButton(onClick = { vm.togglePlaybackInfo() }, modifier = Modifier.size(40.dp)) {
                            Icon(
                                Icons.Default.Info,
                                contentDescription = "Playback Info",
                                tint = Color.White,
                                modifier = Modifier.size(22.dp)
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.weight(1f))

                // Center play/pause indicator (tap zone)
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f),
                    contentAlignment = Alignment.Center
                ) {
                    if (vm.isBuffering) {
                        CircularProgressIndicator(
                            color = Color.White.copy(alpha = 0.8f),
                            modifier = Modifier.size(48.dp),
                            strokeWidth = 3.dp
                        )
                    }
                }

                // Bottom controls
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Color.Transparent)
                        .navigationBarsPadding()
                        .padding(horizontal = 16.dp, vertical = 8.dp)
                ) {
                    // Progress bar
                    if (vm.totalDuration > 0) {
                        Box(modifier = Modifier.fillMaxWidth()) {
                            Slider(
                                value = if (isSeeking) seekPosition else vm.currentPos.toFloat(),
                                valueRange = 0f..vm.totalDuration.toFloat(),
                                onValueChange = { value ->
                                    isSeeking = true
                                    seekPosition = value
                                },
                                onValueChangeFinished = {
                                    vm.seekTo(seekPosition.toLong())
                                    isSeeking = false
                                },
                                modifier = Modifier.fillMaxWidth(),
                                colors = SliderDefaults.colors(
                                    thumbColor = Color.White,
                                    activeTrackColor = MaterialTheme.colorScheme.primary,
                                    inactiveTrackColor = Color.White.copy(alpha = 0.3f),
                                    disabledThumbColor = Color.White,
                                    disabledActiveTrackColor = MaterialTheme.colorScheme.primary,
                                    disabledInactiveTrackColor = Color.White.copy(alpha = 0.3f)
                                ),
                                thumb = {
                                    Box(
                                        modifier = Modifier
                                            .size(14.dp)
                                            .clip(CircleShape)
                                            .background(Color.White)
                                    )
                                },
                                track = { sliderState ->
                                    Box(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .height(3.dp)
                                            .clip(RoundedCornerShape(2.dp))
                                    ) {
                                        Box(
                                            modifier = Modifier
                                                .fillMaxHeight()
                                                .fillMaxWidth(fraction = sliderState.value / sliderState.valueRange.endInclusive)
                                                .background(MaterialTheme.colorScheme.primary)
                                        )
                                        Box(
                                            modifier = Modifier
                                                .fillMaxHeight()
                                                .fillMaxWidth(fraction = 1f - sliderState.value / sliderState.valueRange.endInclusive)
                                                .align(Alignment.CenterEnd)
                                                .background(Color.White.copy(alpha = 0.3f))
                                        )
                                    }
                                }
                            )
                        }

                        // Controls row: Play | Time ---- Quality
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(2.dp)
                        ) {
                            // Play/Pause
                            IconButton(
                                onClick = { vm.togglePlayPause() },
                                modifier = Modifier.size(36.dp)
                            ) {
                                Icon(
                                    imageVector = if (vm.isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                                    contentDescription = null,
                                    tint = Color.White,
                                    modifier = Modifier.size(28.dp)
                                )
                            }

                            // Time display
                            Text(
                                text = "${fmtTime(if (isSeeking) seekPosition.toLong() else vm.currentPos)} / ${fmtTime(vm.totalDuration)}",
                                color = Color.White,
                                style = MaterialTheme.typography.labelMedium
                            )

                            Spacer(modifier = Modifier.weight(1f))

                            // Quality selector
                            Box {
                                Surface(
                                    onClick = { vm.toggleQualityMenu() },
                                    color = Color.White.copy(alpha = 0.15f),
                                    shape = RoundedCornerShape(4.dp)
                                ) {
                                    Row(
                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Text(
                                            text = if (vm.currentQuality == "original") "原画" else vm.currentQuality,
                                            color = Color.White,
                                            style = MaterialTheme.typography.labelMedium
                                        )
                                        Icon(
                                            Icons.Default.ArrowDropDown,
                                            contentDescription = null,
                                            tint = Color.White,
                                            modifier = Modifier.size(14.dp)
                                        )
                                    }
                                }

                                DropdownMenu(
                                    expanded = vm.showQualityMenu,
                                    onDismissRequest = { vm.toggleQualityMenu() },
                                    modifier = Modifier
                                        .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(Dimens.radiusMd))
                                ) {
                                    vm.qualities.forEach { quality ->
                                        DropdownMenuItem(
                                            text = {
                                                Row(
                                                    modifier = Modifier.fillMaxWidth(),
                                                    horizontalArrangement = Arrangement.SpaceBetween,
                                                    verticalAlignment = Alignment.CenterVertically
                                                ) {
                                                    Text(
                                                        text = if (quality == "original") "原画" else quality,
                                                        style = MaterialTheme.typography.bodyMedium
                                                    )
                                                    if (quality == vm.currentQuality) {
                                                        Icon(
                                                            Icons.Default.Check,
                                                            contentDescription = null,
                                                            modifier = Modifier.size(16.dp),
                                                            tint = MaterialTheme.colorScheme.primary
                                                        )
                                                    }
                                                }
                                            },
                                            onClick = { vm.changeQuality(quality) }
                                        )
                                    }
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(4.dp))
                    }
                }
            }
        }

        // Playback info overlay
        if (vm.showPlaybackInfo) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .clickable { vm.togglePlaybackInfo() }
            ) {
                Card(
                    modifier = Modifier
                        .statusBarsPadding()
                        .padding(start = 12.dp, top = 56.dp)
                        .widthIn(max = 350.dp)
                        .wrapContentWidth()
                        .heightIn(max = 350.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = Color.Black.copy(alpha = 0.85f)
                    ),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    androidx.compose.foundation.lazy.LazyColumn(
                        modifier = Modifier.padding(10.dp),
                        verticalArrangement = Arrangement.spacedBy(2.dp)
                    ) {
                        item {
                            Text(
                                text = title,
                                color = Color.White,
                                style = MaterialTheme.typography.labelLarge,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }

                        vm.playbackInfo?.let { info ->
                            // General
                            item {
                                InfoSection("通用") {
                                    CompactInfoGrid(listOf(
                                        "播放器" to info.player,
                                        "协议" to info.protocol,
                                        "格式" to info.containerFormat
                                    ))
                                }
                            }

                            // Video
                            item {
                                HorizontalDivider(color = Color.White.copy(alpha = 0.1f), modifier = Modifier.padding(vertical = 6.dp))
                                InfoSection("视频") {
                                    CompactInfoGrid(listOf(
                                        "编码" to info.videoCodec.substringBefore("(").trim(),
                                        "分辨率" to "${info.width}x${info.height}",
                                        "帧率" to if (info.fps > 0) String.format("%.1ffps", info.fps) else "",
                                        "码率" to if (info.bitrate > 0) "${info.bitrate / 1000}kbps" else "",
                                        "硬件" to info.hwDec.ifEmpty { "无" },
                                        "像素" to info.pixelFormat,
                                        "色彩" to info.colorPrimaries,
                                        "HDR" to if (info.isHDR) "是" else "否",
                                        "杜比" to if (info.isDolbyVision) "是" else "否"
                                    ))
                                }
                            }

                            // Audio
                            if (info.audioCodec.isNotEmpty()) {
                                item {
                                    HorizontalDivider(color = Color.White.copy(alpha = 0.1f), modifier = Modifier.padding(vertical = 6.dp))
                                    InfoSection("音频") {
                                        CompactInfoGrid(listOf(
                                            "编码" to info.audioCodec.substringBefore("(").trim(),
                                            "声道" to info.audioChannels,
                                            "采样" to if (info.audioSampleRate > 0) "${info.audioSampleRate / 1000}kHz" else ""
                                        ))
                                    }
                                }
                            }

                            // Subtitles
                            if (info.subtitleTracks.isNotEmpty()) {
                                item {
                                    HorizontalDivider(color = Color.White.copy(alpha = 0.1f), modifier = Modifier.padding(vertical = 6.dp))
                                    InfoSection("字幕") {
                                        Text(
                                            text = info.subtitleTracks.joinToString(", ") { it.lang.ifEmpty { "?" } },
                                            color = Color.White,
                                            style = MaterialTheme.typography.labelSmall
                                        )
                                    }
                                }
                            }
                        } ?: item {
                            Text(
                                text = "暂无信息",
                                color = Color.White.copy(alpha = 0.5f),
                                style = MaterialTheme.typography.labelSmall
                            )
                        }
                    }
                }
            }
        }

        // Loading overlay
        if (vm.isLoading && vm.totalDuration == 0L) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(
                    color = Color.White.copy(alpha = 0.8f),
                    modifier = Modifier.size(48.dp),
                    strokeWidth = 3.dp
                )
            }
        }

        // Resume hint
        if (vm.showResumeHint) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Surface(
                    color = Color.Black.copy(alpha = 0.7f),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Icon(
                            Icons.Default.PlayArrow,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(20.dp)
                        )
                        Text(
                            text = "继续播放 ${fmtTime(vm.resumePosition)}",
                            color = Color.White,
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun InfoSection(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(
            text = title,
            color = Color.White.copy(alpha = 0.5f),
            style = MaterialTheme.typography.labelSmall
        )
        content()
    }
}

@Composable
private fun CompactInfoGrid(items: List<Pair<String, String>>) {
    val filtered = items.filter { it.second.isNotEmpty() }
    Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
        filtered.chunked(2).forEach { row ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                row.forEach { (label, value) ->
                    Row(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "$label:",
                            color = Color.White.copy(alpha = 0.5f),
                            style = MaterialTheme.typography.labelSmall
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = value,
                            color = Color.White,
                            style = MaterialTheme.typography.labelSmall
                        )
                    }
                }
                if (row.size == 1) Spacer(modifier = Modifier.weight(1f))
            }
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
