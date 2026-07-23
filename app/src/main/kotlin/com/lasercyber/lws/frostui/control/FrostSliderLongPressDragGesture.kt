package com.lasercyber.lws.frostui.control

import android.os.SystemClock
import android.view.View
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChanged
import com.lasercyber.lws.frostui.common.FrostUiClickSoundRegistry
import com.lasercyber.lws.frostui.common.SinglePointerTracker
import com.lasercyber.lws.frostui.common.pressedPointerCount
import kotlin.math.abs
import kotlinx.coroutines.withTimeoutOrNull

class FrostSliderLongPressDragState internal constructor() {
    var isThumbExpanded by mutableStateOf(false)
        internal set
    var isValueArmed by mutableStateOf(false)
        internal set
    var isCenterSnapped by mutableStateOf(false)
        internal set
    var dragFraction by mutableFloatStateOf(Float.NaN)
        internal set
}

@Composable
fun rememberFrostSliderLongPressDragState(): FrostSliderLongPressDragState =
    remember { FrostSliderLongPressDragState() }

@Composable
fun frostSliderThumbDragScale(isThumbExpanded: Boolean, dragScale: Float): Float {
    val target = if (isThumbExpanded) dragScale else 1f
    val scale by animateFloatAsState(
        targetValue = target,
        animationSpec = tween(
            durationMillis = FrostControlDefaults.SLIDER_THUMB_EXPAND_DURATION_MS,
            easing = decelerateEasing(),
        ),
        label = "sliderThumbDragScale",
    )
    return scale
}

/** Value updates are only delivered while [FrostSliderLongPressDragState.isValueArmed] is true. */
internal fun frostSliderApplyValueWhileArmed(
    isValueArmed: Boolean,
    apply: () -> Unit,
) {
    if (isValueArmed) {
        apply()
    }
}

@Composable
internal fun Modifier.frostSliderLongPressDragGesture(
    enabled: Boolean,
    longPressThresholdMs: Long,
    thumbCenterX: Float,
    touchHeightPx: Float,
    thumbRadiusPx: Float,
    minTouchHalfExtentPx: Float,
    state: FrostSliderLongPressDragState,
    onThumbExpand: () -> Unit,
    onValueChangeWhileArmed: (activationX: Float, currentX: Float) -> Float?,
    onRelease: (cancelled: Boolean) -> Unit,
): Modifier {
    val view = androidx.compose.ui.platform.LocalView.current
    val thumbCenterXState = rememberUpdatedState(thumbCenterX)
    val onThumbExpandState = rememberUpdatedState(onThumbExpand)
    val onValueChangeWhileArmedState = rememberUpdatedState(onValueChangeWhileArmed)
    val onReleaseState = rememberUpdatedState(onRelease)
    val thumbExpandDurationMs = FrostControlDefaults.SLIDER_THUMB_EXPAND_DURATION_MS.toLong()
    return pointerInput(
        enabled,
        longPressThresholdMs,
        thumbExpandDurationMs,
        touchHeightPx,
        thumbRadiusPx,
        minTouchHalfExtentPx,
    ) {
        if (!enabled) return@pointerInput
        val touchSlop = viewConfiguration.touchSlop

        awaitEachGesture {
            val down = awaitFirstDown(
                requireUnconsumed = false,
                pass = PointerEventPass.Initial,
            )
            if (currentEvent.pressedPointerCount() > 1) return@awaitEachGesture
            val hitRect = frostSliderThumbHitRect(
                thumbCenterX = thumbCenterXState.value,
                touchHeightPx = touchHeightPx,
                thumbRadiusPx = thumbRadiusPx,
                minTouchHalfExtentPx = minTouchHalfExtentPx,
            )
            if (!frostSliderThumbHitRectContains(down.position.x, down.position.y, hitRect)) {
                return@awaitEachGesture
            }

            val tracker = SinglePointerTracker()
            tracker.recordEvent(currentEvent)
            val pointerId = down.id
            val downX = down.position.x
            var thumbExpanded = false
            var valueArmed = false
            var activationX = 0f
            var lastX = downX
            var expandStartMs = 0L
            val longPressDeadline = down.uptimeMillis + longPressThresholdMs
            var startedExpand = false

            try {
                while (true) {
                    if (!thumbExpanded &&
                        tracker.isSinglePointerGesture &&
                        SystemClock.uptimeMillis() >= longPressDeadline
                    ) {
                        thumbExpanded = true
                        expandStartMs = SystemClock.uptimeMillis()
                        state.isThumbExpanded = true
                        view.isPressed = true
                        view.disallowAncestorsInterceptTouch(true)
                        FrostUiClickSoundRegistry.playClick()
                        onThumbExpandState.value()
                        startedExpand = true
                    }

                    if (thumbExpanded &&
                        !valueArmed &&
                        SystemClock.uptimeMillis() >= expandStartMs + thumbExpandDurationMs
                    ) {
                        valueArmed = true
                        activationX = lastX
                        state.isValueArmed = true
                    }

                    val event = if (thumbExpanded) {
                        awaitPointerEvent(PointerEventPass.Initial)
                    } else {
                        withTimeoutOrNull(16L) {
                            awaitPointerEvent(PointerEventPass.Initial)
                        } ?: continue
                    }

                    tracker.recordEvent(event)
                    if (!tracker.isSinglePointerGesture && !thumbExpanded) {
                        break
                    }
                    val change = event.changes.firstOrNull { it.id == pointerId } ?: break
                    if (!change.pressed) break
                    lastX = change.position.x
                    if (!thumbExpanded && abs(lastX - downX) > touchSlop) {
                        break
                    }
                    if (change.positionChanged()) {
                        change.consume()
                        if (valueArmed && state.isValueArmed) {
                            val reanchorX = onValueChangeWhileArmedState.value(activationX, lastX)
                            if (reanchorX != null) {
                                activationX = reanchorX
                            }
                        }
                    }
                }
            } finally {
                if (startedExpand) {
                    FrostUiClickSoundRegistry.playClick()
                    onReleaseState.value(!tracker.isSinglePointerGesture)
                }
                state.isThumbExpanded = false
                state.isValueArmed = false
                state.isCenterSnapped = false
                state.dragFraction = Float.NaN
                view.isPressed = false
                view.disallowAncestorsInterceptTouch(false)
            }
        }
    }
}

@Composable
internal fun Modifier.frostSliderDirectDragGesture(
    enabled: Boolean,
    state: FrostSliderLongPressDragState,
    onDragStart: () -> Unit,
    onDragPositionX: (x: Float) -> Unit,
    onRelease: (cancelled: Boolean) -> Unit,
): Modifier {
    val view = androidx.compose.ui.platform.LocalView.current
    val onDragStartState = rememberUpdatedState(onDragStart)
    val onDragPositionXState = rememberUpdatedState(onDragPositionX)
    val onReleaseState = rememberUpdatedState(onRelease)
    return pointerInput(enabled) {
        if (!enabled) return@pointerInput

        awaitEachGesture {
            val down = awaitFirstDown(
                requireUnconsumed = false,
                pass = PointerEventPass.Initial,
            )
            if (currentEvent.pressedPointerCount() > 1) return@awaitEachGesture

            val tracker = SinglePointerTracker()
            tracker.recordEvent(currentEvent)
            val pointerId = down.id
            var started = false

            try {
                state.isValueArmed = true
                view.isPressed = true
                view.disallowAncestorsInterceptTouch(true)
                onDragStartState.value()
                started = true
                onDragPositionXState.value(down.position.x)

                while (true) {
                    val event = awaitPointerEvent(PointerEventPass.Initial)
                    tracker.recordEvent(event)
                    if (!tracker.isSinglePointerGesture) break
                    val change = event.changes.firstOrNull { it.id == pointerId } ?: break
                    if (!change.pressed) break
                    if (change.positionChanged()) {
                        change.consume()
                        onDragPositionXState.value(change.position.x)
                    }
                }
            } finally {
                if (started) {
                    onReleaseState.value(!tracker.isSinglePointerGesture)
                }
                state.isValueArmed = false
                state.isCenterSnapped = false
                state.dragFraction = Float.NaN
                view.isPressed = false
                view.disallowAncestorsInterceptTouch(false)
            }
        }
    }
}
