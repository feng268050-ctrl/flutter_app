package com.lasercyber.lws.frostui.button

import com.lasercyber.lws.frostui.common.FrostUiClickSoundRegistry

import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.isSpecified
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import com.lasercyber.lws.frostui.border.BorderGradientCenter
import com.lasercyber.lws.frostui.border.FrostColors
import com.lasercyber.lws.frostui.border.FrostDimens
import com.lasercyber.lws.frostui.border.FrostResources
import com.lasercyber.lws.frostui.border.PanelBorderPainter
import com.lasercyber.lws.frostui.border.PanelFillPainter
import com.lasercyber.lws.frostui.border.frostPanelBorder
import com.lasercyber.lws.frostui.border.frostPanelFill

enum class FrostButtonVariant { DEFAULT, PRIMARY, SECONDARY, LIGHT }

enum class FrostButtonShape { ROUNDED, RECTANGLE }

enum class FrostButtonSize { DEFAULT, SMALL }

private const val DISABLED_TEXT_ALPHA = 0.45f

/** Legacy [FrostedGlassButton] used -1 px to mean a pill (half-height) corner radius. */
private const val PILL_CORNER_RADIUS_PX = -1f

@Composable
fun FrostButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    variant: FrostButtonVariant = FrostButtonVariant.DEFAULT,
    shape: FrostButtonShape = FrostButtonShape.ROUNDED,
    size: FrostButtonSize = FrostButtonSize.DEFAULT,
    enabled: Boolean = true,
    borderGradientCenter: BorderGradientCenter = BorderGradientCenter.TOP_LEFT_BOTTOM_RIGHT,
    cornerRadius: Dp? = null,
    lightToneLocalizedBorder: Boolean? = null,
    minWidth: Dp? = null,
    horizontalPadding: Dp? = null,
    horizontalPaddingStart: Dp? = null,
    horizontalPaddingEnd: Dp? = null,
    verticalPaddingTop: Dp? = null,
    verticalPaddingBottom: Dp? = null,
    textColorOverride: Color? = null,
    textSize: TextUnit? = null,
    singleLine: Boolean = true,
    drawableStart: Painter? = null,
    drawableEnd: Painter? = null,
    drawablePadding: Dp = 4.dp,
    drawableTint: Color? = null,
    interactionSource: MutableInteractionSource = rememberFrostButtonInteractionSource(),
    playClickSound: Boolean = true,
) {
    val context = LocalContext.current
    val defaultTextColor = when (variant) {
        FrostButtonVariant.SECONDARY -> FrostColors.buttonSecondaryText(context)
        FrostButtonVariant.LIGHT,
        FrostButtonVariant.PRIMARY,
        FrostButtonVariant.DEFAULT,
        -> Color.White
    }
    val baseTextColor = textColorOverride ?: defaultTextColor
    val resolvedTextColor = if (enabled) {
        baseTextColor
    } else {
        baseTextColor.copy(alpha = baseTextColor.alpha * DISABLED_TEXT_ALPHA)
    }
    val resolvedTextSize = textSize ?: FrostResources.dimenSp(context, "frost_action_button_text_size")

    FrostButton(
        onClick = onClick,
        modifier = modifier,
        variant = variant,
        shape = shape,
        size = size,
        enabled = enabled,
        borderGradientCenter = borderGradientCenter,
        cornerRadius = cornerRadius,
        lightToneLocalizedBorder = lightToneLocalizedBorder,
        minWidth = minWidth,
        horizontalPadding = horizontalPadding,
        horizontalPaddingStart = horizontalPaddingStart,
        horizontalPaddingEnd = horizontalPaddingEnd,
        verticalPaddingTop = verticalPaddingTop,
        verticalPaddingBottom = verticalPaddingBottom,
        interactionSource = interactionSource,
        playClickSound = playClickSound,
    ) {
        FrostButtonLabel(
            text = text,
            textColor = resolvedTextColor,
            textSize = resolvedTextSize,
            singleLine = singleLine,
            drawableStart = drawableStart,
            drawableEnd = drawableEnd,
            drawablePadding = drawablePadding,
            drawableTint = drawableTint ?: resolvedTextColor,
        )
    }
}

@Composable
fun FrostButton(
    onClick: (() -> Unit)?,
    modifier: Modifier = Modifier,
    variant: FrostButtonVariant = FrostButtonVariant.DEFAULT,
    shape: FrostButtonShape = FrostButtonShape.ROUNDED,
    size: FrostButtonSize = FrostButtonSize.DEFAULT,
    enabled: Boolean = true,
    borderGradientCenter: BorderGradientCenter = BorderGradientCenter.TOP_LEFT_BOTTOM_RIGHT,
    cornerRadius: Dp? = null,
    lightToneLocalizedBorder: Boolean? = null,
    minWidth: Dp? = null,
    horizontalPadding: Dp? = null,
    horizontalPaddingStart: Dp? = null,
    horizontalPaddingEnd: Dp? = null,
    verticalPaddingTop: Dp? = null,
    verticalPaddingBottom: Dp? = null,
    interactionSource: MutableInteractionSource = rememberFrostButtonInteractionSource(),
    playClickSound: Boolean = true,
    content: @Composable () -> Unit,
) {
    val context = LocalContext.current
    val density = LocalDensity.current
    val panelCornerRadiusPx = when {
        shape == FrostButtonShape.ROUNDED && cornerRadius == null -> PILL_CORNER_RADIUS_PX
        cornerRadius != null -> with(density) { cornerRadius.toPx() }
        else -> FrostResources.dimenPx(context, "frost_rectangle_button_corner_radius")
    }
    val resolvedHorizontalPaddingStart = FrostButtonDefaults.resolveHorizontalPaddingStart(
        context = context,
        size = size,
        horizontalPadding = horizontalPadding,
        horizontalPaddingStart = horizontalPaddingStart,
    )
    val resolvedHorizontalPaddingEnd = FrostButtonDefaults.resolveHorizontalPaddingEnd(
        context = context,
        size = size,
        horizontalPadding = horizontalPadding,
        horizontalPaddingEnd = horizontalPaddingEnd,
    )
    val resolvedVerticalPaddingTop = verticalPaddingTop ?: 0.dp
    val resolvedVerticalPaddingBottom = verticalPaddingBottom ?: 0.dp
    val resolvedMinHeight = FrostButtonDefaults.minHeight(context, size)
    val panelPrimary = variant == FrostButtonVariant.PRIMARY
    val panelLight = variant == FrostButtonVariant.LIGHT
    val buttonStrokeWidthPx = FrostDimens.buttonStrokeWidthPx(context)
    val fillSpec = PanelFillPainter.buttonFillSpec(
        context = context,
        primary = panelPrimary,
        light = panelLight,
        cornerRadiusPx = panelCornerRadiusPx,
        borderWidthPx = buttonStrokeWidthPx,
    )
    val borderSpec = PanelBorderPainter.buttonBorderSpec(
        context = context,
        primary = panelPrimary,
        light = panelLight,
        gradientCenter = borderGradientCenter,
        lightToneLocalizedBorder = lightToneLocalizedBorder,
        cornerRadiusPx = panelCornerRadiusPx,
        borderWidthPx = buttonStrokeWidthPx,
    )
    val rippleClipShape = remember(panelCornerRadiusPx, buttonStrokeWidthPx) {
        frostButtonRippleClipShape(
            cornerRadiusPx = panelCornerRadiusPx,
            borderWidthPx = buttonStrokeWidthPx,
        )
    }

    Box(
        modifier = modifier
            .then(
                if (minWidth != null) {
                    Modifier.defaultMinSize(minWidth = minWidth, minHeight = resolvedMinHeight)
                } else {
                    Modifier.defaultMinSize(minHeight = resolvedMinHeight)
                },
            )
            .frostButtonPressAlpha(
                interactionSource = interactionSource,
                variant = variant,
                enabled = enabled,
            )
            .frostPanelFill(
                spec = fillSpec,
            )
            .frostPanelBorder(
                spec = borderSpec,
            )
            .frostButtonRippleIndication(
                interactionSource = interactionSource,
                variant = variant,
                clipShape = rippleClipShape,
            )
            .then(
                if (onClick != null) {
                    Modifier.clickable(
                        enabled = enabled,
                        interactionSource = interactionSource,
                        indication = null,
                        onClick = {
                            if (enabled) {
                                if (playClickSound) {
                                    FrostUiClickSoundRegistry.playClick()
                                }
                                onClick()
                            }
                        },
                    )
                } else {
                    Modifier
                },
            )
            .padding(
                start = resolvedHorizontalPaddingStart,
                end = resolvedHorizontalPaddingEnd,
                top = resolvedVerticalPaddingTop,
                bottom = resolvedVerticalPaddingBottom,
            ),
        contentAlignment = Alignment.Center,
    ) {
        content()
    }
}

@Composable
private fun FrostButtonLabel(
    text: String,
    textColor: Color,
    textSize: TextUnit,
    singleLine: Boolean,
    drawableStart: Painter?,
    drawableEnd: Painter?,
    drawablePadding: Dp,
    drawableTint: Color,
) {
    val density = LocalDensity.current
    val textLineHeight = with(density) { textSize.toDp() }
    val iconSizeFor: (Painter) -> Dp = { painter ->
        val intrinsic = painter.intrinsicSize
        val fromDrawable = if (intrinsic.isSpecified && intrinsic.width.isFinite() && intrinsic.height.isFinite()) {
            with(density) {
                maxOf(intrinsic.width, intrinsic.height).toDp().coerceAtLeast(1.dp)
            }
        } else {
            textLineHeight
        }
        minOf(fromDrawable, textLineHeight)
    }
    val textModifier = Modifier
    if (drawableStart == null && drawableEnd == null) {
        Text(
            text = text,
            color = textColor,
            fontSize = textSize,
            textAlign = TextAlign.Center,
            maxLines = if (singleLine) 1 else Int.MAX_VALUE,
            softWrap = !singleLine,
            overflow = TextOverflow.Clip,
            style = androidx.compose.ui.text.TextStyle(
                platformStyle = PlatformTextStyle(includeFontPadding = true),
            ),
            modifier = textModifier,
        )
        return
    }

    Row(
        modifier = Modifier,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (drawableStart != null) {
            Icon(
                painter = drawableStart,
                contentDescription = null,
                tint = drawableTint,
                modifier = Modifier.size(iconSizeFor(drawableStart)),
            )
            if (text.isNotEmpty()) {
                Spacer(modifier = Modifier.width(drawablePadding))
            }
        }
        if (text.isNotEmpty()) {
            Text(
                text = text,
                color = textColor,
                fontSize = textSize,
                textAlign = TextAlign.Center,
                maxLines = if (singleLine) 1 else Int.MAX_VALUE,
                softWrap = !singleLine,
                overflow = TextOverflow.Clip,
                style = androidx.compose.ui.text.TextStyle(
                    platformStyle = PlatformTextStyle(includeFontPadding = true),
                ),
                modifier = textModifier,
            )
        }
        if (drawableEnd != null) {
            if (text.isNotEmpty()) {
                Spacer(modifier = Modifier.width(drawablePadding))
            }
            Icon(
                painter = drawableEnd,
                contentDescription = null,
                tint = drawableTint,
                modifier = Modifier.size(iconSizeFor(drawableEnd)),
            )
        }
    }
}
