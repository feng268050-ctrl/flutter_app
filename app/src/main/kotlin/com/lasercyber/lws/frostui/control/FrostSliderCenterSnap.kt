package com.lasercyber.lws.frostui.control

import kotlin.math.abs

data class FrostSliderCenterSnapConfig(
    val centerValue: Int,
    val threshold: Int,
    val escapeDistancePx: Float,
    val dwellMs: Long,
    val centerFraction: Float,
)

class FrostSliderCenterSnapSession {
    var isCenterSnapped: Boolean = false
    var snapAnchorX: Float = Float.NaN
    var snapEnteredAtMs: Long = 0L
    var dragRestingFraction: Float = Float.NaN
    /** After escaping center snap, suppress re-entry until raw value leaves the threshold band. */
    var centerSnapSuppressed: Boolean = false

    fun reset(restingFraction: Float) {
        isCenterSnapped = false
        snapAnchorX = Float.NaN
        snapEnteredAtMs = 0L
        centerSnapSuppressed = false
        dragRestingFraction = restingFraction
    }

    fun clear() {
        isCenterSnapped = false
        snapAnchorX = Float.NaN
        snapEnteredAtMs = 0L
        centerSnapSuppressed = false
        dragRestingFraction = Float.NaN
    }
}

data class FrostSliderDragResolveResult(
    val fraction: Float,
    val value: Int,
    val isCenterSnapped: Boolean,
    val reanchorActivationX: Float? = null,
    val enteredCenterSnap: Boolean = false,
)

fun frostSliderCenterSnapConfig(
    min: Int,
    max: Int,
    centerValue: Int,
    threshold: Int,
    escapeDistancePx: Float,
    dwellMs: Long,
): FrostSliderCenterSnapConfig? {
    if (max == min || min >= centerValue || max <= centerValue) return null
    return FrostSliderCenterSnapConfig(
        centerValue = centerValue,
        threshold = threshold,
        escapeDistancePx = escapeDistancePx,
        dwellMs = dwellMs,
        centerFraction = (centerValue - min).toFloat() / (max - min),
    )
}

fun frostSliderResolveDragValue(
    snapConfig: FrostSliderCenterSnapConfig?,
    snapSession: FrostSliderCenterSnapSession,
    min: Int,
    max: Int,
    travelPx: Float,
    activationX: Float,
    currentX: Float,
    nowMs: Long,
): FrostSliderDragResolveResult {
    val restingFraction = snapSession.dragRestingFraction
    val rawFraction = frostSliderFractionFromDelta(
        restingFraction = restingFraction,
        activationX = activationX,
        currentX = currentX,
        travelPx = travelPx,
    )
    val rawValue = frostSliderProgressFromFraction(rawFraction, min, max)

    if (snapConfig == null) {
        snapSession.isCenterSnapped = false
        return FrostSliderDragResolveResult(
            fraction = rawFraction,
            value = rawValue,
            isCenterSnapped = false,
        )
    }

    if (snapSession.isCenterSnapped) {
        val escaped = abs(currentX - snapSession.snapAnchorX) > snapConfig.escapeDistancePx
        if (escaped) {
            snapSession.isCenterSnapped = false
            snapSession.centerSnapSuppressed = true
            val escapedFraction = frostSliderFractionFromDelta(
                restingFraction = snapConfig.centerFraction,
                activationX = snapSession.snapAnchorX,
                currentX = currentX,
                travelPx = travelPx,
            )
            val escapedValue = frostSliderProgressFromFraction(escapedFraction, min, max)
            snapSession.dragRestingFraction = escapedFraction
            return FrostSliderDragResolveResult(
                fraction = escapedFraction,
                value = escapedValue,
                isCenterSnapped = false,
                reanchorActivationX = currentX,
            )
        }
        return FrostSliderDragResolveResult(
            fraction = snapConfig.centerFraction,
            value = snapConfig.centerValue,
            isCenterSnapped = true,
        )
    }

    if (snapSession.centerSnapSuppressed &&
        abs(rawValue - snapConfig.centerValue) > snapConfig.threshold
    ) {
        snapSession.centerSnapSuppressed = false
    }

    if (!snapSession.centerSnapSuppressed &&
        abs(rawValue - snapConfig.centerValue) <= snapConfig.threshold
    ) {
        snapSession.isCenterSnapped = true
        snapSession.snapAnchorX = currentX
        snapSession.snapEnteredAtMs = nowMs
        return FrostSliderDragResolveResult(
            fraction = snapConfig.centerFraction,
            value = snapConfig.centerValue,
            isCenterSnapped = true,
            enteredCenterSnap = true,
        )
    }

    return FrostSliderDragResolveResult(
        fraction = rawFraction,
        value = rawValue,
        isCenterSnapped = false,
    )
}

internal fun applyFrostSliderDragResolve(
    dragState: FrostSliderLongPressDragState,
    snapConfig: FrostSliderCenterSnapConfig?,
    snapSession: FrostSliderCenterSnapSession,
    min: Int,
    max: Int,
    travelPx: Float,
    activationX: Float,
    currentX: Float,
    nowMs: Long,
    onProgressChange: (Int, Boolean) -> Unit,
): Float? {
    if (!dragState.isValueArmed) return null
    val result = frostSliderResolveDragValue(
        snapConfig = snapConfig,
        snapSession = snapSession,
        min = min,
        max = max,
        travelPx = travelPx,
        activationX = activationX,
        currentX = currentX,
        nowMs = nowMs,
    )
    dragState.dragFraction = result.fraction
    dragState.isCenterSnapped = result.isCenterSnapped
    onProgressChange(result.value, true)
    return result.reanchorActivationX
}
