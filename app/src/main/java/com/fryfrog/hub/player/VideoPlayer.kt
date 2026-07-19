package com.fryfrog.hub.player

import android.content.Context
import android.view.SurfaceView
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi

enum class PlayerType {
    EXOPLAYER,
    MPV
}

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
    fun create(type: PlayerType): VideoPlayer {
        return when (type) {
            PlayerType.EXOPLAYER -> ExoPlayerImpl()
            PlayerType.MPV -> {
                // MPV will be implemented later
                // Fallback to ExoPlayer for now
                ExoPlayerImpl()
            }
        }
    }
}
