package com.fryfrog.hub.player

import android.content.Context
import android.util.Log
import android.view.SurfaceHolder
import android.view.SurfaceView
import androidx.media3.common.Player
import dev.jdtech.mpv.MPVLib

class MpvImpl : VideoPlayer {

    private var mpvInstance: MPVLib? = null
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
        override fun eventProperty(property: String, value: Boolean) {
            when (property) {
                "pause" -> isPlaying = !value
            }
        }
        override fun eventProperty(property: String, value: String) {}
        override fun event(eventId: Int) {
            when (eventId) {
                MPVLib.MpvEvent.MPV_EVENT_FILE_LOADED -> Log.d("MpvImpl", "File loaded")
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
            val instance = MPVLib.create(context)
            if (instance != null) {
                mpvInstance = instance
                instance.init()
                instance.addObserver(eventObserver)

                // Observe properties
                instance.observeProperty("time-pos", MPVLib.MpvFormat.MPV_FORMAT_DOUBLE)
                instance.observeProperty("duration", MPVLib.MpvFormat.MPV_FORMAT_DOUBLE)
                instance.observeProperty("pause", MPVLib.MpvFormat.MPV_FORMAT_FLAG)

                // Set options
                instance.setOptionString("keep-open", "yes")

                Log.d("MpvImpl", "MPV initialized successfully")
            } else {
                Log.e("MpvImpl", "Failed to create MPV instance")
            }
        } catch (e: Exception) {
            Log.e("MpvImpl", "Failed to initialize MPV", e)
        }

        surfaceView.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) {
                mpvInstance?.attachSurface(holder.surface)
            }

            override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
                mpvInstance?.attachSurface(holder.surface)
            }

            override fun surfaceDestroyed(holder: SurfaceHolder) {
                mpvInstance?.detachSurface()
            }
        })
    }

    override fun play(url: String) {
        currentUrl = url
        mpvInstance?.let { mpv ->
            mpv.command(arrayOf("loadfile", url))
            isPlaying = true
            Log.d("MpvImpl", "Playing: $url")
        }
    }

    override fun pause() {
        mpvInstance?.setPropertyBoolean("pause", true)
        isPlaying = false
    }

    override fun resume() {
        mpvInstance?.setPropertyBoolean("pause", false)
        isPlaying = true
    }

    override fun seekTo(position: Long) {
        mpvInstance?.let { mpv ->
            val seconds = position / 1000.0
            mpv.command(arrayOf("seek", seconds.toString(), "absolute"))
            currentPosition = position
        }
    }

    override fun release() {
        mpvInstance?.let { mpv ->
            mpv.removeObserver(eventObserver)
            mpv.destroy()
        }
        mpvInstance = null
        _context = null
        _surfaceView = null
    }

    override fun setVolume(volume: Float) {
        mpvInstance?.setPropertyDouble("volume", (volume * 100).toDouble())
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
