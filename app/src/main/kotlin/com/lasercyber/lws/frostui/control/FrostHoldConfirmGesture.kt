package com.lasercyber.lws.frostui.control

import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.clipPath

/** Observable ripple progress for Compose overlays driven by [FrostHoldConfirmController] or custom gesture. */
@Stable
class FrostHoldConfirmState internal constructor() {
    var progress by mutableFloatStateOf(0f)
    var origin by mutableStateOf(Offset.Zero)
    var isHolding by mutableStateOf(false)
}

@Composable
fun rememberFrostHoldConfirmState(): FrostHoldConfirmState = remember { FrostHoldConfirmState() }

fun Modifier.frostReversibleRippleOverlay(
    state: FrostHoldConfirmState,
    appearance: FrostReversibleRippleAppearance,
): Modifier = drawWithContent {
    drawContent()
    if (state.progress <= 0f) {
        return@drawWithContent
    }
    val cornerRadius = appearance.cornerRadiusPx
    val clip = Path().apply {
        addRoundRect(
            RoundRect(
                rect = Rect(0f, 0f, size.width, size.height),
                cornerRadius = CornerRadius(cornerRadius, cornerRadius),
            ),
        )
    }
    val maxRadius = frostReversibleRippleCoverRadius(
        boundsLeft = 0f,
        boundsTop = 0f,
        boundsRight = size.width,
        boundsBottom = size.height,
        originX = state.origin.x,
        originY = state.origin.y,
    )
    clipPath(clip) {
        drawCircle(
            color = Color(appearance.rippleColor),
            radius = maxRadius * state.progress,
            center = state.origin,
        )
    }
}
