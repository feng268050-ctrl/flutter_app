package com.lasercyber.lws.frostui.blur

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.graphics.drawable.Drawable
import android.os.Build
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider
import android.view.ViewParent
import eightbitlab.com.blurview.BlurTarget
import eightbitlab.com.blurview.BlurView

/** Shared live [BlurView] setup for frost cards (home stat tiles, [FrostCardView], etc.). */
object FrostBlurViewSupport {

    private const val TAG = "FrostBlurView"
    const val BLUR_SCALE_FACTOR = 3f

    @JvmStatic
    fun findSiblingBlurTarget(card: View): BlurTarget? {
        var parent: ViewParent? = card.parent
        while (parent is ViewGroup) {
            for (index in 0 until parent.childCount) {
                val child = parent.getChildAt(index)
                if (child is BlurTarget &&
                    !isDescendantOf(card, child) &&
                    sharesWindow(card, child)
                ) {
                    return child
                }
            }
            parent = parent.parent
        }
        return null
    }

    /** Panel-local [BlurTarget] first, then sibling target (e.g. home stat cards). */
    @JvmStatic
    fun findBlurTarget(card: View): BlurTarget? {
        val local = FrostBackdropResolver.findLocalCaptureTarget(card)
        if (local is BlurTarget) {
            return local
        }
        return findSiblingBlurTarget(card)
    }

    @JvmStatic
    @JvmOverloads
    fun setupBlurView(
        blurView: BlurView,
        blurTarget: BlurTarget,
        context: Context,
        overlayColor: Int,
        blurRadius: Float,
        freezeAfterSettle: Boolean = true,
    ): Boolean {
        val hostRoot = blurView.rootView
        if (hostRoot == null || !hostRoot.isHardwareAccelerated) {
            Log.w(TAG, "Host window not hardware-accelerated; blur disabled")
            blurView.setBlurEnabled(false)
            return false
        }
        if (!sharesWindow(blurView, blurTarget)) {
            Log.w(TAG, "BlurView and BlurTarget are in different windows; blur disabled")
            blurView.setBlurEnabled(false)
            return false
        }

        var frameClearDrawable: Drawable? = hostRoot.background
        if (frameClearDrawable == null) {
            val activity = findActivity(context)
            frameClearDrawable = activity?.window?.decorView?.background
        }
        return try {
            val applyNoise = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
            blurView.setupWith(blurTarget, BLUR_SCALE_FACTOR, applyNoise)
                .setFrameClearDrawable(frameClearDrawable)
                .setBlurRadius(blurRadius)
                .setOverlayColor(overlayColor)
            if (freezeAfterSettle) {
                settleAndFreezeBlur(blurView)
            } else {
                blurView.setBlurAutoUpdate(true)
                blurView.invalidate()
            }
            applyRoundedClip(blurView)
            true
        } catch (exception: RuntimeException) {
            Log.e(TAG, "BlurView setup failed; blur disabled", exception)
            blurView.setBlurEnabled(false)
            false
        }
    }

    /** Triple-invalidate then stop live updates (legacy BlurView settle). */
    @JvmStatic
    fun settleAndFreezeBlur(blurView: BlurView) {
        blurView.post {
            blurView.invalidate()
            blurView.post {
                blurView.invalidate()
                blurView.post { blurView.setBlurAutoUpdate(false) }
            }
        }
    }

    @JvmStatic
    fun applyRoundedClip(view: View) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return
        }
        view.outlineProvider = ViewOutlineProvider.BACKGROUND
        view.clipToOutline = true
    }

    private fun sharesWindow(first: View, second: View): Boolean =
        first.rootView === second.rootView

    private fun isDescendantOf(view: View, ancestor: View): Boolean {
        var parent: ViewParent? = view.parent
        while (parent is View) {
            if (parent === ancestor) {
                return true
            }
            parent = parent.parent
        }
        return false
    }

    private fun findActivity(context: Context?): Activity? {
        var current = context
        while (current is ContextWrapper) {
            if (current is Activity) {
                return current
            }
            current = current.baseContext
        }
        return null
    }
}
