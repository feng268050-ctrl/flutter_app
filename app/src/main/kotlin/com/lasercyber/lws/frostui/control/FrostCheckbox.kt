package com.lasercyber.lws.frostui.control

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.lasercyber.lws.frostui.control.FrostControlDefaults
import com.lasercyber.lws.frostui.common.FrostUiClickSoundRegistry
import com.lasercyber.lws.frostui.common.SinglePointerTracker
import com.lasercyber.lws.frostui.common.pressedPointerCount
import kotlin.math.min

@Composable
fun FrostCheckbox(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    label: String? = null,
    appearance: FrostCheckboxAppearance,
) {
    val view = LocalView.current
    val checkedProgress by animateFloatAsState(
        targetValue = if (checked) 1f else 0f,
        animationSpec = tween(
            durationMillis = appearance.animationDurationMs,
            easing = FastOutSlowInEasing,
        ),
        label = "checkboxProgress",
    )

    val hasLabel = !label.isNullOrEmpty()
    val boxSize = appearance.boxSize
    val disabledAlpha = 0.4f
    val strokeColor = if (enabled) {
        appearance.uncheckedStrokeColor
    } else {
        appearance.uncheckedStrokeColor.copy(alpha = appearance.uncheckedStrokeColor.alpha * disabledAlpha)
    }
    val fillColor = if (enabled) {
        appearance.checkedFillColor
    } else {
        appearance.checkedFillColor.copy(alpha = appearance.checkedFillColor.alpha * disabledAlpha)
    }
    val checkColor = if (enabled) {
        appearance.checkmarkColor
    } else {
        appearance.checkmarkColor.copy(alpha = appearance.checkmarkColor.alpha * disabledAlpha)
    }
    val labelColor = if (enabled) {
        appearance.labelColor
    } else {
        appearance.labelColor.copy(alpha = appearance.labelColor.alpha * disabledAlpha)
    }

    Row(
        modifier = modifier
            .pointerInput(enabled, checked) {
                if (!enabled) return@pointerInput
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
                                view.isPressed = true
                                FrostUiClickSoundRegistry.playClick()
                                onCheckedChange(!checked)
                                view.isPressed = false
                                view.callOnClick()
                            }
                            break
                        }
                    }
                }
            },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Canvas(
            modifier = Modifier.size(boxSize),
        ) {
            val width = size.width
            val height = size.height
            if (width <= 0f || height <= 0f) return@Canvas

            val cx = width / 2f
            val cy = height / 2f
            val outerRadius = min(width, height) / 2f
            val strokeRadius = outerRadius - appearance.strokeWidth.toPx() / 2f
            val progress = checkedProgress

            if (progress < 1f) {
                val strokeAlpha = 1f - progress
                drawCircle(
                    color = strokeColor.copy(alpha = strokeColor.alpha * strokeAlpha),
                    radius = strokeRadius,
                    center = Offset(cx, cy),
                    style = Stroke(width = appearance.strokeWidth.toPx()),
                )
            }

            if (progress > 0f) {
                val fillRadius = strokeRadius + (outerRadius - strokeRadius) * progress
                drawCircle(
                    color = fillColor.copy(alpha = fillColor.alpha * progress),
                    radius = fillRadius,
                    center = Offset(cx, cy),
                )
            }

            if (progress > 0f) {
                val boxPx = boxSize.toPx()
                val checkmarkStroke = boxPx * 0.10f
                val left = boxPx * 0.28f
                val top = boxPx * 0.50f
                val midX = boxPx * 0.44f
                val midY = boxPx * 0.66f
                val right = boxPx * 0.74f
                val bottom = boxPx * 0.34f

                val androidPath = android.graphics.Path().apply {
                    moveTo(left, top)
                    lineTo(midX, midY)
                    lineTo(right, bottom)
                }
                val measure = android.graphics.PathMeasure(androidPath, false)
                val length = measure.length
                if (length > 0f) {
                    val visible = android.graphics.Path()
                    measure.getSegment(0f, length * progress, visible, true)
                    drawContext.canvas.nativeCanvas.apply {
                        val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                            color = android.graphics.Color.argb(
                                (255 * checkColor.alpha * progress).toInt(),
                                (checkColor.red * 255).toInt(),
                                (checkColor.green * 255).toInt(),
                                (checkColor.blue * 255).toInt(),
                            )
                            style = android.graphics.Paint.Style.STROKE
                            strokeWidth = checkmarkStroke
                            strokeCap = android.graphics.Paint.Cap.ROUND
                            strokeJoin = android.graphics.Paint.Join.ROUND
                        }
                        drawPath(visible, paint)
                    }
                }
            }
        }

        if (hasLabel) {
            Text(
                text = label!!,
                color = labelColor,
                fontSize = appearance.labelSize,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier
                    .padding(start = appearance.labelSpacing)
                    .widthIn(max = 600.dp),
            )
        }
    }
}

fun defaultFrostCheckboxAppearance(context: android.content.Context): FrostCheckboxAppearance {
    return FrostCheckboxAppearance(
        checkedFillColor = FrostControlColors.checkboxFill(context),
        uncheckedStrokeColor = FrostControlColors.checkboxStroke(context),
        checkmarkColor = FrostControlColors.checkboxCheckmark(context),
        boxSize = FrostControlDimens.checkboxSize(context),
        strokeWidth = FrostControlDimens.checkboxStrokeWidth(context),
        labelSpacing = FrostControlDimens.checkboxLabelSpacing(context),
        labelColor = FrostControlColors.checkboxLabel(context),
        labelSize = FrostControlDimens.checkboxLabelTextSize(context),
        animationDurationMs = FrostControlDefaults.ANIMATION_DURATION_MS,
    )
}
