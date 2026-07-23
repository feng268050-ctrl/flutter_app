package com.lasercyber.lws.ime.compose

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp

@Composable
internal fun ImeShiftKeyIcon(
    visualState: ImeShiftVisualState,
    modifier: Modifier = Modifier,
) {
    val iconColor = when (visualState) {
        ImeShiftVisualState.Off -> imeDefaultTextColor()
        ImeShiftVisualState.Single,
        ImeShiftVisualState.Lock,
        -> imeShiftActiveColor()
    }

    Box(
        modifier = modifier,
        contentAlignment = Alignment.Center,
    ) {
        StandardShiftIcon(
            visualState = visualState,
            color = iconColor,
            modifier = Modifier.size(
                width = imeKeyShiftIconWidth(),
                height = imeKeyShiftIconHeight(),
            ),
        )
    }
}

/** Shared layout for off (outline) and on (fill + bar) so the arrow stays the same size. */
private object ShiftIconGeometry {
    const val ARROW_TIP_Y = 0.10f
    const val ARROW_WING_Y = 0.44f
    const val ARROW_WING_INNER_X = 0.34f
    const val ARROW_WING_OUTER_X = 0.16f
    const val ARROW_STEM_BOTTOM_Y = 0.72f
    const val BAR_TOP_Y = 0.82f
    const val BAR_BOTTOM_Y = 0.92f
    const val BAR_LEFT_X = 0.32f
    const val BAR_RIGHT_X = 0.68f
}

@Composable
private fun StandardShiftIcon(
    visualState: ImeShiftVisualState,
    color: Color,
    modifier: Modifier = Modifier,
) {
    val density = LocalDensity.current
    val strokeWidth = with(density) { 3.dp.toPx() }
    val strokeInset = with(density) { (strokeWidth / 2f).toDp() }
    val active = visualState != ImeShiftVisualState.Off

    Canvas(
        modifier = modifier.padding(strokeInset),
    ) {
        val w = size.width
        val h = size.height
        val g = ShiftIconGeometry

        val arrowPath = Path().apply {
            moveTo(w * 0.50f, h * g.ARROW_TIP_Y)
            lineTo(w * g.ARROW_WING_OUTER_X, h * g.ARROW_WING_Y)
            lineTo(w * g.ARROW_WING_INNER_X, h * g.ARROW_WING_Y)
            lineTo(w * g.ARROW_WING_INNER_X, h * g.ARROW_STEM_BOTTOM_Y)
            lineTo(w * (1f - g.ARROW_WING_INNER_X), h * g.ARROW_STEM_BOTTOM_Y)
            lineTo(w * (1f - g.ARROW_WING_INNER_X), h * g.ARROW_WING_Y)
            lineTo(w * (1f - g.ARROW_WING_OUTER_X), h * g.ARROW_WING_Y)
            close()
        }

        if (active) {
            drawPath(path = arrowPath, color = color, style = Fill)
            drawRect(
                color = color,
                topLeft = Offset(w * g.BAR_LEFT_X, h * g.BAR_TOP_Y),
                size = Size(
                    w * (g.BAR_RIGHT_X - g.BAR_LEFT_X),
                    h * (g.BAR_BOTTOM_Y - g.BAR_TOP_Y),
                ),
            )
        } else {
            drawPath(
                path = arrowPath,
                color = color,
                style = Stroke(
                    width = strokeWidth,
                    cap = StrokeCap.Round,
                    join = StrokeJoin.Round,
                ),
            )
        }
    }
}
