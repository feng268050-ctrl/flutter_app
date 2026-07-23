package com.lasercyber.lws.frostui.border

import android.content.Context
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.runtime.Composable
import androidx.compose.ui.composed

fun Modifier.frostPanelFill(
    spec: PanelFillSpec,
    alpha: Float = 1f,
): Modifier = drawBehind {
    with(PanelFillPainter) { drawPanelFill(spec, alpha) }
}

fun Modifier.frostPanelFill(
    context: Context,
    lightTone: Boolean = false,
    solid: Boolean = false,
    primary: Boolean = false,
    cornerRadiusPx: Float = FrostDimens.cornerRadiusPx(context),
    alpha: Float = 1f,
): Modifier = frostPanelFill(
    spec = PanelFillPainter.panelFillSpec(context, lightTone, solid, primary, cornerRadiusPx),
    alpha = alpha,
)

fun Modifier.frostPanelBorder(
    spec: PanelBorderSpec,
    alpha: Float = 1f,
): Modifier = drawBehind {
    with(PanelBorderPainter) { drawPanelBorder(spec, alpha) }
}

fun Modifier.frostPanelBorder(
    context: Context,
    gradientCenter: BorderGradientCenter = BorderGradientCenter.TOP_LEFT_BOTTOM_RIGHT,
    lightTone: Boolean = false,
    primary: Boolean = false,
    lightToneLocalizedBorder: Boolean = false,
    drawsFill: Boolean = false,
    cornerRadiusPx: Float = FrostDimens.cornerRadiusPx(context),
    borderWidthPx: Float = FrostDimens.defaultBorderWidthPx(context),
    alpha: Float = 1f,
): Modifier = frostPanelBorder(
    spec = PanelBorderPainter.panelBorderSpec(
        context = context,
        gradientCenter = gradientCenter,
        lightTone = lightTone,
        primary = primary,
        lightToneLocalizedBorder = lightToneLocalizedBorder,
        drawsFill = drawsFill,
        cornerRadiusPx = cornerRadiusPx,
        borderWidthPx = borderWidthPx,
    ),
    alpha = alpha,
)

/** Compose-friendly overload resolving token colors from [Context]. */
@Composable
fun Modifier.frostPanelFill(
    lightTone: Boolean = false,
    solid: Boolean = false,
    primary: Boolean = false,
    cornerRadius: Dp = FrostDimens.cornerRadius(LocalContext.current),
    alpha: Float = 1f,
): Modifier = composed {
    val context = LocalContext.current
    val cornerRadiusPx = with(LocalDensity.current) { cornerRadius.toPx() }
    frostPanelFill(
        context = context,
        lightTone = lightTone,
        solid = solid,
        primary = primary,
        cornerRadiusPx = cornerRadiusPx,
        alpha = alpha,
    )
}

/** Compose-friendly overload resolving token colors from [Context]. */
@Composable
fun Modifier.frostPanelBorder(
    gradientCenter: BorderGradientCenter = BorderGradientCenter.TOP_LEFT_BOTTOM_RIGHT,
    lightTone: Boolean = false,
    primary: Boolean = false,
    lightToneLocalizedBorder: Boolean = false,
    drawsFill: Boolean = false,
    cornerRadius: Dp = FrostDimens.cornerRadius(LocalContext.current),
    borderWidth: Dp? = null,
    alpha: Float = 1f,
): Modifier = composed {
    val context = LocalContext.current
    val density = LocalDensity.current
    val cornerRadiusPx = with(density) { cornerRadius.toPx() }
    val borderWidthPx = borderWidth?.let { with(density) { it.toPx() } }
        ?: FrostDimens.defaultBorderWidthPx(context)
    frostPanelBorder(
        context = context,
        gradientCenter = gradientCenter,
        lightTone = lightTone,
        primary = primary,
        lightToneLocalizedBorder = lightToneLocalizedBorder,
        drawsFill = drawsFill,
        cornerRadiusPx = cornerRadiusPx,
        borderWidthPx = borderWidthPx,
        alpha = alpha,
    )
}

/** Combined fill + border behind content (matches full [FrostedGlassPanelDrawable] panel). */
fun Modifier.frostPanel(
    fillSpec: PanelFillSpec,
    borderSpec: PanelBorderSpec,
    drawFill: Boolean = true,
    drawBorder: Boolean = true,
    alpha: Float = 1f,
): Modifier = drawBehind {
    if (drawFill) {
        with(PanelFillPainter) { drawPanelFill(fillSpec, alpha) }
    }
    if (drawBorder) {
        with(PanelBorderPainter) { drawPanelBorder(borderSpec, alpha) }
    }
}

fun Modifier.frostPanel(
    context: Context,
    gradientCenter: BorderGradientCenter = BorderGradientCenter.TOP_LEFT_BOTTOM_RIGHT,
    lightTone: Boolean = false,
    solid: Boolean = false,
    lightToneLocalizedBorder: Boolean = false,
    drawFill: Boolean = true,
    drawBorder: Boolean = true,
    cornerRadiusPx: Float = FrostDimens.cornerRadiusPx(context),
    borderWidthPx: Float = FrostDimens.defaultBorderWidthPx(context),
    alpha: Float = 1f,
): Modifier = frostPanel(
    fillSpec = PanelFillPainter.panelFillSpec(
        context,
        lightTone,
        solid,
        primary = false,
        cornerRadiusPx = cornerRadiusPx,
    ),
    borderSpec = PanelBorderPainter.panelBorderSpec(
        context = context,
        gradientCenter = gradientCenter,
        lightTone = lightTone,
        lightToneLocalizedBorder = lightToneLocalizedBorder,
        drawsFill = drawFill,
        cornerRadiusPx = cornerRadiusPx,
        borderWidthPx = borderWidthPx,
    ),
    drawFill = drawFill,
    drawBorder = drawBorder,
    alpha = alpha,
)
