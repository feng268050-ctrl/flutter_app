package com.lasercyber.lws.frostui.control

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.roundToInt

fun shouldShowFrostSliderZeroLabel(min: Int, max: Int): Boolean = min < 0 && max > 0

fun frostSliderThumbCenterX(
    fraction: Float,
    trackWidthPx: Float,
    thumbSizePx: Float,
): Float {
    val travel = trackWidthPx - thumbSizePx
    if (travel <= 0f) return trackWidthPx / 2f
    return thumbSizePx / 2f + travel * fraction.coerceIn(0f, 1f)
}

fun frostCapsuleThumbCenterX(
    fraction: Float,
    outerTrackWidthPx: Float,
    insetPx: Float,
    thumbSizePx: Float,
): Float {
    val innerWidth = outerTrackWidthPx - 2f * insetPx
    val travel = innerWidth - thumbSizePx
    if (travel <= 0f) return outerTrackWidthPx / 2f
    return insetPx + thumbSizePx / 2f + travel * fraction.coerceIn(0f, 1f)
}

fun frostSliderFractionFromX(
    x: Float,
    trackWidthPx: Float,
    thumbSizePx: Float,
    trackStartX: Float = 0f,
): Float {
    val travel = trackWidthPx - thumbSizePx
    if (travel <= 0f) return 0f
    val thumbLeft = (x - trackStartX - thumbSizePx / 2f).coerceIn(0f, travel)
    return thumbLeft / travel
}

/** Per-side padding so a scaled thumb (e.g. 1.3x) is not clipped by the slider bounds. */
fun frostSliderThumbDragOverflowPx(
    thumbRadiusPx: Float,
    dragScale: Float,
    minOverflowPx: Float = 0f,
): Float = max(thumbRadiusPx * (dragScale - 1f), minOverflowPx)

fun frostSliderResolvedThumbDragOverflowPx(
    thumbRadiusPx: Float,
    dragScale: Float,
    dimenOverflowPx: Float,
): Float = max(
    frostSliderThumbDragOverflowPx(thumbRadiusPx, dragScale),
    dimenOverflowPx,
)

fun frostSliderTravelPx(trackWidthPx: Float, thumbSizePx: Float): Float =
    (trackWidthPx - thumbSizePx).coerceAtLeast(0f)

fun frostCapsuleTravelPx(outerTrackWidthPx: Float, insetPx: Float, thumbSizePx: Float): Float {
    val innerWidth = outerTrackWidthPx - 2f * insetPx
    return (innerWidth - thumbSizePx).coerceAtLeast(0f)
}

fun frostSliderFractionFromDelta(
    restingFraction: Float,
    activationX: Float,
    currentX: Float,
    travelPx: Float,
): Float {
    if (travelPx <= 0f) return restingFraction.coerceIn(0f, 1f)
    val deltaFraction = (currentX - activationX) / travelPx
    return (restingFraction + deltaFraction).coerceIn(0f, 1f)
}

fun frostCapsuleSliderFractionFromX(
    x: Float,
    outerTrackWidthPx: Float,
    insetPx: Float,
    thumbSizePx: Float,
): Float {
    val innerWidth = outerTrackWidthPx - 2f * insetPx
    val travel = innerWidth - thumbSizePx
    if (travel <= 0f) return 0f
    val thumbLeft = (x - insetPx - thumbSizePx / 2f).coerceIn(0f, travel)
    return thumbLeft / travel
}

data class FrostSliderThumbHitRect(
    val left: Float,
    val top: Float,
    val right: Float,
    val bottom: Float,
)

fun frostSliderThumbHitRect(
    thumbCenterX: Float,
    touchHeightPx: Float,
    thumbRadiusPx: Float,
    minTouchHalfExtentPx: Float = thumbRadiusPx,
): FrostSliderThumbHitRect {
    val halfExtent = max(thumbRadiusPx, minTouchHalfExtentPx)
    val centerY = touchHeightPx / 2f
    return FrostSliderThumbHitRect(
        left = thumbCenterX - halfExtent,
        top = centerY - halfExtent,
        right = thumbCenterX + halfExtent,
        bottom = centerY + halfExtent,
    )
}

fun frostSliderThumbHitRectContains(
    x: Float,
    y: Float,
    rect: FrostSliderThumbHitRect,
): Boolean = x in rect.left..rect.right && y in rect.top..rect.bottom

fun frostSegmentWidthPx(trackWidthPx: Float, optionCount: Int): Float {
    if (optionCount <= 0 || !trackWidthPx.isFinite() || trackWidthPx <= 0f) return 0f
    return trackWidthPx / optionCount
}

fun frostSegmentPillOffsetPxFromX(
    x: Float,
    segmentWidthPx: Float,
    trackWidthPx: Float,
): Float {
    if (!x.isFinite() || segmentWidthPx <= 0f || !trackWidthPx.isFinite()) return 0f
    val maxOffset = (trackWidthPx - segmentWidthPx).coerceAtLeast(0f)
    return (x - segmentWidthPx / 2f).coerceIn(0f, maxOffset)
}

fun frostSegmentIndexAtX(
    x: Float,
    segmentWidthPx: Float,
    optionCount: Int,
): Int {
    if (!x.isFinite() || segmentWidthPx <= 0f || optionCount <= 0) return 0
    return (x / segmentWidthPx).toInt().coerceIn(0, optionCount - 1)
}

fun frostSegmentNearestIndex(
    pillOffsetXPx: Float,
    segmentWidthPx: Float,
    optionCount: Int,
): Int {
    if (!pillOffsetXPx.isFinite() || segmentWidthPx <= 0f || optionCount <= 0) return 0
    val pillCenterX = pillOffsetXPx + segmentWidthPx / 2f
    val normalizedIndex = (pillCenterX / segmentWidthPx) - 0.5f
    if (!normalizedIndex.isFinite()) return 0
    return normalizedIndex.roundToInt().coerceIn(0, optionCount - 1)
}

data class FrostSegmentSelectedHitRect(
    val left: Float,
    val top: Float,
    val right: Float,
    val bottom: Float,
)

fun frostSegmentSelectedHitRect(
    selectedIndex: Int,
    segmentWidthPx: Float,
    trackHeightPx: Float,
): FrostSegmentSelectedHitRect {
    val left = selectedIndex.coerceAtLeast(0) * segmentWidthPx
    return FrostSegmentSelectedHitRect(
        left = left,
        top = 0f,
        right = left + segmentWidthPx,
        bottom = trackHeightPx,
    )
}

fun frostSegmentSelectedHitRectContains(
    x: Float,
    y: Float,
    rect: FrostSegmentSelectedHitRect,
): Boolean = x in rect.left..rect.right && y in rect.top..rect.bottom

fun frostSegmentShouldCancelBeforeLongPress(deltaX: Float, touchSlop: Float): Boolean =
    abs(deltaX) > touchSlop

fun frostSegmentPreviewOffsetPx(
    restingOffsetPx: Float,
    activationX: Float,
    currentX: Float,
    segmentWidthPx: Float,
    trackWidthPx: Float,
): Float {
    if (!restingOffsetPx.isFinite() || segmentWidthPx <= 0f || !trackWidthPx.isFinite()) {
        return restingOffsetPx.coerceAtLeast(0f)
    }
    val maxOffset = (trackWidthPx - segmentWidthPx).coerceAtLeast(0f)
    return (restingOffsetPx + (currentX - activationX)).coerceIn(0f, maxOffset)
}

fun frostSegmentRestingOffsetPx(
    selectedIndex: Int,
    segmentWidthPx: Float,
): Float = selectedIndex.coerceAtLeast(0) * segmentWidthPx
