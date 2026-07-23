package com.lasercyber.lws.frostui.control

import android.view.View
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChanged
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.foundation.Image
import androidx.compose.ui.text.style.TextAlign
import com.lasercyber.lws.frostui.common.SinglePointerTracker
import com.lasercyber.lws.frostui.common.pressedPointerCount
import kotlin.math.roundToInt

@Composable
fun FrostCapsuleSlider(
    progress: Int,
    onProgressChange: (Int, Boolean) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    min: Int = 0,
    max: Int = 100,
    appearance: FrostCapsuleSliderAppearance,
    trailingIcon: Painter? = null,
    onStartTracking: (() -> Unit)? = null,
    onStopTracking: ((cancelled: Boolean) -> Unit)? = null,
) {
    val view = LocalView.current
    val density = LocalDensity.current
    val context = LocalContext.current
    var dragFraction by remember { mutableFloatStateOf(Float.NaN) }
    var isDragging by remember { mutableStateOf(false) }
    var valueTextWidthPx by remember { mutableIntStateOf(0) }
    var iconWidthPx by remember { mutableIntStateOf(0) }
    var trackWidthPx by remember { mutableIntStateOf(0) }

    val displayProgress = if (isDragging && !dragFraction.isNaN()) {
        (min + dragFraction.coerceIn(0f, 1f) * (max - min)).roundToInt().coerceIn(min, max)
    } else {
        progress
    }
    val fraction = if (max == min) 0f else (displayProgress - min).toFloat() / (max - min)
    val valueText = "${displayProgress}${appearance.valueSuffix}"

    val outerShape = RoundedCornerShape(appearance.capsuleCornerRadius)
    val sliderShape = RoundedCornerShape(appearance.sliderCornerRadius)

    Box(
        modifier = modifier
            .defaultMinSize(minHeight = FrostControlDimens.capsuleControlHeight(context))
            .clip(outerShape)
            .onSizeChanged { trackWidthPx = it.width }
            .pointerInput(enabled, min, max) {
                if (!enabled) return@pointerInput

                fun applyX(x: Float) {
                    val width = size.width.toFloat()
                    if (width <= 0f) return
                    val fractionX = (x / width).coerceIn(0f, 1f)
                    dragFraction = fractionX
                    onProgressChange(
                        (min + fractionX * (max - min)).roundToInt().coerceIn(min, max),
                        true,
                    )
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
                    var tracking = tracker.isSinglePointerGesture
                    var startedTracking = false
                    isDragging = tracking
                    view.isPressed = tracking
                    if (tracking) {
                        startedTracking = true
                        view.disallowAncestorsInterceptTouch(true)
                        onStartTracking?.invoke()
                        applyX(down.position.x)
                    }

                    val pointerId = down.id
                    try {
                        while (true) {
                            val event = awaitPointerEvent(PointerEventPass.Initial)
                            tracker.recordEvent(event)
                            if (!tracker.isSinglePointerGesture) {
                                tracking = false
                            }
                            val change = event.changes.firstOrNull { it.id == pointerId } ?: break
                            if (!change.pressed) break
                            if (tracking && change.positionChanged()) {
                                change.consume()
                                applyX(change.position.x)
                            }
                        }
                    } finally {
                        isDragging = false
                        dragFraction = Float.NaN
                        view.isPressed = false
                        view.disallowAncestorsInterceptTouch(false)
                        if (startedTracking) {
                            onStopTracking?.invoke(!tracker.isSinglePointerGesture)
                        }
                    }
                }
            },
    ) {
        Canvas(
            modifier = Modifier
                .fillMaxSize()
                .padding(appearance.capsuleInset),
        ) {
            val width = size.width
            val height = size.height
            if (width <= 0f || height <= 0f) return@Canvas

            val radius = appearance.sliderCornerRadius.toPx()
            drawRoundRect(
                color = appearance.trackInactiveColor,
                topLeft = Offset.Zero,
                size = Size(width, height),
                cornerRadius = CornerRadius(radius, radius),
            )

            val fillWidth = width * fraction
            if (fillWidth > 0f) {
                drawRoundRect(
                    color = appearance.trackActiveColor,
                    topLeft = Offset.Zero,
                    size = Size(fillWidth, height),
                    cornerRadius = CornerRadius(radius, radius),
                )
            }
        }

        Canvas(modifier = Modifier.fillMaxSize()) {
            val borderWidth = appearance.capsuleBorderWidth.toPx()
            if (borderWidth <= 0f) return@Canvas
            drawRoundRect(
                color = appearance.capsuleBorderColor,
                size = Size(size.width, size.height),
                cornerRadius = CornerRadius(appearance.capsuleCornerRadius.toPx()),
                style = Stroke(width = borderWidth),
            )
        }

        val insetPx = with(density) { appearance.capsuleInset.toPx() }
        val innerTrackWidthPx = if (trackWidthPx > 0) {
            trackWidthPx - (insetPx * 2f).roundToInt()
        } else {
            0
        }
        val fillWidthPx = innerTrackWidthPx * fraction
        val valueCenterX = with(density) { appearance.valuePaddingHorizontal.toPx() + valueTextWidthPx / 2f }
        val valueColor = frostCapsuleOverlayColor(
            frostCapsuleOverlayDarkFraction(fillWidthPx, valueCenterX, valueTextWidthPx.toFloat()),
            appearance.overlayLightColor,
            appearance.overlayDarkColor,
        )
        val iconCenterX = if (innerTrackWidthPx > 0 && iconWidthPx > 0) {
            innerTrackWidthPx - with(density) { appearance.trailingIconSize.toPx() / 2f }
        } else {
            0f
        }
        val iconColor = frostCapsuleOverlayColor(
            frostCapsuleOverlayDarkFraction(fillWidthPx, iconCenterX, iconWidthPx.toFloat()),
            appearance.overlayLightColor,
            appearance.overlayDarkColor,
        )

        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = appearance.capsuleInset),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = valueText,
                color = valueColor,
                fontSize = appearance.valueTextSize,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .padding(horizontal = appearance.valuePaddingHorizontal)
                    .onSizeChanged { valueTextWidthPx = it.width },
            )
            Box(modifier = Modifier.weight(1f))
            if (trailingIcon != null) {
                Image(
                    painter = trailingIcon,
                    contentDescription = null,
                    colorFilter = ColorFilter.tint(iconColor),
                    modifier = Modifier
                        .size(appearance.trailingIconSize)
                        .onSizeChanged { iconWidthPx = it.width },
                )
            }
        }
    }
}

fun defaultFrostCapsuleSliderAppearance(context: android.content.Context): FrostCapsuleSliderAppearance =
    FrostControlDimens.capsuleSliderAppearance(context)
