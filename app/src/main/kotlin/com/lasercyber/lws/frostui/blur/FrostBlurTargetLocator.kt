package com.lasercyber.lws.frostui.blur

import android.view.View
import android.view.ViewGroup
import android.view.ViewParent

/** Resolves a sibling [FrostCaptureTarget] for views that sample backdrop outside the target (e.g. home clock). */
object FrostBlurTargetLocator {

    @JvmStatic
    fun findLocalBlurTarget(view: View): FrostCaptureTarget? {
        var parent: ViewParent? = view.parent
        while (parent is ViewGroup) {
            for (i in 0 until parent.childCount) {
                val child = parent.getChildAt(i)
                if (child is FrostCaptureTarget
                    && !isDescendantOf(view, child)
                    && sharesWindow(view, child)
                ) {
                    return child
                }
            }
            parent = parent.parent
        }
        return null
    }

    private fun isDescendantOf(view: View, ancestor: View): Boolean {
        var current: ViewParent? = view.parent
        while (current is View) {
            if (current === ancestor) {
                return true
            }
            current = current.parent
        }
        return false
    }

    private fun sharesWindow(first: View, second: View): Boolean =
        first.rootView === second.rootView
}
