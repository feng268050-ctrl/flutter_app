package com.lasercyber.lws.ui.common.audio

import android.content.Context
import android.media.AudioManager
import android.util.Log
import androidx.media3.common.C
import com.innohi.PropertyUtil
import com.innohi.YNHAPI
import com.lasercyber.lws.ui.common.constant.LogTAGConstant
import kotlin.jvm.JvmStatic
import kotlin.math.roundToInt

/**
 * Dev / music playback volume via Android stream volume APIs, with best-effort Innohi fallback.
 *
 * The vendored [YNHAPI] JAR (20250310) has no documented volume methods; reflection and
 * property keys are attempted only when [AudioManager.setStreamVolume] fails.
 */
object MusicPlaybackVolume {

    private const val TAG = LogTAGConstant.DevMusicRhythmPlayer

    /** Matches [androidx.media3.common.util.Util.getStreamTypeForAudioUsage] for [C.USAGE_MEDIA]. */
    @JvmStatic
    fun playbackStreamType(): Int = AudioManager.STREAM_MUSIC

    @JvmStatic
    fun getVolumePercent(context: Context): Int {
        readAndroidVolumePercent(context)?.let { return it }
        readYnhVolumePercent()?.let { return it }
        return 0
    }

    @JvmStatic
    fun setVolumePercent(context: Context, percent: Int): Boolean {
        val clamped = percent.coerceIn(0, 100)
        if (setAndroidVolumePercent(context, clamped)) {
            return true
        }
        if (setYnhVolumePercent(clamped)) {
            return true
        }
        Log.w(TAG, "setVolumePercent failed percent=$clamped")
        return false
    }

    private fun readAndroidVolumePercent(context: Context): Int? {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return null
        val streamType = playbackStreamType()
        val max = audioManager.getStreamMaxVolume(streamType)
        if (max <= 0) {
            return null
        }
        val current = audioManager.getStreamVolume(streamType)
        return (current * 100f / max.toFloat()).roundToInt().coerceIn(0, 100)
    }

    private fun setAndroidVolumePercent(context: Context, percent: Int): Boolean {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return false
        val streamType = playbackStreamType()
        val max = audioManager.getStreamMaxVolume(streamType)
        if (max <= 0) {
            return false
        }
        val index = (percent / 100f * max.toFloat()).roundToInt().coerceIn(0, max)
        return try {
            audioManager.setStreamVolume(streamType, index, /* flags= */ 0)
            true
        } catch (error: SecurityException) {
            Log.w(TAG, "setStreamVolume denied stream=$streamType index=$index", error)
            false
        }
    }

    private fun readYnhVolumePercent(): Int? {
        if (!isYnhApiAvailable()) {
            return null
        }
        return readYnhVolumeViaReflection() ?: readYnhVolumeViaProperties()
    }

    private fun setYnhVolumePercent(percent: Int): Boolean {
        if (!isYnhApiAvailable()) {
            return false
        }
        return setYnhVolumeViaReflection(percent) || setYnhVolumeViaProperties(percent)
    }

    private fun isYnhApiAvailable(): Boolean = try {
        YNHAPI.getInstance()
        true
    } catch (_: Throwable) {
        false
    }

    private fun readYnhVolumeViaReflection(): Int? {
        val api = try {
            YNHAPI.getInstance()
        } catch (_: Throwable) {
            return null
        }
        val raw = invokeYnhVolumeGetter(api) ?: invokeYnhVolumeGetter(YNHAPI::class.java)
        return raw?.let { normalizeYnhVolumeToPercent(it) }
    }

    private fun setYnhVolumeViaReflection(percent: Int): Boolean {
        val api = try {
            YNHAPI.getInstance()
        } catch (_: Throwable) {
            return false
        }
        val scaledValues = listOf(percent, percentToYnhScale(percent))
        for (value in scaledValues) {
            if (invokeYnhVolumeSetter(api, value)) {
                Log.d(TAG, "YNH volume set via reflection value=$value")
                return true
            }
            if (invokeYnhVolumeSetter(YNHAPI::class.java, value)) {
                Log.d(TAG, "YNH static volume set via reflection value=$value")
                return true
            }
        }
        return false
    }

    private fun invokeYnhVolumeGetter(target: Any): Int? {
        val names = listOf(
            "getSystemVolume",
            "getVolume",
            "getMediaVolume",
            "getAudioVolume",
            "System_getVolume",
        )
        for (name in names) {
            val method = target.javaClass.methods.firstOrNull { it.name == name && it.parameterCount == 0 }
                ?: continue
            val result = runCatching { method.invoke(target) }.getOrNull() ?: continue
            when (result) {
                is Int -> return result
                is Number -> return result.toInt()
            }
        }
        return null
    }

    private fun invokeYnhVolumeSetter(target: Any, value: Int): Boolean {
        val signatures = listOf(
            arrayOf(value),
            arrayOf(value, playbackStreamType()),
            arrayOf(playbackStreamType(), value),
        )
        val names = listOf(
            "setSystemVolume",
            "setVolume",
            "setMediaVolume",
            "setAudioVolume",
            "System_setVolume",
        )
        for (name in names) {
            for (args in signatures) {
                val method = target.javaClass.methods.firstOrNull { candidate ->
                    candidate.name == name && candidate.parameterCount == args.size
                } ?: continue
                if (runCatching { method.invoke(target, *args) }.isSuccess) {
                    return true
                }
            }
        }
        return false
    }

    private fun readYnhVolumeViaProperties(): Int? {
        for (key in YNH_VOLUME_PROPERTY_KEYS) {
            val raw = runCatching { PropertyUtil.get(key, "") }.getOrNull()?.trim().orEmpty()
            if (raw.isEmpty()) {
                continue
            }
            raw.toIntOrNull()?.let { return normalizeYnhVolumeToPercent(it) }
        }
        return null
    }

    private fun setYnhVolumeViaProperties(percent: Int): Boolean {
        var wrote = false
        for (key in YNH_VOLUME_PROPERTY_KEYS) {
            wrote = runCatching {
                PropertyUtil.set(key, percentToYnhScale(percent).toString())
            }.isSuccess || wrote
        }
        if (wrote) {
            Log.d(TAG, "YNH volume set via PropertyUtil percent=$percent")
        }
        return wrote
    }

    private fun normalizeYnhVolumeToPercent(raw: Int): Int {
        return when {
            raw in 0..100 -> raw
            raw in 0..15 -> (raw * 100f / 15f).roundToInt().coerceIn(0, 100)
            raw in 0..255 -> (raw * 100f / 255f).roundToInt().coerceIn(0, 100)
            else -> raw.coerceIn(0, 100)
        }
    }

    private fun percentToYnhScale(percent: Int): Int {
        return (percent * 15f / 100f).roundToInt().coerceIn(0, 15)
    }

    private val YNH_VOLUME_PROPERTY_KEYS = listOf(
        "persist.sys.media_volume",
        "persist.sys.system_volume",
        "persist.sys.audio.volume",
        "sys.audio.volume",
    )
}
