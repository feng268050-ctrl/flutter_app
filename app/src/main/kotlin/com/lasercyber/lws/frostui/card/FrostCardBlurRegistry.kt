package com.lasercyber.lws.frostui.card

import android.graphics.Bitmap
import android.view.View
import com.lasercyber.lws.frostui.blur.FrostBackdropResolver
import com.lasercyber.lws.frostui.dialog.FrostBackdropFrameMetadata
import com.lasercyber.lws.frostui.dialog.FrozenDialogAnchor

object FrostCardBlurRegistry {

    class ResolvedBackdrop(
        val drawRoot: View,
    )

    @JvmField
    var resolveBackdrop: ((View) -> ResolvedBackdrop?)? = null

    @JvmField
    var getFrozenBackdrop: ((android.app.Activity) -> Bitmap?)? = null

    /** Full-window snapshot for dialog/keyboard IME crops only — not displayed on page cards. */
    @JvmField
    var getPageFrozenBackdrop: ((android.app.Activity) -> Bitmap?)? = null

    @JvmField
    var getFrozenDialogAnchor: ((android.app.Activity) -> FrozenDialogAnchor?)? = null

    @JvmField
    var getFrozenBackdropGeneration: ((android.app.Activity) -> Int)? = null

    @JvmField
    var getPageFrozenBackdropGeneration: ((android.app.Activity) -> Int)? = null

    @JvmField
    var getFrozenBackdropFrameMetadata: ((android.app.Activity) -> FrostBackdropFrameMetadata?)? = null

    @JvmField
    var hasOverlays: ((android.app.Activity) -> Boolean)? = null

    @JvmField
    var isFrozenBackdropDeferred: ((android.app.Activity) -> Boolean)? = null

    /** Invoked when the first frosted-glass overlay is attached on an activity. */
    @JvmField
    var onOverlayAttached: ((android.app.Activity) -> Unit)? = null

    /** Invoked when the last frosted-glass overlay is removed from an activity. */
    @JvmField
    var onAllOverlaysDismissed: ((android.app.Activity) -> Unit)? = null

    init {
        resolveBackdrop = ::defaultResolveBackdrop
    }

    /** Default resolver when the app layer has not registered a custom implementation. */
    @JvmStatic
    fun defaultResolveBackdrop(card: View): ResolvedBackdrop? {
        val resolved = FrostBackdropResolver.resolve(card) ?: return null
        return ResolvedBackdrop(resolved.drawRoot)
    }
}
