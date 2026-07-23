package com.lasercyber.lws.ui.activitys.dev

import androidx.media3.common.C
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.nio.ShortBuffer
import kotlin.math.abs

/**
 * Low / mid / high band energies from PCM (time-domain split).
 * Maps to stacked bar: 绿(bass) → 黄(mid) → 红(high).
 */
internal object DevMusicPcmAnalyzer {

    data class BandEnergies(
        val bass: Float,
        val mid: Float,
        val high: Float,
    )

    private const val BASS_DECIMATE = 10

    fun measureBands(buffer: ByteBuffer, channelCount: Int, encoding: Int): BandEnergies {
        if (channelCount <= 0) {
            return BandEnergies(0f, 0f, 0f)
        }
        val frames = when (encoding) {
            C.ENCODING_PCM_16BIT -> readInt16MonoFrames(buffer, channelCount)
            C.ENCODING_PCM_FLOAT -> readFloatMonoFrames(buffer, channelCount).map { it * 32_768f }
            else -> emptyList()
        }
        return bandsFromFrames(frames)
    }

    private fun readInt16MonoFrames(buffer: ByteBuffer, channelCount: Int): List<Float> {
        val dup = buffer.duplicate().order(ByteOrder.LITTLE_ENDIAN)
        return readMonoFromShortBuffer(dup.asShortBuffer(), channelCount)
    }

    private fun readFloatMonoFrames(buffer: ByteBuffer, channelCount: Int): List<Float> {
        val dup = buffer.duplicate().order(ByteOrder.LITTLE_ENDIAN)
        return readMonoFromFloatBuffer(dup.asFloatBuffer(), channelCount)
    }

    private fun readMonoFromShortBuffer(samples: ShortBuffer, channelCount: Int): List<Float> {
        val sampleCount = samples.remaining()
        if (sampleCount < channelCount * 8) {
            return emptyList()
        }
        val frames = ArrayList<Float>(sampleCount / channelCount)
        var index = 0
        while (index < sampleCount) {
            var mono = 0
            for (channel in 0 until channelCount) {
                mono += samples.get(index + channel).toInt()
            }
            frames.add(mono / channelCount.toFloat())
            index += channelCount
        }
        return frames
    }

    private fun readMonoFromFloatBuffer(samples: FloatBuffer, channelCount: Int): List<Float> {
        val sampleCount = samples.remaining()
        if (sampleCount < channelCount * 8) {
            return emptyList()
        }
        val frames = ArrayList<Float>(sampleCount / channelCount)
        var index = 0
        while (index < sampleCount) {
            var mono = 0f
            for (channel in 0 until channelCount) {
                mono += samples.get(index + channel)
            }
            frames.add(mono / channelCount)
            index += channelCount
        }
        return frames
    }

    private fun bandsFromFrames(frames: List<Float>): BandEnergies {
        if (frames.size < 16) {
            return BandEnergies(0f, 0f, 0f)
        }
        var bassSum = 0.0
        var bassCount = 0
        var midSum = 0.0
        var highSum = 0.0
        var prev = frames[0]
        var prev2 = frames[0]

        frames.forEachIndexed { index, sample ->
            val absSample = abs(sample).toDouble()
            if (index % BASS_DECIMATE == 0) {
                bassSum += absSample
                bassCount++
            }
            if (index > 0) {
                midSum += abs(sample - prev).toDouble()
            }
            if (index > 1) {
                highSum += abs((sample - prev) - (prev - prev2)).toDouble()
            }
            prev2 = prev
            prev = sample
        }

        return BandEnergies(
            bass = (bassSum / maxOf(1, bassCount)).toFloat(),
            mid = (midSum / maxOf(1, frames.size - 1)).toFloat(),
            high = (highSum / maxOf(1, frames.size - 2)).toFloat(),
        )
    }
}
