package com.fryfrog.hub.player

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Surface
import `is`.xyz.mpv.MPVLib
import kotlin.concurrent.Volatile

class MpvPlayer(private val context: Context) {

    private var listener: ((Int) -> Unit)? = null
    private var initialized = false
    private val handler = Handler(Looper.getMainLooper())

    companion object {
        private const val TAG = "MpvPlayer"
        const val EVENT_PLAYING = 1
        const val EVENT_PAUSED = 2
        const val EVENT_END_REACHED = 3
        const val EVENT_ERROR = 4
        const val EVENT_BUFFERING = 5
    }

    private val eventObserver = object : MPVLib.EventObserver {
        override fun eventProperty(property: String) {}
        override fun eventProperty(property: String, value: Long) {}
        override fun eventProperty(property: String, value: Boolean) {}
        override fun eventProperty(property: String, value: String) {}
        override fun eventProperty(property: String, value: Double) {}
        override fun event(eventId: Int) {
            Log.d(TAG, "mpv event: $eventId")
            when (eventId) {
                MPVLib.MpvEvent.MPV_EVENT_FILE_LOADED -> {
                    Log.d(TAG, "File loaded")
                    handler.post { listener?.invoke(EVENT_PLAYING) }
                }
                MPVLib.MpvEvent.MPV_EVENT_END_FILE -> {
                    Log.d(TAG, "End of file")
                    handler.post { listener?.invoke(EVENT_END_REACHED) }
                }
                MPVLib.MpvEvent.MPV_EVENT_SEEK -> {
                    Log.d(TAG, "Seek event")
                }
                MPVLib.MpvEvent.MPV_EVENT_PLAYBACK_RESTART -> {
                    Log.d(TAG, "Playback restart")
                    handler.post { listener?.invoke(EVENT_PLAYING) }
                }
                17 -> {
                    Log.d(TAG, "Video reconfig")
                }
                18 -> {
                    Log.d(TAG, "Audio reconfig")
                }
            }
        }
    }

    private val propertyObserver = object : MPVLib.EventObserver {
        override fun eventProperty(property: String) {
            Log.d(TAG, "Property changed: $property")
        }
        override fun eventProperty(property: String, value: Long) {
            Log.d(TAG, "Property $property = $value")
            when (property) {
                "pause" -> {
                    handler.post {
                        if (value == 1L) listener?.invoke(EVENT_PAUSED)
                        else listener?.invoke(EVENT_PLAYING)
                    }
                }
            }
        }
        override fun eventProperty(property: String, value: Boolean) {
            Log.d(TAG, "Property $property = $value")
            when (property) {
                "pause" -> {
                    handler.post {
                        if (value) listener?.invoke(EVENT_PAUSED)
                        else listener?.invoke(EVENT_PLAYING)
                    }
                }
            }
        }
        override fun eventProperty(property: String, value: String) {
            Log.d(TAG, "Property $property = $value")
        }
        override fun eventProperty(property: String, value: Double) {
            Log.d(TAG, "Property $property = $value")
        }
        override fun event(eventId: Int) {}
    }

    fun setOnEventListener(listener: (eventType: Int) -> Unit) {
        this.listener = listener
    }

    fun init() {
        Log.d(TAG, "init()")
        try {
            if (!initialized) {
                MPVLib.create(context)
                Log.d(TAG, "MPVLib.create() done")

                MPVLib.setOptionString("vo", "gpu-next")
                MPVLib.setOptionString("hwdec", "mediacodec-copy")
                MPVLib.setOptionString("hwdec-codecs", "h264,hevc,mpeg4,mpeg2video,vp8,vp9,av1")
                MPVLib.setOptionString("gpu-context", "android")
                MPVLib.setOptionString("opengl-es", "yes")
                MPVLib.setOptionString("force-window", "no")
                MPVLib.setOptionString("idle", "once")
                // Force SDR output on non-HDR displays
                MPVLib.setOptionString("target-prim", "bt.709")
                MPVLib.setOptionString("target-trc", "srgb")
                MPVLib.setOptionString("tone-mapping", "mobius")
                MPVLib.setOptionString("tone-mapping-max-boost", "2")
                MPVLib.setOptionString("gamut-mapping-mode", "clip")
                // Network buffering
                MPVLib.setOptionString("cache", "yes")
                MPVLib.setOptionString("cache-secs", "30")
                MPVLib.setOptionString("demuxer-max-bytes", "100MiB")
                MPVLib.setOptionString("demuxer-max-back-bytes", "50MiB")
                Log.d(TAG, "Options set")

                MPVLib.init()
                Log.d(TAG, "MPVLib.init() done")

                MPVLib.addObserver(eventObserver)
                MPVLib.observeProperty("pause", MPVLib.MpvFormat.MPV_FORMAT_FLAG)
                MPVLib.addObserver(propertyObserver)
                initialized = true
                Log.d(TAG, "init() completed successfully")
            }
        } catch (e: Exception) {
            Log.e(TAG, "init() failed", e)
        }
    }

    fun attachSurface(surface: Surface, width: Int, height: Int) {
        Log.d(TAG, "attachSurface($width x $height)")
        try {
            MPVLib.attachSurface(surface)
            MPVLib.setOptionString("force-window", "yes")
            MPVLib.setPropertyString("android-surface-size", "${width}x$height")
            Log.d(TAG, "attachSurface() done")
        } catch (e: Exception) {
            Log.e(TAG, "attachSurface() failed", e)
        }
    }

    fun detachSurface() {
        Log.d(TAG, "detachSurface()")
        try {
            MPVLib.setPropertyString("vo", "null")
            MPVLib.setPropertyString("force-window", "no")
            MPVLib.detachSurface()
        } catch (e: Exception) {
            Log.e(TAG, "detachSurface() failed", e)
        }
    }

    fun open(url: String) {
        Log.d(TAG, "open($url)")
        try {
            MPVLib.command(arrayOf("loadfile", url))
            Log.d(TAG, "loadfile command sent")
        } catch (e: Exception) {
            Log.e(TAG, "open() failed", e)
        }
    }

    fun play() {
        Log.d(TAG, "play()")
        MPVLib.setPropertyBoolean("pause", false)
    }

    fun pause() {
        Log.d(TAG, "pause()")
        MPVLib.setPropertyBoolean("pause", true)
    }

    fun togglePlayPause() {
        try {
            if (!initialized) return
            val paused = MPVLib.getPropertyBoolean("pause") ?: false
            Log.d(TAG, "togglePlayPause() paused=$paused")
            MPVLib.setPropertyBoolean("pause", !paused)
        } catch (e: Exception) {
            Log.e(TAG, "togglePlayPause() failed", e)
        }
    }

    fun seekTo(ms: Long) {
        Log.d(TAG, "seekTo($ms)")
        MPVLib.command(arrayOf("seek", "${ms / 1000.0}", "absolute"))
    }

    fun getPosition(): Long {
        return runOnMainThreadSync {
            try {
                if (!initialized) return@runOnMainThreadSync 0L
                ((MPVLib.getPropertyDouble("time-pos") ?: 0.0) * 1000).toLong()
            } catch (e: Exception) {
                Log.e(TAG, "getPosition() failed", e)
                0L
            }
        }
    }

    fun getDuration(): Long {
        return runOnMainThreadSync {
            try {
                if (!initialized) return@runOnMainThreadSync 0L
                ((MPVLib.getPropertyDouble("duration") ?: 0.0) * 1000).toLong()
            } catch (e: Exception) {
                Log.e(TAG, "getDuration() failed", e)
                0L
            }
        }
    }

    fun isPlaying(): Boolean {
        return runOnMainThreadSync {
            try {
                if (!initialized) return@runOnMainThreadSync false
                val paused = MPVLib.getPropertyBoolean("pause") ?: true
                !paused
            } catch (e: Exception) {
                Log.e(TAG, "isPlaying() failed", e)
                false
            }
        }
    }

    /**
     * 在主线程同步执行代码，确保 MPVLib 调用线程安全
     */
    private fun <T> runOnMainThreadSync(block: () -> T): T {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            return block()
        }
        var result: T? = null
        var error: Throwable? = null
        val latch = java.util.concurrent.CountDownLatch(1)
        handler.post {
            try {
                result = block()
            } catch (e: Throwable) {
                error = e
            } finally {
                latch.countDown()
            }
        }
        latch.await()
        error?.let { throw it }
        @Suppress("UNCHECKED_CAST")
        return result as T
    }

    fun setVolume(percent: Int) {
        MPVLib.setPropertyInt("volume", percent)
    }

    fun getPlaybackInfo(): PlaybackInfo {
        return try {
            val pixelFormat = MPVLib.getPropertyString("video-params/pixel_format") ?: ""
            val colorLevels = MPVLib.getPropertyString("video-params/colorlevels") ?: ""
            val colormatrix = MPVLib.getPropertyString("video-params/colormatrix") ?: ""
            val primaries = MPVLib.getPropertyString("video-params/primaries") ?: ""
            val gamma = MPVLib.getPropertyString("video-params/gamma") ?: ""
            val videoCodec = MPVLib.getPropertyString("video-codec") ?: ""
            val audioCodec = MPVLib.getPropertyString("audio-codec") ?: ""
            val audioParams = MPVLib.getPropertyString("audio-params") ?: ""
            val audioChannels = MPVLib.getPropertyString("audio-params/channels") ?: ""
            val audioSamplerate = MPVLib.getPropertyInt("audio-params/samplerate") ?: 0
            val hwDec = MPVLib.getPropertyString("hwdec-current") ?: ""

            // Get subtitle track info
            val subCount = MPVLib.getPropertyInt("track-list/count") ?: 0
            val subtitles = mutableListOf<TrackInfo>()
            val audios = mutableListOf<TrackInfo>()
            for (i in 0 until subCount) {
                val type = MPVLib.getPropertyString("track-list/$i/type") ?: ""
                val lang = MPVLib.getPropertyString("track-list/$i/lang") ?: ""
                val title = MPVLib.getPropertyString("track-list/$i/title") ?: ""
                val codec = MPVLib.getPropertyString("track-list/$i/codec") ?: ""
                val selected = MPVLib.getPropertyBoolean("track-list/$i/selected") ?: false
                when (type) {
                    "audio" -> audios.add(TrackInfo(i, type, lang, title, codec, selected))
                    "sub" -> subtitles.add(TrackInfo(i, type, lang, title, codec, selected))
                }
            }

            PlaybackInfo(
                player = "MPV",
                protocol = MPVLib.getPropertyString("protocol") ?: "",
                containerFormat = MPVLib.getPropertyString("file-format") ?: "",
                width = MPVLib.getPropertyInt("width") ?: 0,
                height = MPVLib.getPropertyInt("height") ?: 0,
                bitrate = MPVLib.getPropertyInt("bitrate") ?: 0,
                fps = MPVLib.getPropertyDouble("container-fps") ?: 0.0,
                videoCodec = videoCodec,
                pixelFormat = pixelFormat,
                colorLevels = colorLevels,
                colorMatrix = colormatrix,
                colorPrimaries = primaries,
                gamma = gamma,
                hwDec = hwDec,
                audioCodec = audioCodec,
                audioChannels = audioChannels,
                audioSampleRate = audioSamplerate,
                isHDR = primaries == "bt.2020" || gamma == "pq" || gamma == "hlg",
                isDolbyVision = videoCodec.contains("dv", ignoreCase = true),
                subtitleTracks = subtitles,
                audioTracks = audios
            )
        } catch (e: Exception) {
            Log.e(TAG, "getPlaybackInfo() failed", e)
            PlaybackInfo()
        }
    }

    fun getSubtitleText(): String? {
        return try {
            MPVLib.getPropertyString("sub-text")
        } catch (e: Exception) {
            null
        }
    }

    fun release() {
        Log.d(TAG, "release()")
        if (initialized) {
            MPVLib.removeObserver(eventObserver)
            MPVLib.removeObserver(propertyObserver)
            MPVLib.destroy()
            initialized = false
        }
    }

    data class TrackInfo(
        val index: Int,
        val type: String,
        val lang: String,
        val title: String,
        val codec: String,
        val selected: Boolean
    )

    data class PlaybackInfo(
        val player: String = "",
        val protocol: String = "",
        val containerFormat: String = "",
        val width: Int = 0,
        val height: Int = 0,
        val bitrate: Int = 0,
        val fps: Double = 0.0,
        val videoCodec: String = "",
        val pixelFormat: String = "",
        val colorLevels: String = "",
        val colorMatrix: String = "",
        val colorPrimaries: String = "",
        val gamma: String = "",
        val hwDec: String = "",
        val audioCodec: String = "",
        val audioChannels: String = "",
        val audioSampleRate: Int = 0,
        val isHDR: Boolean = false,
        val isDolbyVision: Boolean = false,
        val subtitleTracks: List<TrackInfo> = emptyList(),
        val audioTracks: List<TrackInfo> = emptyList()
    )
}
