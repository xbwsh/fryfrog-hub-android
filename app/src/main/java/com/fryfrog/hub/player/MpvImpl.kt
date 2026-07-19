package com.fryfrog.hub.player

import android.content.Context
import android.view.SurfaceHolder
import android.view.SurfaceView
import androidx.media3.common.Player
import is.xyz.mpv.MPVLib

class MpvImpl : VideoPlayer {

    private var _mpv: MPVLib? = null
    private var _context: Context? = null
    private var _surfaceView: SurfaceView? = null
    private var currentUrl: String? = null
    private var isPlaying = false
    private var currentPosition = 0L
    private var duration = 0L
    private var listener: Player.Listener? = null

    override val player: Player? get() = null

    override fun initialize(context: Context, surfaceView: SurfaceView) {
        _context = context.applicationContext
        _surfaceView = surfaceView

        _mpv = MPVLib().apply {
            init(context, false)
            observeProperty("time-pos", MPVLib.MPV_FORMAT_INT64) { _, value ->
                currentPosition = (value as? Long) ?: 0L
            }
            observeProperty("duration", MPVLib.MPV_FORMAT_INT64) { _, value ->
                duration = (value as? Long) ?: 0L
            }
            observeProperty("core-idle", MPVLib.MPV_FORMAT_FLAG) { _, value ->
                val idle = (value as? Int) == 1
                if (idle && isPlaying) {
                    isPlaying = false
                    listener?.onIsPlayingChanged(false)
                }
            }
            observeProperty("pause", MPVLib.MPV_FORMAT_FLAG) { _, value ->
                val paused = (value as? Int) == 1
                isPlaying = !paused
                listener?.onIsPlayingChanged(isPlaying)
            }
        }

        surfaceView.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) {
                _mpv?.let { mpv ->
                    mpv.setSurface(holder.surface)
                }
            }

            override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
                _mpv?.let { mpv ->
                    mpv.setSurface(holder.surface)
                }
            }

            override fun surfaceDestroyed(holder: SurfaceHolder) {
                _mpv?.setSurface(null)
            }
        })
    }

    override fun play(url: String) {
        currentUrl = url
        _mpv?.let { mpv ->
            mpv.command(arrayOf("loadfile", url))
            isPlaying = true
            listener?.onIsPlayingChanged(true)
        }
    }

    override fun pause() {
        _mpv?.setPropertyString("pause", "yes")
        isPlaying = false
        listener?.onIsPlayingChanged(false)
    }

    override fun resume() {
        _mpv?.setPropertyString("pause", "no")
        isPlaying = true
        listener?.onIsPlayingChanged(true)
    }

    override fun seekTo(position: Long) {
        _mpv?.let { mpv ->
            mpv.command(arrayOf("seek", position.toString(), "absolute"))
            currentPosition = position
        }
    }

    override fun release() {
        _mpv?.let { mpv ->
            mpv.destroy()
        }
        _mpv = null
        _context = null
        _surfaceView = null
    }

    override fun setVolume(volume: Float) {
        _mpv?.setPropertyDouble("volume", (volume * 100).toDouble())
    }

    override fun isPlaying(): Boolean {
        return isPlaying
    }

    override fun getCurrentPosition(): Long {
        return currentPosition * 1000 // Convert seconds to milliseconds
    }

    override fun getDuration(): Long {
        return duration * 1000 // Convert seconds to milliseconds
    }

    fun setListener(listener: Player.Listener) {
        this.listener = listener
    }
}
