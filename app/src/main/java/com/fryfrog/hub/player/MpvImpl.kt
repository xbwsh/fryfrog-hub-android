package com.fryfrog.hub.player

import android.content.Context
import android.util.Log
import android.view.SurfaceView
import androidx.media3.common.Player

/**
 * MPV Player placeholder.
 * Uses external mpv-android app via Intent.
 */
class MpvImpl : VideoPlayer {

    override val player: Player? get() = null

    override fun initialize(context: Context, surfaceView: SurfaceView) {
        Log.w("MpvImpl", "MPV uses external player")
    }

    override fun play(url: String) {
        Log.w("MpvImpl", "MPV play called: $url")
    }

    override fun pause() {}
    override fun resume() {}
    override fun seekTo(position: Long) {}
    override fun release() {}
    override fun setVolume(volume: Float) {}
    override fun isPlaying(): Boolean = false
    override fun getCurrentPosition(): Long = 0L
    override fun getDuration(): Long = 0L
}
