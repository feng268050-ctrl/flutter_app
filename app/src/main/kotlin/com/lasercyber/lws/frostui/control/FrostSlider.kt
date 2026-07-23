package com.lasercyber.lws.frostui.control

import android.os.SystemClock
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import kotlin.math.roundToInt

/** Horizontal inset from [FrostSlider] content edge to the drawable track. */
@Composable
fun rememberFrostSliderTrackHorizontalInset(
    appearance: FrostSliderAppearance,
    longPressDragEnabled: Boolean = true,
    reserveThumbOverflow: Boolean = false,
): Dp {
    if (!reserveThumbOverflow) {
        return 0.dp
    }
    val context = LocalContext.current
    val density = LocalDensity.current
    return remember(appearance, longPressDragEnabled, reserveThumbOverflow, density) {
        val thumbPx = with(density) { appearance.thumbSize.toPx() }
        val thumbRadius = thumbPx / 2f
        val thumbDragScale = if (longPressDragEnabled) {
            FrostControlDimens.sliderThumbDragScale(context)
        } else {
            1f
        }
        val dimenOverflowPx = with(density) { FrostControlDimens.sliderThumbDragOverflow(context).toPx() }
        val overflowPx = frostSliderResolvedThumbDragOverflowPx(thumbRadius, thumbDragScale, dimenOverflowPx)
        with(density) { overflowPx.toDp() }
    }
}

@Composable
private fun rememberFrostSliderThumbOverflowPx(
    appearance: FrostSliderAppearance,
    longPressDragEnabled: Boolean,
    reserveThumbOverflow: Boolean,
): Float {
    if (!reserveThumbOverflow) {
        return 0f
    }
    val context = LocalContext.current
    val density = LocalDensity.current
    return remember(appearance, longPressDragEnabled, reserveThumbOverflow, density) {
        val thumbPx = with(density) { appearance.thumbSize.toPx() }
        val thumbRadius = thumbPx / 2f
        val thumbDragScale = if (longPressDragEnabled) {
            FrostControlDimens.sliderThumbDragScale(context)
        } else {
            1f
        }
        val dimenOverflowPx = with(density) { FrostControlDimens.sliderThumbDragOverflow(context).toPx() }
        frostSliderResolvedThumbDragOverflowPx(thumbRadius, thumbDragScale, dimenOverflowPx)
    }
}

fun frostSliderProgressFromFraction(fraction: Float, min: Int, max: Int): Int {
    if (max == min) return min
    return (min + fraction.coerceIn(0f, 1f) * (max - min)).roundToInt().coerceIn(min, max)
}

@Composable
fun FrostSlider(
    progress: Int,
    onProgressChange: (Int, Boolean) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    min: Int = 0,
    max: Int = 100,
    scaleMinText: String? = null,
    scaleMaxText: String? = null,
    scaleZeroText: String = "0",
    appearance: FrostSliderAppearance,
    longPressDragEnabled: Boolean = true,
    reserveThumbOverflow: Boolean = false,
    onStartTracking: (() -> Unit)? = null,
    onStopTracking: ((cancelled: Boolean) -> Unit)? = null,
) {
    val context = LocalContext.current
    val density = LocalDensity.current
    val thumbPx = with(density) { appearance.thumbSize.toPx() }
    val thumbRadius = thumbPx / 2f
    val minTouchHalfExtentPx = with(density) { 24.dp.toPx() }
    val longPressThresholdMs = FrostControlDimens.sliderLongPressThresholdMs(context)
    val thumbDragScale = FrostControlDimens.sliderThumbDragScale(context)
    val overflowPx = rememberFrostSliderThumbOverflowPx(
        appearance = appearance,
        longPressDragEnabled = longPressDragEnabled,
        reserveThumbOverflow = reserveThumbOverflow,
    )
    val overflowDp = with(density) { overflowPx.toDp() }
    val dragState = rememberFrostSliderLongPressDragState()
    val snapSession = remember { FrostSliderCenterSnapSession() }
    val centerSnapConfig = remember(min, max) {
        if (longPressDragEnabled) FrostControlDimens.sliderCenterSnapConfig(context, min, max) else null
    }
    val thumbScale = if (longPressDragEnabled) {
        frostSliderThumbDragScale(dragState.isThumbExpanded, thumbDragScale)
    } else {
        1f
    }

    val restingFraction = if (max == min) 0f else (progress - min).toFloat() / (max - min)
    val displayFraction = if (dragState.isValueArmed && !dragState.dragFraction.isNaN()) {
        dragState.dragFraction
    } else {
        restingFraction
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .frostSliderDrawUnclipped(),
    ) {
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxWidth()
                .height(appearance.touchHeight + overflowDp * 2)
                .frostSliderDrawUnclipped(),
        ) {
            val outerWidthPx = with(density) { maxWidth.toPx() }
            val outerHeightPx = with(density) { maxHeight.toPx() }
            val trackWidthPx = outerWidthPx - 2f * overflowPx
            val trackStartX = overflowPx
            val travelPx = frostSliderTravelPx(trackWidthPx, thumbPx)
            val thumbCenterX = trackStartX + frostSliderThumbCenterX(displayFraction, trackWidthPx, thumbPx)
            val scaledThumbRadius = thumbRadius * thumbScale

            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .frostSliderDrawUnclipped()
                    .then(
                        if (longPressDragEnabled) {
                            Modifier.frostSliderLongPressDragGesture(
                                enabled = enabled,
                                longPressThresholdMs = longPressThresholdMs,
                                thumbCenterX = trackStartX + frostSliderThumbCenterX(restingFraction, trackWidthPx, thumbPx),
                                touchHeightPx = outerHeightPx,
                                thumbRadiusPx = thumbRadius,
                                minTouchHalfExtentPx = minTouchHalfExtentPx,
                                state = dragState,
                                onThumbExpand = {
                                    onStartTracking?.invoke()
                                    snapSession.reset(restingFraction)
                                    dragState.dragFraction = restingFraction
                                },
                                onValueChangeWhileArmed = { activationX, x ->
                                    applyFrostSliderDragResolve(
                                        dragState = dragState,
                                        snapConfig = centerSnapConfig,
                                        snapSession = snapSession,
                                        min = min,
                                        max = max,
                                        travelPx = travelPx,
                                        activationX = activationX,
                                        currentX = x,
                                        nowMs = SystemClock.uptimeMillis(),
                                        onProgressChange = onProgressChange,
                                    )
                                },
                                onRelease = { cancelled ->
                                    snapSession.clear()
                                    onStopTracking?.invoke(cancelled)
                                },
                            )
                        } else {
                            Modifier.frostSliderDirectDragGesture(
                                enabled = enabled,
                                state = dragState,
                                onDragStart = {
                                    onStartTracking?.invoke()
                                },
                                onDragPositionX = { x ->
                                    val fraction = frostSliderFractionFromX(
                                        x = x,
                                        trackWidthPx = trackWidthPx,
                                        thumbSizePx = thumbPx,
                                        trackStartX = trackStartX,
                                    )
                                    dragState.dragFraction = fraction
                                    onProgressChange(
                                        frostSliderProgressFromFraction(fraction, min, max),
                                        true,
                                    )
                                },
                                onRelease = { cancelled ->
                                    onStopTracking?.invoke(cancelled)
                                },
                            )
                        },
                    ),
            ) {
                Canvas(modifier = Modifier.fillMaxSize()) {
                    val trackHeightPx = appearance.trackHeight.toPx()
                    val trackTop = (size.height - trackHeightPx) / 2f
                    drawFrostSliderTrack(
                        trackStartX = trackStartX,
                        trackWidthPx = trackWidthPx,
                        trackHeightPx = trackHeightPx,
                        trackTop = trackTop,
                        trackCornerRadiusPx = appearance.trackCornerRadius.toPx(),
                        inactiveColor = appearance.trackInactiveColor,
                        activeColor = appearance.trackActiveColor,
                        thumbCenterX = thumbCenterX,
                    )
                }
                Canvas(
                    modifier = Modifier
                        .fillMaxSize()
                        .frostSliderDrawUnclipped(),
                ) {
                    drawFrostSliderThumb(
                        centerX = thumbCenterX,
                        centerY = size.height / 2f,
                        thumbRadiusPx = scaledThumbRadius,
                        thumbColor = appearance.thumbColor,
                    )
                }
            }
        }

        if (scaleMinText != null || scaleMaxText != null || shouldShowFrostSliderZeroLabel(min, max)) {
            BoxWithConstraints(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = overflowDp),
            ) {
                val trackWidthPx = with(density) { maxWidth.toPx() }
                val trackStartX = 0f
                val showZero = shouldShowFrostSliderZeroLabel(min, max)
                val zeroCenterX = if (showZero && trackWidthPx > thumbPx) {
                    trackStartX + frostSliderThumbCenterX(
                        fraction = (0f - min) / (max - min).toFloat(),
                        trackWidthPx = trackWidthPx,
                        thumbSizePx = thumbPx,
                    )
                } else {
                    0f
                }

                if (scaleMinText != null) {
                    Text(
                        text = scaleMinText,
                        color = appearance.labelColor,
                        fontSize = appearance.labelSize,
                        modifier = Modifier.align(Alignment.CenterStart),
                    )
                }
                if (scaleMaxText != null) {
                    Text(
                        text = scaleMaxText,
                        color = appearance.labelColor,
                        fontSize = appearance.labelSize,
                        modifier = Modifier.align(Alignment.CenterEnd),
                    )
                }
                if (showZero) {
                    var zeroLabelWidth by remember { mutableIntStateOf(0) }
                    Text(
                        text = scaleZeroText,
                        color = appearance.labelColor,
                        fontSize = appearance.labelSize,
                        onTextLayout = { zeroLabelWidth = it.size.width },
                        modifier = Modifier
                            .align(Alignment.TopStart)
                            .offset {
                                IntOffset(
                                    (zeroCenterX - zeroLabelWidth / 2f).roundToInt(),
                                    0,
                                )
                            },
                    )
                }
            }
        }
    }
}

fun defaultFrostSliderAppearance(context: android.content.Context): FrostSliderAppearance {
    return FrostSliderAppearance(
        trackInactiveColor = FrostControlColors.sliderTrackInactive(context),
        trackActiveColor = FrostControlColors.sliderTrackActive(context),
        thumbColor = FrostControlColors.sliderThumb(context),
        labelColor = FrostControlColors.sliderLabel(context),
        labelSize = FrostControlDimens.sliderLabelTextSize(context),
        thumbSize = FrostControlDimens.sliderThumbSize(context),
        trackHeight = FrostControlDimens.sliderTrackHeight(context),
        trackCornerRadius = FrostControlDimens.sliderTrackCornerRadius(context),
        touchHeight = FrostControlDimens.sliderTouchHeight(context),
    )
}
