package com.lasercyber.lws.frostui.border

import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import kotlin.math.max
import kotlin.math.min

/** Border stroke for frost panels (ported from [FrostedGlassPanelDrawable] border path). */
data class PanelBorderSpec(
    val highlightColor: Color,
    val midColor: Color,
    val shadowColor: Color,
    val gradientCenter: BorderGradientCenter = BorderGradientCenter.TOP_LEFT_BOTTOM_RIGHT,
    val cornerRadiusPx: Float,
    val borderWidthPx: Float,
    val lightToneLocalizedBorder: Boolean = false,
    val drawsFill: Boolean = false,
)

object PanelBorderPainter {

    /** Localized capsule borders taper from full width at highlights to this ratio on shadow tails. */
    private const val LOCALIZED_BORDER_THIN_RATIO = 0.34f
    private const val LOCALIZED_BORDER_MID_RATIO = 0.66f

    fun DrawScope.drawPanelBorder(
        spec: PanelBorderSpec,
        alpha: Float = 1f,
    ) {
        if (size.isEmpty()) {
            return
        }

        val inset = spec.borderWidthPx * 0.5f
        val left = inset
        val top = inset
        val right = size.width - inset
        val bottom = size.height - inset
        val rect = Rect(left, top, right, bottom)

        val resolvedCornerRadius = if (spec.cornerRadiusPx < 0f) {
            min(rect.width, rect.height) * 0.5f
        } else {
            spec.cornerRadiusPx
        }
        val strokeRadius = max(0f, resolvedCornerRadius - inset)

        if (spec.gradientCenter == BorderGradientCenter.UNIFORM) {
            drawUniformBorder(spec, rect, strokeRadius, alpha)
            return
        }

        drawLocalizedBorder(spec, rect, strokeRadius, alpha)
    }

    private fun DrawScope.drawUniformBorder(
        spec: PanelBorderSpec,
        rect: Rect,
        strokeRadius: Float,
        alpha: Float,
    ) {
        drawRoundRect(
            color = uniformBorderColor(spec).applyAlpha(alpha),
            topLeft = rect.topLeft,
            size = rect.size,
            cornerRadius = CornerRadius(strokeRadius, strokeRadius),
            style = Stroke(width = spec.borderWidthPx),
        )
    }

    private fun uniformBorderColor(spec: PanelBorderSpec): Color =
        if (spec.lightToneLocalizedBorder) {
            spec.midColor
        } else {
            visibleShadowColor(spec)
        }

    /** Top edge only — matches the bright top stroke of [BorderGradientCenter.TOP_BOTTOM] panels. */
    fun DrawScope.drawPanelTopEdgeBorder(
        spec: PanelBorderSpec,
        alpha: Float = 1f,
    ) {
        if (size.isEmpty()) {
            return
        }
        val strokeWidth = spec.borderWidthPx
        val y = strokeWidth * 0.5f
        drawLine(
            brush = createLocalizedPairHighlightLinearGradient(
                spec = spec,
                startX = 0f,
                startY = y,
                endX = size.width,
                endY = y,
                alpha = alpha,
            ),
            start = Offset(0f, y),
            end = Offset(size.width, y),
            strokeWidth = strokeWidth,
            cap = StrokeCap.Butt,
        )
    }

    fun panelBorderSpec(
        context: android.content.Context,
        gradientCenter: BorderGradientCenter = BorderGradientCenter.TOP_LEFT_BOTTOM_RIGHT,
        lightTone: Boolean = false,
        primary: Boolean = false,
        lightToneLocalizedBorder: Boolean = false,
        drawsFill: Boolean = false,
        cornerRadiusPx: Float = FrostDimens.cornerRadiusPx(context),
        borderWidthPx: Float = FrostDimens.defaultBorderWidthPx(context),
    ): PanelBorderSpec = when {
        primary -> PanelBorderSpec(
            highlightColor = FrostColors.buttonPrimaryBorderHighlight(context),
            midColor = FrostColors.buttonPrimaryBorderMid(context),
            shadowColor = FrostColors.buttonPrimaryBorderShadow(context),
            gradientCenter = gradientCenter,
            cornerRadiusPx = cornerRadiusPx,
            borderWidthPx = borderWidthPx,
            lightToneLocalizedBorder = false,
            drawsFill = drawsFill,
        )
        lightTone -> PanelBorderSpec(
            highlightColor = FrostColors.lightBorderHighlight(context),
            midColor = FrostColors.lightBorderMid(context),
            shadowColor = FrostColors.lightBorderShadow(context),
            gradientCenter = gradientCenter,
            cornerRadiusPx = cornerRadiusPx,
            borderWidthPx = borderWidthPx,
            lightToneLocalizedBorder = lightToneLocalizedBorder,
            drawsFill = drawsFill,
        )
        else -> PanelBorderSpec(
            highlightColor = FrostColors.borderHighlight(context),
            midColor = FrostColors.borderMid(context),
            shadowColor = FrostColors.borderShadow(context),
            gradientCenter = gradientCenter,
            cornerRadiusPx = cornerRadiusPx,
            borderWidthPx = borderWidthPx,
            lightToneLocalizedBorder = lightToneLocalizedBorder,
            drawsFill = drawsFill,
        )
    }

    /**
     * Foreground border for [com.lasercyber.lws.frostui.card.FrostCard] / [FrostCardView].
     * Cards use localized corner highlights (same family as [FrostButton]).
     */
    fun cardBorderSpec(
        context: android.content.Context,
        gradientCenter: BorderGradientCenter = BorderGradientCenter.TOP_LEFT_BOTTOM_RIGHT,
        lightTone: Boolean = false,
        cornerRadiusPx: Float = FrostDimens.cornerRadiusPx(context),
        borderWidthPx: Float = FrostDimens.defaultBorderWidthPx(context),
    ): PanelBorderSpec = panelBorderSpec(
        context = context,
        gradientCenter = gradientCenter,
        lightTone = lightTone,
        lightToneLocalizedBorder = lightTone,
        drawsFill = false,
        cornerRadiusPx = cornerRadiusPx,
        borderWidthPx = borderWidthPx,
    )

    /**
     * Border spec for [com.lasercyber.lws.frostui.button.FrostButton] matching legacy
     * [FrostedGlassButton] stroke width (1.5dp).
     */
    fun buttonBorderSpec(
        context: android.content.Context,
        primary: Boolean = false,
        light: Boolean = false,
        gradientCenter: BorderGradientCenter = BorderGradientCenter.TOP_LEFT_BOTTOM_RIGHT,
        lightToneLocalizedBorder: Boolean? = null,
        cornerRadiusPx: Float = FrostDimens.cornerRadiusPx(context),
        borderWidthPx: Float = FrostDimens.buttonStrokeWidthPx(context),
    ): PanelBorderSpec {
        val (highlight, mid, shadow) = when {
            primary -> Triple(
                FrostColors.buttonPrimaryBorderHighlight(context),
                FrostColors.buttonPrimaryBorderMid(context),
                FrostColors.buttonPrimaryBorderShadow(context),
            )
            light -> Triple(
                FrostColors.buttonLightBorderHighlight(context),
                FrostColors.buttonLightBorderMid(context),
                FrostColors.buttonLightBorderShadow(context),
            )
            else -> Triple(
                FrostColors.borderHighlight(context),
                FrostColors.borderMid(context),
                FrostColors.borderShadow(context),
            )
        }
        return PanelBorderSpec(
            highlightColor = highlight,
            midColor = mid,
            shadowColor = shadow,
            gradientCenter = gradientCenter,
            cornerRadiusPx = cornerRadiusPx,
            borderWidthPx = borderWidthPx,
            lightToneLocalizedBorder = lightToneLocalizedBorder ?: light,
            drawsFill = true,
        )
    }

    private fun DrawScope.drawLocalizedBorder(
        spec: PanelBorderSpec,
        rect: Rect,
        strokeRadius: Float,
        alpha: Float,
    ) {
        when (spec.gradientCenter) {
            BorderGradientCenter.TOP_BOTTOM -> {
                if (spec.lightToneLocalizedBorder) {
                    drawLocalizedBaseline(spec, rect, strokeRadius, alpha)
                }
                drawLocalizedAxisBorder(
                    spec,
                    rect,
                    strokeRadius,
                    rect.left,
                    rect.top,
                    rect.left,
                    rect.bottom,
                    alpha,
                )
                return
            }
            BorderGradientCenter.LEFT_RIGHT -> {
                if (spec.lightToneLocalizedBorder) {
                    drawLocalizedBaseline(spec, rect, strokeRadius, alpha)
                }
                drawLocalizedAxisBorder(
                    spec,
                    rect,
                    strokeRadius,
                    rect.left,
                    rect.top,
                    rect.right,
                    rect.top,
                    alpha,
                )
                return
            }
            else -> Unit
        }

        drawLocalizedBaseline(spec, rect, strokeRadius, alpha)

        val diagonalRadius = resolveLocalizedCornerRadius(rect)
        when (spec.gradientCenter) {
            BorderGradientCenter.BOTTOM_LEFT_TOP_RIGHT,
            BorderGradientCenter.TOP_RIGHT_BOTTOM_LEFT,
            -> {
                drawCornerHighlight(spec, rect, strokeRadius, rect.left, rect.bottom, diagonalRadius, alpha)
                drawCornerHighlight(spec, rect, strokeRadius, rect.right, rect.top, diagonalRadius, alpha)
            }
            BorderGradientCenter.TOP_LEFT_BOTTOM_RIGHT,
            -> {
                drawCornerHighlight(spec, rect, strokeRadius, rect.left, rect.top, diagonalRadius, alpha)
                drawCornerHighlight(spec, rect, strokeRadius, rect.right, rect.bottom, diagonalRadius, alpha)
            }
            else -> Unit
        }
    }

    private fun resolveLocalizedCornerRadius(rect: Rect): Float =
        min(rect.width, rect.height) * 1.45f

    private fun DrawScope.drawLocalizedBaseline(
        spec: PanelBorderSpec,
        rect: Rect,
        strokeRadius: Float,
        alpha: Float,
    ) {
        val baselineWidth = resolveLocalizedBaselineWidth(spec)
        drawRoundRect(
            color = visibleShadowColor(spec).applyAlpha(alpha),
            topLeft = rect.topLeft,
            size = rect.size,
            cornerRadius = CornerRadius(strokeRadius, strokeRadius),
            style = Stroke(width = baselineWidth),
        )
    }

    private fun resolveLocalizedBaselineWidth(spec: PanelBorderSpec): Float =
        if (spec.lightToneLocalizedBorder) {
            spec.borderWidthPx * LOCALIZED_BORDER_THIN_RATIO
        } else {
            spec.borderWidthPx
        }

    private fun DrawScope.drawLocalizedAxisBorder(
        spec: PanelBorderSpec,
        rect: Rect,
        strokeRadius: Float,
        startX: Float,
        startY: Float,
        endX: Float,
        endY: Float,
        alpha: Float,
    ) {
        drawRoundRect(
            brush = createLocalizedPairHighlightLinearGradient(spec, startX, startY, endX, endY, alpha),
            topLeft = rect.topLeft,
            size = rect.size,
            cornerRadius = CornerRadius(strokeRadius, strokeRadius),
            style = Stroke(width = spec.borderWidthPx),
        )
    }

    private fun createLocalizedPairHighlightLinearGradient(
        spec: PanelBorderSpec,
        startX: Float,
        startY: Float,
        endX: Float,
        endY: Float,
        alpha: Float,
    ): Brush {
        val shadow = visibleShadowColor(spec)
        val stops = floatArrayOf(0f, 0.20f, 0.5f, 0.80f, 1f)
        val colors = listOf(
            withMinimumAlpha(spec.highlightColor, localizedTailAlpha(spec, 0xCC)).applyAlpha(alpha),
            blendColors(
                shadow,
                withMinimumAlpha(spec.highlightColor, localizedTailAlpha(spec, 0xA8)),
                0.38f,
            ).applyAlpha(alpha),
            shadow.applyAlpha(alpha),
            blendColors(
                shadow,
                withMinimumAlpha(spec.highlightColor, localizedTailAlpha(spec, 0xA8)),
                0.38f,
            ).applyAlpha(alpha),
            withMinimumAlpha(spec.highlightColor, localizedTailAlpha(spec, 0xCC)).applyAlpha(alpha),
        )
        return Brush.linearGradient(
            colorStops = stops.zip(colors).map { it.first to it.second }.toTypedArray(),
            start = Offset(startX, startY),
            end = Offset(endX, endY),
        )
    }

    private fun DrawScope.drawCornerHighlight(
        spec: PanelBorderSpec,
        rect: Rect,
        strokeRadius: Float,
        centerX: Float,
        centerY: Float,
        radius: Float,
        alpha: Float,
    ) {
        if (spec.lightToneLocalizedBorder) {
            drawTaperedCornerHighlight(spec, rect, strokeRadius, centerX, centerY, radius, alpha)
            return
        }
        val shadow = localizedShadowColor(spec)
        val stops = floatArrayOf(0f, 0.38f, 0.76f, 1f)
        val colors = listOf(
            withMinimumAlpha(spec.highlightColor, localizedTailAlpha(spec, 0xD4)).applyAlpha(alpha),
            blendColors(
                shadow,
                withMinimumAlpha(spec.highlightColor, localizedTailAlpha(spec, 0xB0)),
                0.52f,
            ).applyAlpha(alpha),
            blendColors(
                shadow,
                withMinimumAlpha(spec.highlightColor, localizedTailAlpha(spec, 0x80)),
                0.08f,
            ).applyAlpha(alpha),
            Color.Transparent,
        )
        drawRoundRect(
            brush = Brush.radialGradient(
                colorStops = stops.zip(colors).map { it.first to it.second }.toTypedArray(),
                center = Offset(centerX, centerY),
                radius = radius,
            ),
            topLeft = rect.topLeft,
            size = rect.size,
            cornerRadius = CornerRadius(strokeRadius, strokeRadius),
            style = Stroke(width = spec.borderWidthPx),
        )
    }

    private fun DrawScope.drawTaperedCornerHighlight(
        spec: PanelBorderSpec,
        rect: Rect,
        strokeRadius: Float,
        centerX: Float,
        centerY: Float,
        radius: Float,
        alpha: Float,
    ) {
        val shadow = localizedShadowColor(spec)
        val bright = withMinimumAlpha(spec.highlightColor, localizedTailAlpha(spec, 0xD4))
        val midBlend = blendColors(
            shadow,
            withMinimumAlpha(spec.highlightColor, localizedTailAlpha(spec, 0xB0)),
            0.52f,
        )
        val softBlend = blendColors(
            shadow,
            withMinimumAlpha(spec.highlightColor, localizedTailAlpha(spec, 0x80)),
            0.08f,
        )

        drawTaperedCornerLayer(
            spec,
            rect,
            strokeRadius,
            centerX,
            centerY,
            radius,
            spec.borderWidthPx * LOCALIZED_BORDER_THIN_RATIO,
            floatArrayOf(0f, 1f),
            listOf(softBlend, Color.Transparent),
            alpha,
        )
        drawTaperedCornerLayer(
            spec,
            rect,
            strokeRadius,
            centerX,
            centerY,
            radius * 0.72f,
            spec.borderWidthPx * LOCALIZED_BORDER_MID_RATIO,
            floatArrayOf(0f, 0.42f, 1f),
            listOf(midBlend, softBlend, Color.Transparent),
            alpha,
        )
        drawTaperedCornerLayer(
            spec,
            rect,
            strokeRadius,
            centerX,
            centerY,
            radius * 0.45f,
            spec.borderWidthPx,
            floatArrayOf(0f, 0.55f, 1f),
            listOf(bright, midBlend, Color.Transparent),
            alpha,
        )
    }

    private fun DrawScope.drawTaperedCornerLayer(
        spec: PanelBorderSpec,
        rect: Rect,
        strokeRadius: Float,
        centerX: Float,
        centerY: Float,
        radius: Float,
        strokeWidth: Float,
        stops: FloatArray,
        colors: List<Color>,
        alpha: Float,
    ) {
        if (radius <= 0f || strokeWidth <= 0f) {
            return
        }
        drawRoundRect(
            brush = Brush.radialGradient(
                colorStops = stops.zip(colors.map { it.applyAlpha(alpha) }).map { it.first to it.second }.toTypedArray(),
                center = Offset(centerX, centerY),
                radius = radius,
            ),
            topLeft = rect.topLeft,
            size = rect.size,
            cornerRadius = CornerRadius(strokeRadius, strokeRadius),
            style = Stroke(width = strokeWidth),
        )
    }

    private fun blendColors(from: Color, to: Color, toFraction: Float): Color {
        val fromFraction = 1f - toFraction
        return Color(
            red = from.red * fromFraction + to.red * toFraction,
            green = from.green * fromFraction + to.green * toFraction,
            blue = from.blue * fromFraction + to.blue * toFraction,
            alpha = from.alpha * fromFraction + to.alpha * toFraction,
        )
    }

    private fun withMinimumAlpha(color: Color, minAlpha: Int): Color {
        val min = minAlpha / 255f
        return if (color.alpha >= min) color else color.copy(alpha = min)
    }

    private fun localizedShadowColor(spec: PanelBorderSpec): Color = visibleShadowColor(spec)

    private fun visibleShadowColor(spec: PanelBorderSpec): Color {
        if (spec.lightToneLocalizedBorder && spec.drawsFill) {
            return blendColors(spec.shadowColor, spec.midColor, 0.38f)
        }
        val base = blendColors(
            spec.shadowColor,
            spec.midColor,
            if (!spec.drawsFill) 0.55f else 0.28f,
        )
        if (!spec.drawsFill) {
            return withMinimumAlpha(base, 0x88)
        }
        return base
    }

    private fun localizedTailAlpha(spec: PanelBorderSpec, alpha: Int): Int =
        if (!spec.drawsFill) max(alpha, 0x98) else alpha

    private fun Color.applyAlpha(alpha: Float): Color =
        if (alpha >= 1f) this else copy(alpha = this.alpha * alpha)
}
