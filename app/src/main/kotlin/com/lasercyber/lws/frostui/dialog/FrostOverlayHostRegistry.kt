package com.lasercyber.lws.frostui.dialog

import android.app.Activity
import android.content.Context
import android.view.View

/**
 * Optional hooks registered by the app layer so frostui dialog code stays free of `ui` imports.
 */
object FrostOverlayHostRegistry {
    @JvmField
    var panelShellInstaller: ((overlay: View, context: Context) -> Unit)? = null

    @JvmField
    var panelShellReleaser: ((overlay: View) -> Unit)? = null

    @JvmField
    var frozenBackdropApplier: ((cardView: View) -> Unit)? = null

    @JvmField
    var blurRestoreHandler: ((activity: Activity) -> Unit)? = null

    @JvmField
    var immersiveSystemUiMaintainer: ((activity: Activity) -> Unit)? = null
}
