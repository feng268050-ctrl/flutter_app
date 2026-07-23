package com.lasercyber.lws.frostui.control

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/**
 * Horizontal G·Y·R energy meter (bottom→top stack mapped left→right).
 * For emulator / no-GPIO preview when physical side LEDs are unavailable.
 */
@Composable
fun FrostHorizontalRhythmBar(
    litSegments: Int,
    pulseLevel: Int,
    modifier: Modifier = Modifier,
    barHeight: androidx.compose.ui.unit.Dp = 36.dp,
) {
    val pulseAlpha = (0.35f + (pulseLevel / 255f) * 0.65f).coerceIn(0.35f, 1f)
    val dimAlpha = 0.14f
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(barHeight),
    ) {
        FrostHorizontalRhythmSegment(
            threshold = 1,
            litSegments = litSegments,
            color = Color(0xFF43A047),
            dimAlpha = dimAlpha,
            pulseAlpha = pulseAlpha,
            modifier = Modifier.weight(1f),
        )
        FrostHorizontalRhythmSegment(
            threshold = 2,
            litSegments = litSegments,
            color = Color(0xFFFDD835),
            dimAlpha = dimAlpha,
            pulseAlpha = pulseAlpha,
            modifier = Modifier.weight(1f),
        )
        FrostHorizontalRhythmSegment(
            threshold = 3,
            litSegments = litSegments,
            color = Color(0xFFE53935),
            dimAlpha = dimAlpha,
            pulseAlpha = pulseAlpha,
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun FrostHorizontalRhythmSegment(
    threshold: Int,
    litSegments: Int,
    color: Color,
    dimAlpha: Float,
    pulseAlpha: Float,
    modifier: Modifier = Modifier,
) {
    val lit = litSegments >= threshold
    Box(
        modifier = modifier
            .fillMaxHeight()
            .background(if (lit) color.copy(alpha = pulseAlpha) else color.copy(alpha = dimAlpha)),
    )
}
