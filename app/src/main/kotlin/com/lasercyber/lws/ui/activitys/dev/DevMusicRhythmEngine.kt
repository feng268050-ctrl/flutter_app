package com.lasercyber.lws.ui.activitys.dev

import android.os.SystemClock
import com.lasercyber.lws.ui.activitys.dev.DevMusicPcmAnalyzer.BandEnergies
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow

/**
 * Stacked bar (bottom→top: 绿 / 黄 / 红).
 * Sustain height follows blended energy; beat pulse creates a cascading flash (−1 segment when dim).
 */
internal class DevMusicRhythmEngine {
    private val smooth = FloatArray(3)
    private val peak = FloatArray(3) { 1f }
    private var smoothTotal = 0f
    private var peakTotal = 1f
    private var sustainSegments = 0
    private var pulse = 0f
    private var bassAverage = 0f
    private var lastBeatElapsedMs = 0L
    private var lastSampleElapsedMs = 0L
    private var beatIntervalMs = 420f

    fun reset() {
        smooth.fill(0f)
        peak.fill(1f)
        smoothTotal = 0f
        peakTotal = 1f
        sustainSegments = 0
        pulse = 0f
        bassAverage = 0f
        lastBeatElapsedMs = 0L
        lastSampleElapsedMs = 0L
        beatIntervalMs = 420f
    }

    fun onBands(bands: BandEnergies, nowElapsedMs: Long = SystemClock.elapsedRealtime()): RhythmFrame {
        val dtMs = if (lastSampleElapsedMs > 0L) {
            (nowElapsedMs - lastSampleElapsedMs).coerceIn(1L, 120L)
        } else {
            33L
        }
        lastSampleElapsedMs = nowElapsedMs

        val raw = floatArrayOf(bands.bass, bands.mid, bands.high)
        for (i in 0..2) {
            smooth[i] = smooth[i] * SMOOTH_DECAY + raw[i] * (1f - SMOOTH_DECAY)
            peak[i] = max(max(peak[i] * PEAK_DECAY, smooth[i]), raw[i])
        }

        val total = smooth[0] * 0.48f + smooth[1] * 0.34f + smooth[2] * 0.18f
        smoothTotal = smoothTotal * TOTAL_SMOOTH_DECAY + total * (1f - TOTAL_SMOOTH_DECAY)
        peakTotal = max(peakTotal * TOTAL_PEAK_DECAY, smoothTotal, total)

        bassAverage = bassAverage * 0.9f + smooth[0] * 0.1f
        val bassFlux = max(0f, raw[0] - smooth[0])
        val sinceBeat = nowElapsedMs - lastBeatElapsedMs
        val beat = sinceBeat >= tempoMinBeatIntervalMs() &&
            (
                raw[0] > bassAverage * BEAT_BASS_RATIO + 35f ||
                    bassFlux > bassAverage * BEAT_FLUX_RATIO ||
                    total > smoothTotal * 1.28f
                )

        if (beat) {
            if (lastBeatElapsedMs > 0L) {
                val interval = sinceBeat.toFloat().coerceIn(MIN_BEAT_MS.toFloat(), MAX_BEAT_MS.toFloat())
                beatIntervalMs = beatIntervalMs * 0.6f + interval * 0.4f
            }
            lastBeatElapsedMs = nowElapsedMs
            pulse = 1f
        } else {
            pulse *= pulseDecayForTempo(dtMs)
        }

        sustainSegments = resolveSustainSegments(totalEnergyNorm())
        val litSegments = resolveLitSegments(sustainSegments, pulse)
        return RhythmFrame(
            litSegments = litSegments,
            pulseLevel = (pulse * 255f).toInt().coerceIn(0, 255),
            energyNorm = totalEnergyNorm(),
        )
    }

    private fun totalEnergyNorm(): Float {
        if (peakTotal <= 1f || smoothTotal < SILENCE_FLOOR) {
            return 0f
        }
        return (smoothTotal / peakTotal).coerceIn(0f, 1f).pow(ENERGY_CURVE_EXP)
    }

    private fun resolveSustainSegments(energyNorm: Float): Int {
        if (energyNorm < ACTIVE_FLOOR) {
            return 0
        }

        var target = when {
            energyNorm < TIER2_ENERGY -> 1
            energyNorm < TIER3_ENERGY -> 2
            else -> 3
        }

        val bassN = bandNorm(0)
        val midN = bandNorm(1)
        val highN = bandNorm(2)

        if (midN > 0.22f && target < 2) {
            target = 2
        }
        if (highN > 0.28f && target < 3) {
            target = 3
        }
        if (highN < 0.12f && target == 3) {
            target = 2
        }
        if (midN < 0.10f && target >= 2) {
            target = 1
        }

        val prev = sustainSegments
        if (prev > 0) {
            if (target > prev) {
                target = prev + 1
            } else if (target < prev) {
                target = prev - 1
            }
        }
        return target.coerceIn(0, 3)
    }

    private fun resolveLitSegments(sustain: Int, pulse: Float): Int {
        if (sustain <= 0) {
            return 0
        }
        return if (pulse > PULSE_BRIGHT_GATE) {
            sustain
        } else if (pulse > PULSE_DIM_GATE) {
            max(1, sustain - 1)
        } else {
            0
        }
    }

    private fun bandNorm(index: Int): Float {
        val p = peak[index]
        if (p <= 1f) {
            return 0f
        }
        return (smooth[index] / p).coerceIn(0f, 1f)
    }

    private fun tempoMinBeatIntervalMs(): Long {
        return (beatIntervalMs * 0.42f).toLong().coerceIn(MIN_BEAT_MS, MAX_BEAT_MS)
    }

    private fun pulseDecayForTempo(dtMs: Long): Float {
        val rate = when {
            beatIntervalMs < 300f -> FAST_DECAY
            beatIntervalMs < 450f -> MID_DECAY
            else -> SLOW_DECAY
        }
        return rate.pow(dtMs / 33f)
    }

    private fun max(a: Float, b: Float, c: Float): Float = max(max(a, b), c)

    data class RhythmFrame(
        val litSegments: Int,
        val pulseLevel: Int,
        val energyNorm: Float,
    )

    companion object {
        private const val SMOOTH_DECAY = 0.78f
        private const val PEAK_DECAY = 0.997f
        private const val TOTAL_SMOOTH_DECAY = 0.84f
        private const val TOTAL_PEAK_DECAY = 0.9985f
        private const val ENERGY_CURVE_EXP = 1.15f
        private const val SILENCE_FLOOR = 70f
        private const val ACTIVE_FLOOR = 0.06f

        private const val TIER2_ENERGY = 0.22f
        private const val TIER3_ENERGY = 0.50f

        private const val BEAT_BASS_RATIO = 1.45f
        private const val BEAT_FLUX_RATIO = 1.7f
        private const val PULSE_BRIGHT_GATE = 0.22f
        private const val PULSE_DIM_GATE = 0.06f
        private const val MIN_BEAT_MS = 120L
        private const val MAX_BEAT_MS = 900L
        private const val FAST_DECAY = 0.55f
        private const val MID_DECAY = 0.68f
        private const val SLOW_DECAY = 0.78f
    }
}
