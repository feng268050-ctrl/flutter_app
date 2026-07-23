package com.lasercyber.lws.frostui.control

import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size

internal fun Modifier.frostSliderDrawUnclipped(): Modifier =
    graphicsLayer { clip = false }

internal fun DrawScope.drawFrostSliderTrack(
    trackStartX: Float,
    trackWidthPx: Float,
    trackHeightPx: Float,
    trackTop: Float,
    trackCornerRadiusPx: Float,
    inactiveColor: androidx.compose.ui.graphics.Color,
    activeColor: androidx.compose.ui.graphics.Color,
    thumbCenterX: Float,
) {
    if (trackWidthPx <= 0f) return
    val trackRadius = CornerRadius(trackCornerRadiusPx, trackCornerRadiusPx)
    drawRoundRect(
        color = inactiveColor,
        topLeft = Offset(trackStartX, trackTop),
        size = Size(trackWidthPx, trackHeightPx),
        cornerRadius = trackRadius,
    )
    val activeWidth = (thumbCenterX - trackStartX).coerceIn(0f, trackWidthPx)
    if (activeWidth > 0f) {
        drawRoundRect(
            color = activeColor,
            topLeft = Offset(trackStartX, trackTop),
            size = Size(activeWidth, trackHeightPx),
            cornerRadius = trackRadius,
        )
    }
}

internal fun DrawScope.drawFrostSliderThumb(
    centerX: Float,
    centerY: Float,
    thumbRadiusPx: Float,
    thumbColor: androidx.compose.ui.graphics.Color,
) {
    drawCircle(
        color = thumbColor,
        radius = thumbRadiusPx,
        center = Offset(centerX, centerY),
    )
}
