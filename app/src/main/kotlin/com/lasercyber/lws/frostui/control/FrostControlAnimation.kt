package com.lasercyber.lws.frostui.control

import androidx.compose.animation.core.AnimationSpec
import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.tween
import kotlin.math.pow

/** Matches [android.view.animation.DecelerateInterpolator] with factor 1.5f. */
fun decelerateEasing(factor: Float = 1.5f): Easing = Easing { fraction ->
    1f - (1f - fraction).pow(2f * factor)
}

fun switchSnapSpec(durationMs: Int = FrostControlDefaults.ANIMATION_DURATION_MS): AnimationSpec<Float> =
    tween(durationMillis = durationMs, easing = decelerateEasing())

fun segmentSlideSpec(durationMs: Int = FrostControlDefaults.SEGMENT_CROSSFADE_DURATION_MS): AnimationSpec<Float> =
    tween(durationMillis = durationMs, easing = decelerateEasing())

fun switchEdgeChecked(position: Float): Boolean = position >= 0.5f

fun switchEdgePosition(checked: Boolean): Float = if (checked) 1f else 0f
