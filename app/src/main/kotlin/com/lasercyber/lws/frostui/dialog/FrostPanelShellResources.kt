package com.lasercyber.lws.frostui.dialog

import android.content.Context
import android.graphics.drawable.Drawable

/**
 * App-layer drawable hooks for [FrostPanelShell] so frostui stays free of `ui` imports.
 * Registered from [com.lasercyber.lws.ui.component.dialog.FrostUiDialogBridge].
 */
object FrostPanelShellResources {
    @JvmField
    var backdropTintProvider: ((Context) -> Drawable)? = null

    @JvmField
    var shellBorderProvider: ((Context) -> Drawable)? = null

    @JvmField
    var shellFallbackProvider: ((Context) -> Drawable)? = null

    @JvmField
    var shellFrostForegroundProvider: ((Context) -> Drawable)? = null

    @JvmField
    var roundedClipDrawableId: Int = 0
}
