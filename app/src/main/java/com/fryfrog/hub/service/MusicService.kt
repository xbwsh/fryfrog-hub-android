package com.fryfrog.hub.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import com.fryfrog.hub.MainActivity
import com.fryfrog.hub.R
import com.fryfrog.hub.data.remote.ApiClient
import com.fryfrog.hub.player.MusicPlayer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.net.URL

class MusicService : Service() {

    companion object {
        const val CHANNEL_ID = "music_playback_channel"
        const val NOTIFICATION_ID = 1
        const val ACTION_PLAY_PAUSE = "com.fryfrog.hub.ACTION_PLAY_PAUSE"
        const val ACTION_NEXT = "com.fryfrog.hub.ACTION_NEXT"
        const val ACTION_PREVIOUS = "com.fryfrog.hub.ACTION_PREVIOUS"
        const val ACTION_STOP = "com.fryfrog.hub.ACTION_STOP"
    }

    private val binder = MusicBinder()
    private var musicPlayer: MusicPlayer? = null
    private var mediaSession: MediaSessionCompat? = null
    private var notificationManager: NotificationManager? = null

    private val _currentTrack = MutableStateFlow<TrackInfo?>(null)
    val currentTrack: StateFlow<TrackInfo?> = _currentTrack.asStateFlow()

    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

    private val _position = MutableStateFlow(0L)
    val position: StateFlow<Long> = _position.asStateFlow()

    private val _duration = MutableStateFlow(0L)
    val duration: StateFlow<Long> = _duration.asStateFlow()

    data class TrackInfo(
        val id: Long,
        val title: String,
        val artist: String?,
        val coverUrl: String?
    )

    inner class MusicBinder : Binder() {
        fun getService(): MusicService = this@MusicService
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        initMediaSession()
        initPlayer()
        // 立即启动前台服务，避免 ForegroundServiceDidNotStartInTimeException
        startForeground(NOTIFICATION_ID, buildNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY_PAUSE -> togglePlayPause()
            ACTION_NEXT -> playNext()
            ACTION_PREVIOUS -> playPrevious()
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        // 更新通知
        updateNotification()
        return START_STICKY
    }

    private fun createNotificationChannel() {
        notificationManager = getSystemService(NotificationManager::class.java)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "音乐播放",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "音乐播放控制"
                setShowBadge(false)
            }
            notificationManager?.createNotificationChannel(channel)
        }
    }

    private fun initMediaSession() {
        mediaSession = MediaSessionCompat(this, "MusicService").apply {
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() {
                    togglePlayPause()
                }

                override fun onPause() {
                    togglePlayPause()
                }

                override fun onSkipToNext() {
                    playNext()
                }

                override fun onSkipToPrevious() {
                    playPrevious()
                }

                override fun onStop() {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                }
            })
            isActive = true
        }
    }

    private fun initPlayer() {
        musicPlayer = MusicPlayer(this).apply {
            setOnEventListener { eventType ->
                when (eventType) {
                    MusicPlayer.EVENT_PLAYING -> {
                        _isPlaying.value = true
                        updatePlaybackState(PlaybackStateCompat.STATE_PLAYING)
                        updateNotification()
                    }
                    MusicPlayer.EVENT_PAUSED -> {
                        _isPlaying.value = false
                        updatePlaybackState(PlaybackStateCompat.STATE_PAUSED)
                        updateNotification()
                    }
                    MusicPlayer.EVENT_END_REACHED -> {
                        _isPlaying.value = false
                        updatePlaybackState(PlaybackStateCompat.STATE_PAUSED)
                        updateNotification()
                    }
                }
            }
        }
    }

    fun playTrack(trackId: Long, title: String, artist: String?, coverUrl: String?) {
        val trackInfo = TrackInfo(trackId, title, artist, coverUrl)
        _currentTrack.value = trackInfo
        
        val url = "${ApiClient.getBaseUrl()}/api/v1/music/$trackId/stream"
        musicPlayer?.play(url)
        
        _isPlaying.value = true
        updateMetadata(trackInfo)
        updatePlaybackState(PlaybackStateCompat.STATE_PLAYING)
        startForeground(NOTIFICATION_ID, buildNotification())
    }

    fun togglePlayPause() {
        musicPlayer?.togglePlayPause()
    }

    fun playNext() {
        // This will be handled by the ViewModel
        val intent = Intent("com.fryfrog.hub.ACTION_PLAY_NEXT")
        sendBroadcast(intent)
    }

    fun playPrevious() {
        // This will be handled by the ViewModel
        val intent = Intent("com.fryfrog.hub.ACTION_PLAY_PREVIOUS")
        sendBroadcast(intent)
    }

    fun seekTo(position: Long) {
        musicPlayer?.seekTo(position)
        _position.value = position
        updatePlaybackState(
            if (_isPlaying.value) PlaybackStateCompat.STATE_PLAYING
            else PlaybackStateCompat.STATE_PAUSED
        )
    }

    fun updateProgress() {
        musicPlayer?.let { player ->
            _position.value = player.getPosition()
            _duration.value = player.getDuration()
            updatePlaybackState(
                if (_isPlaying.value) PlaybackStateCompat.STATE_PLAYING
                else PlaybackStateCompat.STATE_PAUSED
            )
        }
    }

    private fun updateMetadata(track: TrackInfo) {
        val metadata = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, track.title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, track.artist ?: "")
            .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, "")
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, _duration.value)
            .build()
        
        mediaSession?.setMetadata(metadata)
    }

    private fun updatePlaybackState(state: Int) {
        val playbackState = PlaybackStateCompat.Builder()
            .setActions(
                PlaybackStateCompat.ACTION_PLAY or
                PlaybackStateCompat.ACTION_PAUSE or
                PlaybackStateCompat.ACTION_PLAY_PAUSE or
                PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                PlaybackStateCompat.ACTION_SEEK_TO
            )
            .setState(state, _position.value, 1f)
            .build()
        
        mediaSession?.setPlaybackState(playbackState)
    }

    private fun buildNotification(): Notification {
        val track = _currentTrack.value
        
        // 打开应用的 PendingIntent
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            this, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 上一曲
        val previousIntent = Intent(this, MusicService::class.java).apply {
            action = ACTION_PREVIOUS
        }
        val previousPendingIntent = PendingIntent.getService(
            this, 1, previousIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 播放/暂停
        val playPauseIntent = Intent(this, MusicService::class.java).apply {
            action = ACTION_PLAY_PAUSE
        }
        val playPausePendingIntent = PendingIntent.getService(
            this, 2, playPauseIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 下一曲
        val nextIntent = Intent(this, MusicService::class.java).apply {
            action = ACTION_NEXT
        }
        val nextPendingIntent = PendingIntent.getService(
            this, 3, nextIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 停止
        val stopIntent = Intent(this, MusicService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 4, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_music_note)
            .setContentTitle(track?.title ?: "未知歌曲")
            .setContentText(track?.artist ?: "未知艺术家")
            .setContentIntent(openAppPendingIntent)
            .setOngoing(true)
            .setShowWhen(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(R.drawable.ic_skip_previous, "上一曲", previousPendingIntent)
            .addAction(
                if (_isPlaying.value) R.drawable.ic_pause else R.drawable.ic_play_arrow,
                if (_isPlaying.value) "暂停" else "播放",
                playPausePendingIntent
            )
            .addAction(R.drawable.ic_skip_next, "下一曲", nextPendingIntent)
            .addAction(R.drawable.ic_close, "关闭", stopPendingIntent)
            .setStyle(
                androidx.media.app.NotificationCompat.MediaStyle()
                    .setMediaSession(mediaSession?.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2)
            )

        // 如果有封面，加载为大图标
        track?.coverUrl?.let { url ->
            try {
                Thread {
                    try {
                        val imageUrl = if (url.startsWith("http")) url else "${ApiClient.getBaseUrl()}$url"
                        val connection = URL(imageUrl).openConnection()
                        val inputStream = connection.getInputStream()
                        val bitmap = BitmapFactory.decodeStream(inputStream)
                        val scaledBitmap = Bitmap.createScaledBitmap(bitmap, 128, 128, true)
                        
                        // 更新通知
                        val updatedBuilder = builder.setLargeIcon(scaledBitmap)
                        notificationManager?.notify(NOTIFICATION_ID, updatedBuilder.build())
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }.start()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        return builder.build()
    }

    private fun updateNotification() {
        notificationManager?.notify(NOTIFICATION_ID, buildNotification())
    }

    override fun onDestroy() {
        super.onDestroy()
        musicPlayer?.release()
        mediaSession?.release()
    }
}
