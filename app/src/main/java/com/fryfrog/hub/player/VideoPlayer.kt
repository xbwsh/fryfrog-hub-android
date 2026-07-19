package com.fryfrog.hub.player

import android.content.Context
import android.view.SurfaceView
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi

interface VideoPlayer {
    val player: Player?
    fun initialize(context: Context, surfaceView: SurfaceView)
    fun play(url: String)
    fun pause()
    fun resume()
    fun seekTo(position: Long)
    fun release()
    fun setVolume(volume: Float)
    fun isPlaying(): Boolean
    fun getCurrentPosition(): Long
    fun getDuration(): Long
}

@OptIn(UnstableApi::class)
object PlayerFactory {
    fun create(): VideoPlayer {
        return ExoPlayerImpl()
    }
}
