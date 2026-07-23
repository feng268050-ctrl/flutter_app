package com.lasercyber.lws.frostui.button.interop

import android.view.ViewGroup
import android.widget.LinearLayout
import androidx.constraintlayout.widget.ConstraintLayout

/**
 * Maps [ViewGroup.LayoutParams] to Compose [fillMaxWidth]/[fillMaxHeight] only when the View
 * shell already has a fixed size from XML. Wrap-content axes are left to Compose intrinsic measure.
 */
internal object FrostButtonMeasure {

    /** Exact dp, match_parent, ConstraintLayout match-constraint (`0dp`), or linear weight. */
    fun shouldFillWidth(lp: ViewGroup.LayoutParams): Boolean {
        if (lp.width > 0 || lp.width == ViewGroup.LayoutParams.MATCH_PARENT) {
            return true
        }
        if (lp.width != 0) {
            return false
        }
        if (lp is LinearLayout.LayoutParams && lp.weight > 0f) {
            return true
        }
        if (lp is ConstraintLayout.LayoutParams) {
            return true
        }
        return false
    }

    fun shouldFillHeight(lp: ViewGroup.LayoutParams): Boolean {
        if (lp.height > 0 || lp.height == ViewGroup.LayoutParams.MATCH_PARENT) {
            return true
        }
        if (lp.height != 0) {
            return false
        }
        if (lp is LinearLayout.LayoutParams && lp.weight > 0f) {
            return true
        }
        if (lp is ConstraintLayout.LayoutParams) {
            return true
        }
        return false
    }
}
