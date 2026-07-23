package com.lasercyber.lws.frostui.control

import android.view.View
import androidx.compose.animation.core.Animatable
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.LocalViewConfiguration
import com.lasercyber.lws.frostui.common.FrostUiClickSoundRegistry
import com.lasercyber.lws.frostui.common.SinglePointerTracker
import com.lasercyber.lws.frostui.common.pressedPointerCount
import kotlin.math.abs
import kotlin.math.min
import kotlinx.coroutines.launch

@Composable
fun FrostSwitch(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    appearance: FrostSwitchAppearance,
    hostView: View = LocalView.current,
) {
    val view = hostView
    val scope = rememberCoroutineScope()
    val touchSlop = LocalViewConfiguration.current.touchSlop
    val thumbPosition = remember { Animatable(if (checked) 1f else 0f) }
    var dragPosition by remember { mutableFloatStateOf(Float.NaN) }
    var isDragging by remember { mutableStateOf(false) }
    val checkedState = rememberUpdatedState(checked)
    val onCheckedChangeState = rememberUpdatedState(onCheckedChange)
    val animationDurationMs = appearance.animationDurationMs

    LaunchedEffect(checked) {
        if (!isDragging && dragPosition.isNaN()) {
            val target = switchEdgePosition(checked)
            if (abs(thumbPosition.value - target) > 0.001f) {
                thumbPosition.animateTo(
                    targetValue = target,
                    animationSpec = switchSnapSpec(animationDurationMs),
                )
            }
        }
    }

    val trackWidth = maxOf(appearance.trackWidth, appearance.thumbSize * 2)
    val trackHeight = appearance.trackHeight
    val thumbSizePx = with(LocalDensity.current) { appearance.thumbSize.toPx() }
    val displayPosition = if (!dragPosition.isNaN()) dragPosition else thumbPosition.value

    Canvas(
        modifier = modifier
            .size(trackWidth, trackHeight)
            .pointerInput(enabled, checked, appearance, touchSlop, thumbSizePx) {
                if (!enabled) return@pointerInput

                fun thumbFractionFromX(x: Float): Float {
                    val travel = size.width - thumbSizePx
                    if (travel <= 0f) return thumbPosition.value
                    val thumbLeft = (x - thumbSizePx / 2f).coerceIn(0f, travel)
                    return thumbLeft / travel
                }

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
                    var dragging = false
                    val downX = down.position.x
                    view.isPressed = true
                    view.disallowAncestorsInterceptTouch(true)
                    dragPosition = thumbPosition.value
                    scope.launch { thumbPosition.stop() }

                    val pointerId = down.id
                    try {
                        while (true) {
                            val event = awaitPointerEvent(PointerEventPass.Initial)
                            tracker.recordEvent(event)
                            val change = event.changes.firstOrNull { it.id == pointerId } ?: break
                            if (!change.pressed) {
                                if (tracker.isSinglePointerGesture) {
                                    if (dragging) {
                                        val releasePosition = dragPosition
                                        val targetChecked = switchEdgeChecked(releasePosition)
                                        scope.launch {
                                            try {
                                                thumbPosition.snapTo(releasePosition)
                                                dragPosition = Float.NaN
                                                if (targetChecked != checkedState.value) {
                                                    FrostUiClickSoundRegistry.playClick()
                                                    onCheckedChangeState.value(targetChecked)
                                                }
                                                thumbPosition.animateTo(
                                                    targetValue = switchEdgePosition(targetChecked),
                                                    animationSpec = switchSnapSpec(animationDurationMs),
                                                )
                                            } finally {
                                                isDragging = false
                                            }
                                        }
                                    } else {
                                        val targetChecked = !checkedState.value
                                        dragPosition = Float.NaN
                                        FrostUiClickSoundRegistry.playClick()
                                        onCheckedChangeState.value(targetChecked)
                                    }
                                }
                                break
                            }
                            if (!dragging && abs(change.position.x - downX) > touchSlop) {
                                dragging = true
                                isDragging = true
                            }
                            if (dragging && change.positionChanged()) {
                                change.consume()
                                dragPosition = thumbFractionFromX(change.position.x)
                            }
                        }
                    } finally {
                        if (!dragging) {
                            isDragging = false
                        }
                        view.isPressed = false
                        view.disallowAncestorsInterceptTouch(false)
                    }
                }
            },
    ) {
        val width = size.width
        val height = size.height
        if (width <= 0f || height <= 0f) return@Canvas

        val position = displayPosition
        val trackRadius = min(appearance.trackCornerRadius.toPx(), height / 2f)
        drawRoundRect(
            color = appearance.trackOffColor,
            size = Size(width, height),
            cornerRadius = CornerRadius(trackRadius, trackRadius),
        )

        val thumbSizePx = appearance.thumbSize.toPx()
        val travel = width - thumbSizePx
        val thumbLeft = travel * position
        val thumbRight = thumbLeft + thumbSizePx
        val thumbTop = appearance.thumbInsetVertical.toPx()
        val thumbBottom = height - appearance.thumbInsetVertical.toPx()

        if (position > 0f) {
            val fillRadius = min(trackRadius, min(thumbRight / 2f, height / 2f))
            drawRoundRect(
                color = appearance.trackOnColor,
                size = Size(thumbRight, height),
                cornerRadius = CornerRadius(fillRadius, fillRadius),
            )
        }

        drawOval(
            color = appearance.thumbColor,
            topLeft = Offset(thumbLeft, thumbTop),
            size = Size(thumbRight - thumbLeft, thumbBottom - thumbTop),
        )
    }
}

fun defaultFrostSwitchAppearance(context: android.content.Context): FrostSwitchAppearance {
    return FrostSwitchAppearance(
        trackOffColor = FrostControlColors.switchTrackOff(context),
        trackOnColor = FrostControlColors.switchTrackOn(context),
        thumbColor = FrostControlColors.switchThumb(context),
        trackWidth = FrostControlDimens.switchTrackWidth(context),
        trackHeight = FrostControlDimens.switchTrackHeight(context),
        trackCornerRadius = FrostControlDimens.switchTrackCornerRadius(context),
        thumbSize = FrostControlDimens.switchThumbSize(context),
        thumbInsetVertical = FrostControlDimens.switchThumbInsetVertical(context),
        animationDurationMs = FrostControlDefaults.ANIMATION_DURATION_MS,
    )
}
