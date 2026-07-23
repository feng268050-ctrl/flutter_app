package com.lasercyber.lws.ime.compose

import android.os.SystemClock
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.PressInteraction
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import kotlinx.coroutines.withTimeoutOrNull

fun Modifier.imeSimpleKeyTap(
    interactionSource: MutableInteractionSource,
    onTap: () -> Unit,
): Modifier = pointerInput(interactionSource, onTap) {
    detectTapGestures(
        onPress = { offset ->
            val press = PressInteraction.Press(offset)
            interactionSource.tryEmit(press)
            val released = tryAwaitRelease()
            if (released) {
                interactionSource.tryEmit(PressInteraction.Release(press))
            } else {
                interactionSource.emit(PressInteraction.Cancel(press))
            }
        },
        onTap = { onTap() },
    )
}

fun Modifier.imeShiftKeyGestures(
    interactionSource: MutableInteractionSource,
    onShortTap: () -> Unit,
    onLongPress: () -> Unit,
): Modifier = pointerInput(interactionSource, onLongPress, onShortTap) {
    awaitEachGesture {
        val down = awaitFirstDown(requireUnconsumed = false)
        val press = PressInteraction.Press(down.position)
        interactionSource.tryEmit(press)
        try {
            val pointerId = down.id
            var longPressTriggered = false
            val longPressDeadline = down.uptimeMillis + viewConfiguration.longPressTimeoutMillis

            while (true) {
                if (!longPressTriggered && SystemClock.uptimeMillis() >= longPressDeadline) {
                    longPressTriggered = true
                    onLongPress()
                }

                val event = withTimeoutOrNull(16L) {
                    awaitPointerEvent()
                }
                if (event == null) {
                    continue
                }

                val change = event.changes.firstOrNull { it.id == pointerId } ?: continue
                if (!change.pressed) {
                    if (!longPressTriggered) {
                        onShortTap()
                    }
                    break
                }
            }
        } finally {
            interactionSource.tryEmit(PressInteraction.Release(press))
        }
    }
}

fun Modifier.imeAlternateKeyGestures(
    interactionSource: MutableInteractionSource,
    keyWidthPx: Int,
    optionCount: Int,
    onShortTap: () -> Unit,
    onPopupShown: () -> Unit,
    onSelectionChange: (Int) -> Unit,
    onPopupCommit: (Int) -> Unit,
    onPopupDismiss: () -> Unit,
): Modifier = pointerInput(interactionSource, keyWidthPx, optionCount) {
    awaitEachGesture {
        val down = awaitFirstDown(requireUnconsumed = false)
        val press = PressInteraction.Press(down.position)
        interactionSource.tryEmit(press)
        try {
            val pointerId = down.id
            var popupActive = false
            var lastSelection = defaultPopupIndex(optionCount)
            val longPressDeadline = down.uptimeMillis + viewConfiguration.longPressTimeoutMillis

            while (true) {
                if (!popupActive && SystemClock.uptimeMillis() >= longPressDeadline) {
                    popupActive = true
                    onPopupShown()
                    onSelectionChange(lastSelection)
                }

                val event = if (popupActive) {
                    awaitPointerEvent()
                } else {
                    withTimeoutOrNull(16L) { awaitPointerEvent() } ?: continue
                }

                val change = event.changes.firstOrNull { it.id == pointerId } ?: continue

                if (popupActive) {
                    lastSelection = selectionIndexForX(
                        x = change.position.x,
                        keyWidthPx = keyWidthPx,
                        optionCount = optionCount,
                    )
                    onSelectionChange(lastSelection)
                }

                if (!change.pressed) {
                    if (popupActive) {
                        onPopupCommit(lastSelection)
                        onPopupDismiss()
                    } else {
                        onShortTap()
                    }
                    break
                }
            }
        } finally {
            interactionSource.tryEmit(PressInteraction.Release(press))
        }
    }
}

internal fun selectionIndexForX(x: Float, keyWidthPx: Int, optionCount: Int): Int {
    if (optionCount <= 1 || keyWidthPx <= 0) {
        return 0
    }
    val slot = (x / keyWidthPx.toFloat() * optionCount).toInt()
    return slot.coerceIn(0, optionCount - 1)
}

internal fun defaultPopupIndex(optionCount: Int): Int =
    if (optionCount >= 3) 1 else 0
