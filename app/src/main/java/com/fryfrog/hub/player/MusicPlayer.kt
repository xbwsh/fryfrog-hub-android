package com.fryfrog.hub.player

import android.content.Context
import `is`.xyz.mpv.MPVLib

class MusicPlayer(private val context: Context) {

    private var listener: ((Int) -> Unit)? = null
    private var initialized = false

    fun setOnEventListener(listener: (eventType: Int) -> Unit) {
        this.listener = listener
    }

    private fun ensureInit() {
        if (!initialized) {
            MPVLib.create(context)
            MPVLib.setOptionString("vo", "null")
            MPVLib.setOptionString("ao", "audiotrack")
            MPVLib.setOptionString("config", "no")
            MPVLib.setOptionString("idle", "once")
            MPVLib.init()
            MPVLib.addObserver(eventObserver)
            MPVLib.observeProperty("pause", MPVLib.MpvFormat.MPV_FORMAT_FLAG)
            initialized = true
        }
    }

    private val eventObserver = object : MPVLib.EventObserver {
        override fun eventProperty(property: String) {}
        override fun eventProperty(property: String, value: Long) {}
        override fun eventProperty(property: String, value: Boolean) {
            if (property == "pause") {
                listener?.invoke(if (value) EVENT_PAUSED else EVENT_PLAYING)
            }
        }
        override fun eventProperty(property: String, value: String) {}
        override fun eventProperty(property: String, value: Double) {}
        override fun event(eventId: Int) {
            when (eventId) {
                MPVLib.MpvEvent.MPV_EVENT_FILE_LOADED -> listener?.invoke(EVENT_PLAYING)
                MPVLib.MpvEvent.MPV_EVENT_END_FILE -> listener?.invoke(EVENT_END_REACHED)
                MPVLib.MpvEvent.MPV_EVENT_PLAYBACK_RESTART -> listener?.invoke(EVENT_PLAYING)
            }
        }
    }

    fun play(url: String) {
        ensureInit()
        MPVLib.command(arrayOf("loadfile", url))
    }

    fun pause() {
        MPVLib.setPropertyBoolean("pause", true)
    }

    fun resume() {
        MPVLib.setPropertyBoolean("pause", false)
    }

    fun togglePlayPause() {
        val paused = MPVLib.getPropertyBoolean("pause") ?: false
        MPVLib.setPropertyBoolean("pause", !paused)
    }

    fun seekTo(ms: Long) {
        MPVLib.command(arrayOf("seek", "${ms / 1000.0}", "absolute"))
    }

    fun getPosition(): Long {
        return ((MPVLib.getPropertyDouble("time-pos") ?: 0.0) * 1000).toLong()
    }

    fun getDuration(): Long {
        return ((MPVLib.getPropertyDouble("duration") ?: 0.0) * 1000).toLong()
    }

    fun isPlaying(): Boolean {
        val paused = MPVLib.getPropertyBoolean("pause") ?: true
        return !paused
    }

    fun setVolume(percent: Int) {
        MPVLib.setPropertyInt("volume", percent)
    }

    fun release() {
        if (initialized) {
            MPVLib.removeObserver(eventObserver)
            MPVLib.destroy()
            initialized = false
        }
    }

    companion object {
        const val EVENT_PLAYING = 1
        const val EVENT_PAUSED = 2
        const val EVENT_END_REACHED = 3
    }
}
