package com.lasercyber.lws.frostui.button

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.indication
import androidx.compose.foundation.interaction.InteractionSource
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.material.ripple.rememberRipple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import kotlin.math.max
import kotlin.math.min

/** Press feedback tokens aligned with legacy `FrostedGlassButton` (View). */
object FrostButtonPressDefaults {
    const val RESTING_ALPHA = 225f / 255f
    const val PRESSED_ALPHA = 1f
    const val DISABLED_ALPHA = 110f / 255f
    const val DEFAULT_RIPPLE_ALPHA = 0x3D / 255f
    const val SECONDARY_RIPPLE_ALPHA = 0x2A / 255f
    const val LIGHT_RIPPLE_ALPHA = 0x33 / 255f
    private const val PRESS_IN_MS = 70
    private const val RELEASE_MS = 140

    fun alphaAnimationSpec(pressed: Boolean) = tween<Float>(
        durationMillis = if (pressed) PRESS_IN_MS else RELEASE_MS,
    )

    fun restingAlpha(variant: FrostButtonVariant): Float = when (variant) {
        FrostButtonVariant.PRIMARY,
        FrostButtonVariant.LIGHT,
        -> PRESSED_ALPHA
        FrostButtonVariant.SECONDARY,
        FrostButtonVariant.DEFAULT,
        -> RESTING_ALPHA
    }

    fun rippleAlpha(variant: FrostButtonVariant): Float = when (variant) {
        FrostButtonVariant.SECONDARY -> SECONDARY_RIPPLE_ALPHA
        FrostButtonVariant.LIGHT -> LIGHT_RIPPLE_ALPHA
        FrostButtonVariant.PRIMARY,
        FrostButtonVariant.DEFAULT,
        -> DEFAULT_RIPPLE_ALPHA
    }

    fun rippleColor(variant: FrostButtonVariant): Color = when (variant) {
        FrostButtonVariant.LIGHT -> Color.Black.copy(alpha = rippleAlpha(variant))
        else -> Color.White.copy(alpha = rippleAlpha(variant))
    }
}

@Composable
fun rememberFrostButtonInteractionSource(): MutableInteractionSource = remember { MutableInteractionSource() }

/**
 * Ripple clip aligned to [com.lasercyber.lws.frostui.border.PanelFillPainter] fill geometry
 * (inset by half the stroke width, corner radius reduced by the same inset).
 */
fun frostButtonRippleClipShape(
    cornerRadiusPx: Float,
    borderWidthPx: Float,
): Shape = object : Shape {
    override fun createOutline(
        size: Size,
        layoutDirection: LayoutDirection,
        density: Density,
    ): Outline {
        if (size.isEmpty()) {
            return Outline.Rectangle(Rect.Zero)
        }
        val inset = borderWidthPx * 0.5f
        val left = inset
        val top = inset
        val right = size.width - inset
        val bottom = size.height - inset
        val resolvedCornerRadius = if (cornerRadiusPx < 0f) {
            min(right - left, bottom - top) * 0.5f
        } else {
            cornerRadiusPx
        }
        val strokeRadius = max(0f, resolvedCornerRadius - inset)
        return Outline.Rounded(
            RoundRect(
                left = left,
                top = top,
                right = right,
                bottom = bottom,
                cornerRadius = CornerRadius(strokeRadius, strokeRadius),
            ),
        )
    }
}

@Composable
fun rememberFrostButtonRipple(
    variant: FrostButtonVariant,
    bounded: Boolean = true,
    radius: Dp = Dp.Unspecified,
) = rememberRipple(
    bounded = bounded,
    radius = radius,
    color = FrostButtonPressDefaults.rippleColor(variant),
)

fun Modifier.frostButtonPressAlpha(
    interactionSource: InteractionSource,
    variant: FrostButtonVariant,
    enabled: Boolean = true,
): Modifier = composed {
    val pressed by interactionSource.collectIsPressedAsState()
    val restingAlpha = if (enabled) {
        FrostButtonPressDefaults.restingAlpha(variant)
    } else {
        FrostButtonPressDefaults.DISABLED_ALPHA
    }
    val targetAlpha = when {
        !enabled -> FrostButtonPressDefaults.DISABLED_ALPHA
        pressed -> FrostButtonPressDefaults.PRESSED_ALPHA
        else -> restingAlpha
    }
    val alpha by animateFloatAsState(
        targetValue = targetAlpha,
        animationSpec = FrostButtonPressDefaults.alphaAnimationSpec(pressed && enabled),
        label = "frostButtonPressAlpha",
    )
    graphicsLayer { this.alpha = alpha }
}

fun Modifier.frostButtonRippleIndication(
    interactionSource: InteractionSource,
    variant: FrostButtonVariant,
    clipShape: Shape,
): Modifier = composed {
    val ripple = rememberFrostButtonRipple(variant = variant)
    clip(clipShape).indication(interactionSource, ripple)
}
