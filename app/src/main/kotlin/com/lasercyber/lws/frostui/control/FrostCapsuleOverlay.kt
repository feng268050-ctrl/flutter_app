package com.lasercyber.lws.frostui.control

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp

fun frostCapsuleOverlayDarkFraction(
    fillWidthPx: Float,
    centerXPx: Float,
    transitionWidthPx: Float,
): Float {
    if (transitionWidthPx <= 0f) {
        return if (fillWidthPx >= centerXPx) 1f else 0f
    }
    val start = centerXPx - transitionWidthPx / 2f
    val end = centerXPx + transitionWidthPx / 2f
    return when {
        fillWidthPx <= start -> 0f
        fillWidthPx >= end -> 1f
        else -> (fillWidthPx - start) / (end - start)
    }
}

fun frostCapsuleOverlayColor(
    darkFraction: Float,
    lightColor: Color,
    darkColor: Color,
): Color = lerp(lightColor, darkColor, darkFraction.coerceIn(0f, 1f))
