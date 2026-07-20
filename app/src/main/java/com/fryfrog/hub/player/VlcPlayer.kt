package com.fryfrog.hub.player

import android.content.Context
import android.net.Uri
import android.view.SurfaceView
import org.videolan.libvlc.LibVLC
import org.videolan.libvlc.Media
import org.videolan.libvlc.MediaPlayer
import org.videolan.libvlc.interfaces.IVLCVout

class VlcPlayer(context: Context) {

    private val libVLC = LibVLC(context.applicationContext)
    private var mp: MediaPlayer? = null
    private var vlcVout: IVLCVout? = null
    private var listener: ((Int) -> Unit)? = null
    private var savedPosition: Long = 0L
    private var wasPlaying: Boolean = false

    fun setOnEventListener(listener: (eventType: Int) -> Unit) {
        this.listener = listener
    }

    fun attachSurface(surfaceView: SurfaceView, width: Int, height: Int) {
        val player = getOrCreatePlayer()

        vlcVout?.detachViews()
        vlcVout = player.vlcVout
        vlcVout?.setVideoSurface(surfaceView.holder.surface, surfaceView.holder)
        vlcVout?.setWindowSize(width, height)
        vlcVout?.attachViews()

        // 旋转后恢复播放
        if (wasPlaying && savedPosition > 0) {
            player.play()
            player.time = savedPosition
        }
    }

    fun detachSurface() {
        // 保存播放状态
        mp?.let {
            wasPlaying = it.isPlaying
            savedPosition = it.time
        }
        vlcVout?.detachViews()
    }

    fun open(url: String) {
        val player = getOrCreatePlayer()
        val media = Media(libVLC, Uri.parse(url))
        media.setHWDecoderEnabled(true, false)
        player.setMedia(media)
        media.release()
        player.play()
        savedPosition = 0L
        wasPlaying = true
    }

    fun play() {
        mp?.play()
        wasPlaying = true
    }

    fun pause() {
        mp?.pause()
        wasPlaying = false
    }

    fun togglePlayPause() {
        mp?.let {
            if (it.isPlaying) {
                it.pause()
                wasPlaying = false
            } else {
                it.play()
                wasPlaying = true
            }
        }
    }

    fun seekTo(ms: Long) {
        mp?.time = ms
    }

    fun getPosition(): Long = mp?.time ?: 0L
    fun getDuration(): Long = mp?.length ?: 0L
    fun isPlaying(): Boolean = mp?.isPlaying ?: false

    fun setVolume(percent: Int) {
        mp?.volume = percent
    }

    fun release() {
        mp?.setEventListener(null)
        vlcVout?.detachViews()
        mp?.stop()
        mp?.release()
        mp = null
        vlcVout = null
        libVLC.release()
    }

    private fun getOrCreatePlayer(): MediaPlayer {
        if (mp == null) {
            mp = MediaPlayer(libVLC).apply {
                setEventListener { event ->
                    listener?.invoke(event.type)
                }
            }
        }
        return mp!!
    }

    companion object {
        const val EVENT_PLAYING = MediaPlayer.Event.Playing
        const val EVENT_PAUSED = MediaPlayer.Event.Paused
        const val EVENT_END_REACHED = MediaPlayer.Event.EndReached
        const val EVENT_ERROR = MediaPlayer.Event.EncounteredError
        const val EVENT_BUFFERING = MediaPlayer.Event.Buffering
        const val EVENT_TIME_CHANGED = MediaPlayer.Event.TimeChanged
    }
}
