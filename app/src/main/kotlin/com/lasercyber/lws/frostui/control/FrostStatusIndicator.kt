package com.lasercyber.lws.frostui.control

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.nativeCanvas
import kotlin.math.min

enum class FrostStatusState {
    Idle,
    InProgress,
    Success,
    Failure,
}

enum class FrostStatusVariant {
    Dot,
    Icon,
}

data class FrostStatusIndicatorAppearance(
    val indicatorSize: androidx.compose.ui.unit.Dp,
    val strokeWidth: androidx.compose.ui.unit.Dp,
    val dotRadius: androidx.compose.ui.unit.Dp,
    val idleRingColor: Color,
    val inProgressDotColor: Color,
    val successColor: Color,
    val failureColor: Color,
    val glyphColor: Color,
)

data class ResolvedFrostStatusAppearance(
    val backgroundColor: Color,
    val dotColor: Color?,
    val showCheckmark: Boolean,
    val showCross: Boolean,
)

/**
 * Resolves semantic state + presentation variant into draw-time colors and glyphs.
 *
 * | State       | Dot                         | Icon                          |
 * |-------------|-----------------------------|-------------------------------|
 * | Idle        | gray bg                     | gray bg                       |
 * | InProgress  | gray bg + yellow dot        | gray bg + yellow dot          |
 * | Success     | gray bg + green dot         | green bg + white checkmark    |
 * | Failure     | gray bg + red dot           | red bg + white cross          |
 *
 * Idle and InProgress ignore variant for glyphs; InProgress always uses yellow dot.
 */
fun resolveFrostStatusAppearance(
    state: FrostStatusState,
    variant: FrostStatusVariant,
    appearance: FrostStatusIndicatorAppearance,
): ResolvedFrostStatusAppearance {
    return when (state) {
        FrostStatusState.Idle -> ResolvedFrostStatusAppearance(
            backgroundColor = appearance.idleRingColor,
            dotColor = null,
            showCheckmark = false,
            showCross = false,
        )
        FrostStatusState.InProgress -> ResolvedFrostStatusAppearance(
            backgroundColor = appearance.idleRingColor,
            dotColor = appearance.inProgressDotColor,
            showCheckmark = false,
            showCross = false,
        )
        FrostStatusState.Success -> when (variant) {
            FrostStatusVariant.Dot -> ResolvedFrostStatusAppearance(
                backgroundColor = appearance.idleRingColor,
                dotColor = appearance.successColor,
                showCheckmark = false,
                showCross = false,
            )
            FrostStatusVariant.Icon -> ResolvedFrostStatusAppearance(
                backgroundColor = appearance.successColor,
                dotColor = null,
                showCheckmark = true,
                showCross = false,
            )
        }
        FrostStatusState.Failure -> when (variant) {
            FrostStatusVariant.Dot -> ResolvedFrostStatusAppearance(
                backgroundColor = appearance.idleRingColor,
                dotColor = appearance.failureColor,
                showCheckmark = false,
                showCross = false,
            )
            FrostStatusVariant.Icon -> ResolvedFrostStatusAppearance(
                backgroundColor = appearance.failureColor,
                dotColor = null,
                showCheckmark = false,
                showCross = true,
            )
        }
    }
}

/** Background disc radius: nearly fills the 36dp tile so glyphs sit inside the solid core. */
fun frostStatusBackgroundRadiusPx(indicatorSizePx: Float): Float =
    indicatorSizePx / 2f * (17f / 18f)

fun frostStatusDotRadiusPx(dotRadiusDpPx: Float): Float = dotRadiusDpPx

@Composable
fun FrostStatusIndicator(
    state: FrostStatusState,
    modifier: Modifier = Modifier,
    variant: FrostStatusVariant = FrostStatusVariant.Dot,
    appearance: FrostStatusIndicatorAppearance,
) {
    val resolved = resolveFrostStatusAppearance(state, variant, appearance)
    val indicatorSize = appearance.indicatorSize

    Canvas(modifier = modifier.size(indicatorSize)) {
        val width = size.width
        val height = size.height
        if (width <= 0f || height <= 0f) return@Canvas

        val cx = width / 2f
        val cy = height / 2f
        val boxPx = min(width, height)
        val backgroundRadius = frostStatusBackgroundRadiusPx(boxPx)

        drawSoftBackground(
            center = Offset(cx, cy),
            radius = backgroundRadius,
            color = resolved.backgroundColor,
        )

        resolved.dotColor?.let { dotColor ->
            drawCircle(
                color = dotColor,
                radius = frostStatusDotRadiusPx(appearance.dotRadius.toPx()),
                center = Offset(cx, cy),
            )
        }

        if (resolved.showCheckmark) {
            drawStatusCheckmark(
                boxPx = boxPx,
                color = appearance.glyphColor,
            )
        }
        if (resolved.showCross) {
            drawStatusCross(
                boxPx = boxPx,
                color = appearance.glyphColor,
            )
        }
    }
}

internal fun androidx.compose.ui.graphics.drawscope.DrawScope.drawSoftBackground(
    center: Offset,
    radius: Float,
    color: Color,
) {
    if (radius <= 0f) return
    val fadeStart = 0.86f
    drawCircle(
        brush = Brush.radialGradient(
            colorStops = arrayOf(
                0f to color,
                fadeStart to color,
                1f to color.copy(alpha = 0f),
            ),
            center = center,
            radius = radius,
        ),
        radius = radius,
        center = center,
    )
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawStatusCheckmark(
    boxPx: Float,
    color: Color,
) {
    val stroke = boxPx * 0.10f
    val left = boxPx * 0.28f
    val top = boxPx * 0.50f
    val midX = boxPx * 0.44f
    val midY = boxPx * 0.66f
    val right = boxPx * 0.74f
    val bottom = boxPx * 0.34f

    val path = android.graphics.Path().apply {
        moveTo(left, top)
        lineTo(midX, midY)
        lineTo(right, bottom)
    }
    drawContext.canvas.nativeCanvas.apply {
        val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
            this.color = android.graphics.Color.argb(
                255,
                (color.red * 255).toInt(),
                (color.green * 255).toInt(),
                (color.blue * 255).toInt(),
            )
            style = android.graphics.Paint.Style.STROKE
            this.strokeWidth = stroke
            strokeCap = android.graphics.Paint.Cap.ROUND
            strokeJoin = android.graphics.Paint.Join.ROUND
        }
        drawPath(path, paint)
    }
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawStatusCross(
    boxPx: Float,
    color: Color,
) {
    val stroke = boxPx * 0.10f
    val inset = boxPx * 0.32f
    val path = android.graphics.Path().apply {
        moveTo(inset, inset)
        lineTo(boxPx - inset, boxPx - inset)
        moveTo(boxPx - inset, inset)
        lineTo(inset, boxPx - inset)
    }
    drawContext.canvas.nativeCanvas.apply {
        val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
            this.color = android.graphics.Color.argb(
                255,
                (color.red * 255).toInt(),
                (color.green * 255).toInt(),
                (color.blue * 255).toInt(),
            )
            style = android.graphics.Paint.Style.STROKE
            this.strokeWidth = stroke
            strokeCap = android.graphics.Paint.Cap.ROUND
        }
        drawPath(path, paint)
    }
}

fun defaultFrostStatusIndicatorAppearance(context: android.content.Context): FrostStatusIndicatorAppearance {
    return FrostStatusIndicatorAppearance(
        indicatorSize = FrostControlDimens.statusIndicatorSize(context),
        strokeWidth = FrostControlDimens.statusStrokeWidth(context),
        dotRadius = FrostControlDimens.statusDotRadius(context),
        idleRingColor = FrostControlColors.statusIdleRing(context),
        inProgressDotColor = FrostControlColors.statusInProgressDot(context),
        successColor = FrostControlColors.statusSuccess(context),
        failureColor = FrostControlColors.statusFailure(context),
        glyphColor = FrostControlColors.statusGlyph(context),
    )
}
