package com.fryfrog.hub.player

import android.content.Context
import android.util.Log
import android.view.Surface
import android.view.SurfaceHolder
import android.view.SurfaceView
import androidx.media3.common.Player
import dev.jdtech.mpv.MPVLib

class MpvImpl : VideoPlayer {

    private var mpv: MPVLib? = null
    private var _context: Context? = null
    private var _surfaceView: SurfaceView? = null
    private var currentUrl: String? = null
    private var isPlaying = false
    private var currentPosition = 0L
    private var duration = 0L

    override val player: Player? get() = null

    private val eventObserver = object : MPVLib.EventObserver {
        override fun eventProperty(property: String) {}
        override fun eventProperty(property: String, value: Long) {}
        override fun eventProperty(property: String, value: Double) {
            when (property) {
                "time-pos" -> currentPosition = (value * 1000).toLong()
                "duration" -> duration = (value * 1000).toLong()
            }
        }
        override fun eventProperty(property: String, value: Boolean) {}
        override fun eventProperty(property: String, value: String) {}
        override fun event(eventId: Int) {
            when (eventId) {
                MPVLib.MpvEvent.MPV_EVENT_FILE_LOADED -> {
                    Log.d("MpvImpl", "File loaded")
                }
                MPVLib.MpvEvent.MPV_EVENT_END_FILE -> {
                    isPlaying = false
                    Log.d("MpvImpl", "Playback ended")
                }
            }
        }
    }

    override fun initialize(context: Context, surfaceView: SurfaceView) {
        _context = context.applicationContext
        _surfaceView = surfaceView

        try {
            mpv = MPVLib.create(context)
            mpv?.let { mpv ->
                mpv.init()
                mpv.addObserver(eventObserver)

                // Observe properties
                mpv.observeProperty("time-pos", MPVLib.MpvFormat.MPV_FORMAT_DOUBLE)
                mpv.observeProperty("duration", MPVLib.MpvFormat.MPV_FORMAT_DOUBLE)
                mpv.observeProperty("pause", MPVLib.MpvFormat.MPV_FORMAT_FLAG)

                // Set options
                mpv.setOptionString("keep-open", "yes")
                mpv.setOptionString("ytdl", "no")

                Log.d("MpvImpl", "MPV initialized successfully")
            }
        } catch (e: Exception) {
            Log.e("MpvImpl", "Failed to initialize MPV", e)
        }

        surfaceView.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) {
                mpv?.attachSurface(holder.surface)
            }

            override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
                mpv?.attachSurface(holder.surface)
            }

            override fun surfaceDestroyed(holder: SurfaceHolder) {
                mpv?.detachSurface()
            }
        })
    }

    override fun play(url: String) {
        currentUrl = url
        mpv?.let { mpv ->
            mpv.command(arrayOf("loadfile", url))
            isPlaying = true
            Log.d("MpvImpl", "Playing: $url")
        }
    }

    override fun pause() {
        mpv?.setPropertyBoolean("pause", true)
        isPlaying = false
    }

    override fun resume() {
        mpv?.setPropertyBoolean("pause", false)
        isPlaying = true
    }

    override fun seekTo(position: Long) {
        mpv?.let { mpv ->
            val seconds = position / 1000.0
            mpv.command(arrayOf("seek", seconds.toString(), "absolute"))
            currentPosition = position
        }
    }

    override fun release() {
        mpv?.let { mpv ->
            mpv.removeObserver(eventObserver)
            mpv.destroy()
        }
        mpv = null
        _context = null
        _surfaceView = null
    }

    override fun setVolume(volume: Float) {
        mpv?.setPropertyDouble("volume", (volume * 100).toDouble())
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
