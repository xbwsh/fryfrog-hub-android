package com.fryfrog.hub.player

import android.content.Context
import android.net.Uri
import org.videolan.libvlc.LibVLC
import org.videolan.libvlc.Media
import org.videolan.libvlc.MediaPlayer

class MusicPlayer(context: Context) {

    private val libVLC = LibVLC(context.applicationContext)
    private var mp: MediaPlayer? = null
    private var listener: ((Int) -> Unit)? = null

    fun setOnEventListener(listener: (eventType: Int) -> Unit) {
        this.listener = listener
    }

    fun play(url: String) {
        mp?.stop()
        mp?.release()

        val media = Media(libVLC, Uri.parse(url))
        mp = MediaPlayer(libVLC).apply {
            setEventListener { event -> listener?.invoke(event.type) }
            setMedia(media)
            play()
        }
        media.release()
    }

    fun pause() { mp?.pause() }
    fun resume() { mp?.play() }
    fun togglePlayPause() { mp?.let { if (it.isPlaying) it.pause() else it.play() } }
    fun seekTo(ms: Long) { mp?.time = ms }
    fun getPosition(): Long = mp?.time ?: 0L
    fun getDuration(): Long = mp?.length ?: 0L
    fun isPlaying(): Boolean = mp?.isPlaying ?: false
    fun setVolume(percent: Int) { mp?.volume = percent }

    fun release() {
        mp?.setEventListener(null)
        mp?.stop()
        mp?.release()
        mp = null
        libVLC.release()
    }

    companion object {
        const val EVENT_PLAYING = MediaPlayer.Event.Playing
        const val EVENT_PAUSED = MediaPlayer.Event.Paused
        const val EVENT_END_REACHED = MediaPlayer.Event.EndReached
    }
}
