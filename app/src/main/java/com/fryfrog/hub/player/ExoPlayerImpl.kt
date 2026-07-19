package com.fryfrog.hub.player

import android.content.Context
import android.view.SurfaceHolder
import android.view.SurfaceView
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.common.util.UnstableApi
import okhttp3.OkHttpClient
import java.util.concurrent.TimeUnit

@OptIn(UnstableApi::class)
class ExoPlayerImpl : VideoPlayer {

    private var _player: ExoPlayer? = null
    private var _context: Context? = null
    private var _surfaceView: SurfaceView? = null
    private var currentUrl: String? = null

    override val player: Player? get() = _player

    override fun initialize(context: Context, surfaceView: SurfaceView) {
        _context = context.applicationContext
        _surfaceView = surfaceView

        val okHttpClient = OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .build()

        val dataSourceFactory = OkHttpDataSource.Factory(okHttpClient)
        val mediaSourceFactory = DefaultMediaSourceFactory(dataSourceFactory)

        _player = ExoPlayer.Builder(context)
            .setMediaSourceFactory(mediaSourceFactory)
            .build()
            .apply {
                repeatMode = Player.REPEAT_MODE_OFF
                playWhenReady = true
            }

        // Connect player to SurfaceView
        surfaceView.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) {
                _player?.setVideoSurfaceHolder(holder)
            }

            override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {}

            override fun surfaceDestroyed(holder: SurfaceHolder) {
                _player?.setVideoSurfaceHolder(null)
            }
        })
    }

    override fun play(url: String) {
        currentUrl = url
        _player?.let { player ->
            val mediaItem = MediaItem.fromUri(url)
            player.setMediaItem(mediaItem)
            player.prepare()
            player.play()
        }
    }

    override fun pause() {
        _player?.pause()
    }

    override fun resume() {
        _player?.play()
    }

    override fun seekTo(position: Long) {
        _player?.seekTo(position)
    }

    override fun release() {
        _player?.release()
        _player = null
        _context = null
        _surfaceView = null
    }

    override fun setVolume(volume: Float) {
        _player?.volume = volume
    }

    override fun isPlaying(): Boolean {
        return _player?.isPlaying ?: false
    }

    override fun getCurrentPosition(): Long {
        return _player?.currentPosition ?: 0L
    }

    override fun getDuration(): Long {
        return _player?.duration ?: 0L
    }
}
