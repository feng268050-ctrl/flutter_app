package com.lasercyber.lws.frostui.border

import android.content.Context
import android.graphics.drawable.Drawable

/** Work-status dialog shell drawables registered via [com.lasercyber.lws.ui.component.dialog.FrostUiDialogBridge]. */
object PanelShellDrawables {

    @JvmStatic
    fun workStatusShellBorder(context: Context): Drawable =
        PanelBorderDrawable.create(
            context = context,
            lightTone = true,
        )

    @JvmStatic
    fun workStatusShellFallback(context: Context): Drawable =
        PanelCompositeDrawable.create(
            context = context,
            lightTone = true,
            lightToneLocalizedBorder = true,
        )
}
