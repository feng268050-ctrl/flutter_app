package com.lasercyber.lws.ui.activitys.dev

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.annotation.MainThread
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.audio.DefaultAudioSink
import androidx.media3.exoplayer.audio.TeeAudioProcessor
import com.lasercyber.lws.ui.R
import com.lasercyber.lws.ui.common.constant.LogTAGConstant
import com.lasercyber.lws.ui.common.gpio.LedIndicatorManager
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.max
data class DevMusicUiState(
    val trackFileName: String = DevMusicRhythmPlayer.TRACK_FILE_NAME,
    val isPrepared: Boolean = false,
    val isPlaying: Boolean = false,
    val positionMs: Long = 0L,
    val durationMs: Long = 0L,
    /** Lit segments 0–3, bottom→top G/Y/R */
    val barSegments: Int = 0,
    /** Beat pulse 0–255 for virtual meter */
    val pulseLevel: Int = 0,
    val analyzerActive: Boolean = false,
    /** System [android.media.AudioManager.STREAM_MUSIC] volume 0–100%. */
    val volumePercent: Int = 0,
)

/**
 * Dev-only: plays bundled MP3 via ExoPlayer and drives RGB GPIO from decoded PCM band energy.
 * Uses [TeeAudioProcessor] so privileged apps do not need Visualizer / RECORD_AUDIO.
 * Playback uses [C.USAGE_MEDIA]; volume is controlled via system [android.media.AudioManager].
 */
@OptIn(UnstableApi::class)
class DevMusicRhythmPlayer(
    context: Context,
    private val onUiState: (DevMusicUiState) -> Unit,
) {
    private val playbackContext = context
    private val mainHandler = Handler(Looper.getMainLooper())
    private val tag = LogTAGConstant.DevMusicRhythmPlayer

    private var player: ExoPlayer? = null
    private var uiState = DevMusicUiState()
    private var lastRhythmUpdateElapsedMs = 0L
    private val pcmFrameCount = AtomicLong(0L)

    @Volatile
    private var pcmChannelCount = 2
    @Volatile
    private var pcmEncoding = C.ENCODING_PCM_16BIT

    @Volatile
    private var rhythmAnalysisActive = false
    private val rhythmEngine = DevMusicRhythmEngine()
    private val pcmAnalysisExecutor: ExecutorService = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "dev-music-pcm").apply { isDaemon = true }
    }

    private val pcmSink = object : TeeAudioProcessor.AudioBufferSink {
        override fun flush(sampleRateHz: Int, channelCount: Int, encoding: Int) {
            pcmFrameCount.set(0L)
            pcmChannelCount = channelCount
            pcmEncoding = encoding
            pcmAnalysisExecutor.execute { rhythmEngine.reset() }
            Log.d(tag, "PCM sink flush rate=$sampleRateHz ch=$channelCount enc=$encoding")
        }

        override fun handleBuffer(buffer: ByteBuffer) {
            if (!rhythmAnalysisActive) {
                return
            }
            val byteCount = buffer.remaining()
            if (byteCount <= 0) {
                return
            }
            val pcmCopy = ByteArray(byteCount)
            buffer.asReadOnlyBuffer().get(pcmCopy)
            val channels = pcmChannelCount
            val encoding = pcmEncoding
            pcmAnalysisExecutor.execute {
                if (!rhythmAnalysisActive) {
                    return@execute
                }
                pcmFrameCount.incrementAndGet()
                val bands = DevMusicPcmAnalyzer.measureBands(
                    ByteBuffer.wrap(pcmCopy).order(ByteOrder.LITTLE_ENDIAN),
                    channels,
                    encoding,
                )
                val frame = rhythmEngine.onBands(bands)
                val now = SystemClock.elapsedRealtime()
                if (now - lastRhythmUpdateElapsedMs < RHYTHM_UPDATE_INTERVAL_MS) {
                    return@execute
                }
                lastRhythmUpdateElapsedMs = now
                LedIndicatorManager.setMusicReactiveBar(frame.litSegments)
                mainHandler.post {
                    publishUi(
                        barSegments = frame.litSegments,
                        pulseLevel = frame.pulseLevel,
                        analyzerActive = true,
                    )
                }
            }
        }
    }

    private val teeProcessor = TeeAudioProcessor(pcmSink)

    private val progressRunnable = object : Runnable {
        override fun run() {
            val p = player ?: return
            publishUi(
                positionMs = max(0L, p.currentPosition),
                durationMs = max(0L, p.duration),
                isPlaying = p.isPlaying,
                isPrepared = p.playbackState != Player.STATE_IDLE,
            )
            if (p.isPlaying) {
                mainHandler.postDelayed(this, PROGRESS_INTERVAL_MS)
            }
        }
    }

    private val playerListener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            val p = player ?: return
            when (playbackState) {
                Player.STATE_READY -> {
                    publishUi(
                        isPrepared = true,
                        durationMs = max(0L, p.duration),
                    )
                }
                Player.STATE_ENDED -> {
                    stopRhythmLeds()
                    publishUi(
                        isPlaying = false,
                        positionMs = max(0L, p.duration),
                        analyzerActive = false,
                    )
                    mainHandler.removeCallbacks(progressRunnable)
                }
            }
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            val p = player ?: return
            publishUi(
                isPlaying = isPlaying,
                analyzerActive = isPlaying && pcmFrameCount.get() > 0L,
            )
            if (isPlaying) {
                rhythmAnalysisActive = true
                LedIndicatorManager.enterMusicReactiveMode()
                mainHandler.removeCallbacks(progressRunnable)
                mainHandler.post(progressRunnable)
            } else if (!p.playWhenReady) {
                rhythmAnalysisActive = false
                mainHandler.removeCallbacks(progressRunnable)
                publishUi(
                    positionMs = p.currentPosition,
                    analyzerActive = false,
                )
            }
        }

        override fun onPlayerError(error: PlaybackException) {
            Log.e(tag, "Playback failed: ${error.errorCodeName} ${error.message}", error)
            rhythmAnalysisActive = false
            stopRhythmLeds()
            publishUi(isPlaying = false, analyzerActive = false)
        }

        override fun onPlaybackSuppressionReasonChanged(playbackSuppressionReason: Int) {
            if (playbackSuppressionReason != Player.PLAYBACK_SUPPRESSION_REASON_NONE) {
                Log.w(tag, "Playback suppressed reason=$playbackSuppressionReason")
            }
        }
    }

    @MainThread
    fun prepare() {
        if (player != null) {
            return
        }
        val uri = Uri.parse("android.resource://${playbackContext.packageName}/${R.raw.shanghai_tan}")
        val renderersFactory = object : DefaultRenderersFactory(playbackContext) {
            override fun buildAudioSink(
                context: Context,
                enableFloatOutput: Boolean,
                enableAudioTrackPlaybackParams: Boolean,
            ): AudioSink {
                return DefaultAudioSink.Builder(context)
                    .setEnableFloatOutput(false)
                    .setEnableAudioTrackPlaybackParams(enableAudioTrackPlaybackParams)
                    .setAudioProcessors(arrayOf(teeProcessor))
                    .build()
            }
        }
        val audioAttributes = devMusicAudioAttributes()
        player = ExoPlayer.Builder(playbackContext)
            .setRenderersFactory(renderersFactory)
            .setSuppressPlaybackOnUnsuitableOutput(false)
            .build()
            .apply {
                setAudioAttributes(audioAttributes, /* handleAudioFocus= */ false)
                setMediaItem(MediaItem.fromUri(uri))
                addListener(playerListener)
                volume = 1f
                prepare()
            }
        publishUi(
            isPrepared = false,
            isPlaying = false,
            positionMs = 0L,
            durationMs = 0L,
            analyzerActive = false,
        )
        Log.d(tag, "ExoPlayer prepared usage=${audioAttributes.usage} with PCM tee")
    }

    @MainThread
    fun togglePlayPause() {
        val p = player ?: run {
            prepare()
            player
        } ?: return
        if (p.playbackState == Player.STATE_ENDED) {
            p.seekTo(0L)
            rhythmEngine.reset()
            pcmFrameCount.set(0L)
        }
        if (p.isPlaying) {
            p.pause()
            rhythmAnalysisActive = false
            stopRhythmLeds()
        } else {
            rhythmAnalysisActive = true
            LedIndicatorManager.enterMusicReactiveMode()
            p.play()
        }
    }

    @MainThread
    fun stop() {
        rhythmAnalysisActive = false
        stopRhythmLeds()
        player?.run {
            pause()
            seekTo(0L)
        }
        rhythmEngine.reset()
        pcmFrameCount.set(0L)
        mainHandler.removeCallbacks(progressRunnable)
        publishUi(
            isPlaying = false,
            positionMs = 0L,
            barSegments = 0,
            pulseLevel = 0,
            analyzerActive = false,
        )
    }

    @MainThread
    fun seekBack() {
        val p = player ?: return
        if (p.duration <= 0L) {
            return
        }
        p.seekBack()
        publishUi(positionMs = p.currentPosition)
    }

    @MainThread
    fun seekForward() {
        val p = player ?: return
        if (p.duration <= 0L) {
            return
        }
        p.seekForward()
        publishUi(positionMs = p.currentPosition)
    }

    @MainThread
    fun seekTo(positionMs: Long) {
        player?.seekTo(positionMs.coerceAtLeast(0L))
        publishUi(positionMs = positionMs)
    }

    @MainThread
    fun release() {
        mainHandler.removeCallbacks(progressRunnable)
        rhythmAnalysisActive = false
        stopRhythmLeds()
        player?.run {
            removeListener(playerListener)
            release()
        }
        player = null
        rhythmEngine.reset()
        pcmFrameCount.set(0L)
        pcmAnalysisExecutor.shutdownNow()
        publishUi(
            isPrepared = false,
            isPlaying = false,
            positionMs = 0L,
            durationMs = 0L,
            barSegments = 0,
            pulseLevel = 0,
            analyzerActive = false,
        )
    }

    private fun stopRhythmLeds() {
        LedIndicatorManager.leaveMusicReactiveMode()
    }

    private fun publishUi(
        trackFileName: String = uiState.trackFileName,
        isPrepared: Boolean = uiState.isPrepared,
        isPlaying: Boolean = uiState.isPlaying,
        positionMs: Long = uiState.positionMs,
        durationMs: Long = uiState.durationMs,
        barSegments: Int = uiState.barSegments,
        pulseLevel: Int = uiState.pulseLevel,
        analyzerActive: Boolean = uiState.analyzerActive,
        volumePercent: Int = uiState.volumePercent,
    ) {
        uiState = DevMusicUiState(
            trackFileName = trackFileName,
            isPrepared = isPrepared,
            isPlaying = isPlaying,
            positionMs = positionMs,
            durationMs = durationMs,
            barSegments = barSegments,
            pulseLevel = pulseLevel,
            analyzerActive = analyzerActive,
            volumePercent = volumePercent,
        )
        onUiState(uiState)
    }

    companion object {
        const val TRACK_FILE_NAME = "shanghai_tan.mp3"
        private const val PROGRESS_INTERVAL_MS = 250L
        private const val RHYTHM_UPDATE_INTERVAL_MS = 33L

        /** [C.USAGE_MEDIA] routes to [android.media.AudioManager.STREAM_MUSIC] for system volume. */
        fun devMusicAudioAttributes(): AudioAttributes = AudioAttributes.Builder()
            .setUsage(C.USAGE_MEDIA)
            .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
            .build()
    }
}
