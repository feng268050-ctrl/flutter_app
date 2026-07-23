package com.lasercyber.lws.ime.compose

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlin.math.min

@Composable
fun ReturnArrowIcon(
    modifier: Modifier = Modifier,
    color: Color = Color.White,
    strokeWidth: Dp = 4.dp,
) {
    val strokePx = with(LocalDensity.current) {
        strokeWidth.toPx()
    }

    Canvas(modifier = modifier) {
        val w = size.width
        val h = size.height
        val g = ReturnArrowLayout
        val cr = min(w, h) * g.CORNER_RADIUS
        val rightX = w * g.RIGHT_X
        val topY = h * g.TOP_Y
        val stemY = h * g.STEM_Y
        val arrowX = w * g.ARROW_X
        val topEndX = w * g.TOP_END_X

        val path = Path().apply {
            moveTo(topEndX, topY)
            lineTo(rightX - cr, topY)
            quadraticBezierTo(rightX, topY, rightX, topY + cr)
            lineTo(rightX, stemY - cr)
            quadraticBezierTo(rightX, stemY, rightX - cr, stemY)
            lineTo(arrowX, stemY)
        }

        drawPath(
            path = path,
            color = color,
            style = Stroke(
                width = strokePx,
                cap = StrokeCap.Round,
                join = StrokeJoin.Round,
            ),
        )

        drawLine(
            color = color,
            start = Offset(arrowX, stemY),
            end = Offset(w * g.ARROW_UPPER_X, h * g.ARROW_UPPER_Y),
            strokeWidth = strokePx,
            cap = StrokeCap.Round,
        )
        drawLine(
            color = color,
            start = Offset(arrowX, stemY),
            end = Offset(w * g.ARROW_LOWER_X, h * g.ARROW_LOWER_Y),
            strokeWidth = strokePx,
            cap = StrokeCap.Round,
        )
    }
}

/** Normalized layout; corner radius is a fraction of min(width, height). */
private object ReturnArrowLayout {
    const val RIGHT_X = 0.82f
    const val TOP_Y = 0.22f
    const val STEM_Y = 0.50f
    const val ARROW_X = 0.28f
    const val TOP_END_X = 0.78f
    const val ARROW_UPPER_X = 0.44f
    const val ARROW_UPPER_Y = 0.34f
    const val ARROW_LOWER_X = 0.44f
    const val ARROW_LOWER_Y = 0.66f
    const val CORNER_RADIUS = 0.10f
}

@Composable
internal fun ImeEnterKeyIcon(
    modifier: Modifier = Modifier,
    color: Color = Color.White,
) {
    ReturnArrowIcon(
        modifier = modifier,
        color = color,
        strokeWidth = 4.dp,
    )
}
