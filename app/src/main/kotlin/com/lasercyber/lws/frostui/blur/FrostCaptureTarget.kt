package com.lasercyber.lws.frostui.blur

import android.content.Context
import android.util.AttributeSet
import eightbitlab.com.blurview.BlurTarget

/**
 * Marks a subtree whose first child is the drawable backdrop for live [BlurView] sampling
 * (home stat cards, light dialog shell). Extends [BlurTarget] for GPU backdrop blur.
 */
class FrostCaptureTarget @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : BlurTarget(context, attrs)
