package com.fryfrog.hub.player

import android.content.Context
import android.util.Log
import android.view.SurfaceView
import androidx.media3.common.Player

/**
 * MPV Player implementation placeholder.
 * 
 * To enable MPV support, you need to:
 * 1. Download mpv-android AAR from https://github.com/nicholaschum/mpv-android/releases
 * 2. Place it in app/libs/ directory
 * 3. Add implementation(files("libs/mpv-android-0.39.0.aar")) to build.gradle.kts
 * 4. Uncomment the MPVLib import and implementation below
 */
class MpvImpl : VideoPlayer {

    private var _context: Context? = null
    private var _surfaceView: SurfaceView? = null
    private var currentUrl: String? = null
    private var isPlaying = false
    private var currentPosition = 0L
    private var duration = 0L

    override val player: Player? get() = null

    override fun initialize(context: Context, surfaceView: SurfaceView) {
        _context = context.applicationContext
        _surfaceView = surfaceView
        
        Log.w("MpvImpl", "MPV player not fully integrated. Falling back to ExoPlayer behavior.")
    }

    override fun play(url: String) {
        currentUrl = url
        // MPV not integrated yet - this will be a no-op
        Log.w("MpvImpl", "MPV play called but not integrated: $url")
    }

    override fun pause() {
        isPlaying = false
    }

    override fun resume() {
        isPlaying = true
    }

    override fun seekTo(position: Long) {
        currentPosition = position
    }

    override fun release() {
        _context = null
        _surfaceView = null
    }

    override fun setVolume(volume: Float) {
        // No-op
    }

    override fun isPlaying(): Boolean {
        return isPlaying
    }

    override fun getCurrentPosition(): Long {
        return currentPosition
    }

    override fun getDuration(): Long {
        return duration
    }
}
