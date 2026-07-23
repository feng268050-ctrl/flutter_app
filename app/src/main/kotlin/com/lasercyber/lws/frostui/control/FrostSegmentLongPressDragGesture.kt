package com.lasercyber.lws.frostui.control

import android.os.SystemClock
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
import androidx.compose.ui.platform.LocalView
import com.lasercyber.lws.frostui.common.FrostUiClickSoundRegistry
import com.lasercyber.lws.frostui.common.SinglePointerTracker
import com.lasercyber.lws.frostui.common.pressedPointerCount
import kotlinx.coroutines.withTimeoutOrNull

class FrostSegmentLongPressDragState internal constructor() {
    var isPillExpanded by mutableStateOf(false)
        internal set
    var isSelectionArmed by mutableStateOf(false)
        internal set
    var dragOffsetPx by mutableFloatStateOf(Float.NaN)
        internal set
    var releaseSlideIndex by mutableFloatStateOf(Float.NaN)
        internal set
}

@Composable
fun rememberFrostSegmentLongPressDragState(): FrostSegmentLongPressDragState =
    remember { FrostSegmentLongPressDragState() }

@Composable
fun frostSegmentPillDragScale(isPillExpanded: Boolean, dragScale: Float): Float {
    val target = if (isPillExpanded) dragScale else 1f
    val scale by animateFloatAsState(
        targetValue = target,
        animationSpec = tween(
            durationMillis = FrostControlDefaults.SLIDER_THUMB_EXPAND_DURATION_MS,
            easing = decelerateEasing(),
        ),
        label = "segmentPillDragScale",
    )
    return scale
}

@Composable
internal fun Modifier.frostSegmentLongPressDragGesture(
    enabled: Boolean,
    optionCount: Int,
    longPressThresholdMs: Long,
    selectedIndex: Int,
    state: FrostSegmentLongPressDragState,
    clickSoundEnabled: Boolean,
    onPillExpand: (trackWidthPx: Float, segmentWidthPx: Float) -> Unit,
    onDragOffsetWhileArmed: (
        trackWidthPx: Float,
        segmentWidthPx: Float,
        activationX: Float,
        currentX: Float,
    ) -> Unit,
    onRelease: (trackWidthPx: Float, segmentWidthPx: Float, cancelled: Boolean) -> Unit,
): Modifier {
    val view = LocalView.current
    val selectedIndexState = rememberUpdatedState(selectedIndex)
    val clickSoundEnabledState = rememberUpdatedState(clickSoundEnabled)
    val onPillExpandState = rememberUpdatedState(onPillExpand)
    val onDragOffsetWhileArmedState = rememberUpdatedState(onDragOffsetWhileArmed)
    val onReleaseState = rememberUpdatedState(onRelease)
    val stateRef = rememberUpdatedState(state)
    val thumbExpandDurationMs = FrostControlDefaults.SLIDER_THUMB_EXPAND_DURATION_MS.toLong()
    return pointerInput(
        enabled,
        optionCount,
        longPressThresholdMs,
        thumbExpandDurationMs,
    ) {
        if (!enabled || optionCount <= 0) return@pointerInput
        val touchSlop = viewConfiguration.touchSlop

        awaitEachGesture {
            val trackWidthPx = size.width.toFloat()
            val trackHeightPx = size.height.toFloat()
            val segmentWidthPx = frostSegmentWidthPx(trackWidthPx, optionCount)
            if (segmentWidthPx <= 0f) return@awaitEachGesture

            val down = awaitFirstDown(
                requireUnconsumed = false,
                pass = PointerEventPass.Initial,
            )
            if (currentEvent.pressedPointerCount() > 1) return@awaitEachGesture

            val hitRect = frostSegmentSelectedHitRect(
                selectedIndex = selectedIndexState.value,
                segmentWidthPx = segmentWidthPx,
                trackHeightPx = trackHeightPx,
            )
            if (!frostSegmentSelectedHitRectContains(down.position.x, down.position.y, hitRect)) {
                return@awaitEachGesture
            }

            val tracker = SinglePointerTracker()
            tracker.recordEvent(currentEvent)
            val pointerId = down.id
            val downX = down.position.x
            var pillExpanded = false
            var selectionArmed = false
            var activationX = 0f
            var lastX = downX
            var expandStartMs = 0L
            val longPressDeadline = down.uptimeMillis + longPressThresholdMs
            var startedExpand = false

            try {
                while (true) {
                    if (!pillExpanded &&
                        tracker.isSinglePointerGesture &&
                        SystemClock.uptimeMillis() >= longPressDeadline
                    ) {
                        pillExpanded = true
                        expandStartMs = SystemClock.uptimeMillis()
                        stateRef.value.isPillExpanded = true
                        view.isPressed = true
                        view.disallowAncestorsInterceptTouch(true)
                        if (clickSoundEnabledState.value) {
                            FrostUiClickSoundRegistry.playClick()
                        }
                        onPillExpandState.value(trackWidthPx, segmentWidthPx)
                        startedExpand = true
                    }

                    if (pillExpanded &&
                        !selectionArmed &&
                        SystemClock.uptimeMillis() >= expandStartMs + thumbExpandDurationMs
                    ) {
                        selectionArmed = true
                        activationX = lastX
                        stateRef.value.isSelectionArmed = true
                    }

                    val event = if (pillExpanded) {
                        awaitPointerEvent(PointerEventPass.Initial)
                    } else {
                        withTimeoutOrNull(16L) {
                            awaitPointerEvent(PointerEventPass.Initial)
                        } ?: continue
                    }

                    tracker.recordEvent(event)
                    if (!tracker.isSinglePointerGesture && !pillExpanded) {
                        break
                    }
                    val change = event.changes.firstOrNull { it.id == pointerId } ?: break
                    if (!change.pressed) break
                    lastX = change.position.x
                    if (!pillExpanded && frostSegmentShouldCancelBeforeLongPress(lastX - downX, touchSlop)) {
                        break
                    }
                    if (change.positionChanged()) {
                        change.consume()
                        if (selectionArmed && stateRef.value.isSelectionArmed) {
                            onDragOffsetWhileArmedState.value(
                                trackWidthPx,
                                segmentWidthPx,
                                activationX,
                                lastX,
                            )
                        }
                    }
                }
            } finally {
                if (startedExpand) {
                    if (clickSoundEnabledState.value) {
                        FrostUiClickSoundRegistry.playClick()
                    }
                    onReleaseState.value(trackWidthPx, segmentWidthPx, !tracker.isSinglePointerGesture)
                }
                stateRef.value.isPillExpanded = false
                stateRef.value.isSelectionArmed = false
                stateRef.value.dragOffsetPx = Float.NaN
                view.isPressed = false
                view.disallowAncestorsInterceptTouch(false)
            }
        }
    }
}
