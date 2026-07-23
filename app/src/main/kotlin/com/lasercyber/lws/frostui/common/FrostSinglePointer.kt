package com.lasercyber.lws.frostui.common

import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.input.pointer.PointerEvent
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput

/** Active pointers currently hitting this composable. */
internal fun PointerEvent.pressedPointerCount(): Int = changes.count { it.pressed }

/**
 * Tracks whether a pointer gesture ever involved more than one finger on this target.
 * Industrial UI controls should ignore multi-touch to avoid accidental toggles during scroll/zoom.
 */
internal class SinglePointerTracker {
    private var hadMultiTouch = false

    fun recordEvent(event: PointerEvent) {
        if (event.pressedPointerCount() > 1) {
            hadMultiTouch = true
        }
    }

    val isSinglePointerGesture: Boolean
        get() = !hadMultiTouch
}

/**
 * Click handler that ignores multi-touch, matching legacy View behavior for row controls.
 */
internal fun Modifier.frostSingleFingerClickable(
    enabled: Boolean = true,
    onClick: () -> Unit,
): Modifier = composed {
    if (!enabled) return@composed this
    pointerInput(onClick) {
        awaitEachGesture {
            val tracker = SinglePointerTracker()
            val down = awaitFirstDown(
                requireUnconsumed = false,
                pass = PointerEventPass.Initial,
            )
            if (currentEvent.pressedPointerCount() > 1) {
                return@awaitEachGesture
            }
            tracker.recordEvent(currentEvent)

            val pointerId = down.id
            while (true) {
                val event = awaitPointerEvent(PointerEventPass.Initial)
                tracker.recordEvent(event)
                val change = event.changes.firstOrNull { it.id == pointerId } ?: break
                if (!change.pressed) {
                    if (tracker.isSinglePointerGesture) {
                        onClick()
                    }
                    break
                }
            }
        }
    }
}
