package com.lasercyber.lws.frostui.blur

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.view.View
import android.view.ViewGroup
import android.view.ViewParent
import com.lasercyber.lws.frostui.dialog.FrostResourceIds
import eightbitlab.com.blurview.BlurTarget

/**
 * Resolves the view subtree to draw when capturing card/dialog backdrop blur.
 * No dynamic window wrapping — callers snapshot directly from existing hierarchy.
 */
object FrostBackdropResolver {

    class ResolvedBackdrop(
        val drawRoot: View,
    )

    @JvmStatic
    fun resolve(card: View): ResolvedBackdrop? {
        findLocalCaptureTarget(card)?.let { target ->
            return ResolvedBackdrop(resolveCaptureTargetDrawRoot(target))
        }

        val activity = findActivity(card.context) ?: return null
        if (card.rootView != activity.window.decorView) {
            return null
        }

        val contentRoot = card.rootView.findViewById<ViewGroup>(android.R.id.content) ?: return null
        val explicit = contentRoot.rootView.findViewById<View>(captureTargetId(card))
        if (explicit is FrostCaptureTarget && !isDescendantOf(card, explicit)) {
            return ResolvedBackdrop(resolveCaptureTargetDrawRoot(explicit))
        }
        if (explicit is BlurTarget && !isDescendantOf(card, explicit)) {
            return ResolvedBackdrop(resolveCaptureTargetDrawRoot(explicit))
        }
        if (contentRoot.childCount == 0) {
            return null
        }
        val firstChild = contentRoot.getChildAt(0)
        if (firstChild is FrostCaptureTarget && !isDescendantOf(card, firstChild)) {
            return ResolvedBackdrop(resolveCaptureTargetDrawRoot(firstChild))
        }
        if (firstChild is BlurTarget && !isDescendantOf(card, firstChild)) {
            return ResolvedBackdrop(resolveCaptureTargetDrawRoot(firstChild))
        }
        // Card may live inside the page root (settings / engineer); hide it during capture.
        return ResolvedBackdrop(firstChild)
    }

    /**
     * Nearest panel-scoped backdrop layer under this card in the view stack (e.g. light dialog
     * [frost_blur_target] or home [BlurTarget]). Nested cards sample this — not activity snapshot.
     */
    @JvmStatic
    fun findLocalCaptureTarget(view: View): View? {
        var parent: ViewParent? = view.parent
        while (parent is ViewGroup) {
            for (index in 0 until parent.childCount) {
                val child = parent.getChildAt(index)
                if (isLocalBackdropLayer(child) &&
                    !isDescendantOf(view, child) &&
                    sharesWindow(view, child)
                ) {
                    return child
                }
            }
            parent = parent.parent
        }
        val overlayRoot = findDialogOverlayRoot(view)
        if (overlayRoot is ViewGroup) {
            val target = overlayRoot.findViewById<View>(captureTargetId(view))
            if (target != null && isLocalBackdropLayer(target) && sharesWindow(view, target)) {
                return target
            }
        }
        return null
    }

    private fun isLocalBackdropLayer(view: View): Boolean =
        view is FrostCaptureTarget || view is BlurTarget

  @JvmStatic
    fun resolveCaptureTargetDrawRoot(target: View): View = target

    @JvmStatic
    fun resolveContentRoot(contentRoot: ViewGroup): View? =
        resolveBackdropSnapshotRoot(contentRoot)

    /**
     * Page subtree to snapshot for dialog frozen blur: first non-overlay child of [android.R.id.content].
     * On home this is the full [activity_main] constraint root (background + stat cards), not
     * [FrostCaptureTarget] alone.
     */
    @JvmStatic
    fun resolveBackdropSnapshotRoot(contentRoot: ViewGroup): View? {
        val overlayRootId = FrostResourceIds.viewId(contentRoot.context, "frost_dialog_root")
        for (index in 0 until contentRoot.childCount) {
            val child = contentRoot.getChildAt(index)
            if (child.id == overlayRootId) {
                continue
            }
            return child
        }
        return null
    }

    private fun captureTargetId(view: View): Int =
        FrostResourceIds.viewId(view.context, "frost_blur_target")

    private fun findDialogOverlayRoot(view: View): View? {
        var current: ViewParent? = view.parent
        while (current is View) {
            if (current.id == FrostResourceIds.viewId(view.context, "frost_dialog_root")) {
                return current
            }
            current = current.parent
        }
        return null
    }

    private fun sharesWindow(first: View, second: View): Boolean =
        first.rootView === second.rootView

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
