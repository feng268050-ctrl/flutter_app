package com.lasercyber.lws.frostui.border

import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import kotlin.math.max

/** Vertical linear fill for frost panels (ported from [FrostedGlassPanelDrawable] fill path). */
data class PanelFillSpec(
    val topColor: Color,
    val midColor: Color,
    val bottomColor: Color,
    val cornerRadiusPx: Float,
    val borderWidthPx: Float = 0f,
)

object PanelFillPainter {

    private val fillStops = floatArrayOf(0f, 0.45f, 1f)

    fun DrawScope.drawPanelFill(
        spec: PanelFillSpec,
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

        val resolvedCornerRadius = if (spec.cornerRadiusPx < 0f) {
            minOf(right - left, bottom - top) * 0.5f
        } else {
            spec.cornerRadiusPx
        }
        val strokeRadius = max(0f, resolvedCornerRadius - inset)

        val colors = listOf(
            spec.topColor.applyAlpha(alpha),
            spec.midColor.applyAlpha(alpha),
            spec.bottomColor.applyAlpha(alpha),
        )

        drawRoundRect(
            brush = Brush.linearGradient(
                colorStops = fillStops.zip(colors).map { it.first to it.second }.toTypedArray(),
                start = Offset(left, top),
                end = Offset(left, bottom),
            ),
            topLeft = Offset(left, top),
            size = Size(right - left, bottom - top),
            cornerRadius = CornerRadius(strokeRadius, strokeRadius),
        )
    }

    fun panelFillSpec(
        context: android.content.Context,
        lightTone: Boolean = false,
        solid: Boolean = false,
        primary: Boolean = false,
        cornerRadiusPx: Float = FrostDimens.cornerRadiusPx(context),
        borderWidthPx: Float = FrostDimens.defaultBorderWidthPx(context),
    ): PanelFillSpec = when {
        primary -> PanelFillSpec(
            topColor = FrostColors.buttonPrimaryFillTop(context),
            midColor = FrostColors.buttonPrimaryFillMid(context),
            bottomColor = FrostColors.buttonPrimaryFillBottom(context),
            cornerRadiusPx = cornerRadiusPx,
            borderWidthPx = borderWidthPx,
        )
        solid -> PanelFillSpec(
            topColor = FrostColors.fillSolidTop(context),
            midColor = FrostColors.fillSolidMid(context),
            bottomColor = FrostColors.fillSolidBottom(context),
            cornerRadiusPx = cornerRadiusPx,
            borderWidthPx = borderWidthPx,
        )
        lightTone -> PanelFillSpec(
            topColor = FrostColors.lightFillTop(context),
            midColor = FrostColors.lightFillMid(context),
            bottomColor = FrostColors.lightFillBottom(context),
            cornerRadiusPx = cornerRadiusPx,
            borderWidthPx = borderWidthPx,
        )
        else -> PanelFillSpec(
            topColor = FrostColors.fillTop(context),
            midColor = FrostColors.fillMid(context),
            bottomColor = FrostColors.fillBottom(context),
            cornerRadiusPx = cornerRadiusPx,
            borderWidthPx = borderWidthPx,
        )
    }

    /** Fill spec for buttons; uses button stroke width for inset (legacy FrostedGlassButton). */
    fun buttonFillSpec(
        context: android.content.Context,
        primary: Boolean = false,
        light: Boolean = false,
        cornerRadiusPx: Float = FrostDimens.cornerRadiusPx(context),
        borderWidthPx: Float = FrostDimens.buttonStrokeWidthPx(context),
    ): PanelFillSpec = when {
        primary -> PanelFillSpec(
            topColor = FrostColors.buttonPrimaryFillTop(context),
            midColor = FrostColors.buttonPrimaryFillMid(context),
            bottomColor = FrostColors.buttonPrimaryFillBottom(context),
            cornerRadiusPx = cornerRadiusPx,
            borderWidthPx = borderWidthPx,
        )
        light -> PanelFillSpec(
            topColor = FrostColors.lightFillTop(context),
            midColor = FrostColors.lightFillMid(context),
            bottomColor = FrostColors.lightFillBottom(context),
            cornerRadiusPx = cornerRadiusPx,
            borderWidthPx = borderWidthPx,
        )
        else -> PanelFillSpec(
            topColor = FrostColors.fillTop(context),
            midColor = FrostColors.fillMid(context),
            bottomColor = FrostColors.fillBottom(context),
            cornerRadiusPx = cornerRadiusPx,
            borderWidthPx = borderWidthPx,
        )
    }

    private fun Color.applyAlpha(alpha: Float): Color =
        if (alpha >= 1f) this else copy(alpha = this.alpha * alpha)
}
