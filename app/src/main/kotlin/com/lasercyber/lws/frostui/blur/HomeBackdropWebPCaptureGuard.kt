package com.lasercyber.lws.frostui.blur

import android.view.View
import com.lasercyber.lws.frostui.dialog.FrostResourceIds

/** Hides home WebP overlay during offscreen backdrop draw so Animatable playback is not stopped. */
object HomeBackdropWebPCaptureGuard {

    @JvmStatic
    inline fun withOverlayHidden(drawRoot: View, block: () -> Unit) {
        val overlayId = runCatching {
            FrostResourceIds.viewId(drawRoot.context, "home_webp_overlay")
        }.getOrNull()
        val overlay = overlayId?.let { drawRoot.findViewById<View>(it) }
        if (overlay == null) {
            block()
            return
        }
        val previousVisibility = overlay.visibility
        overlay.visibility = View.GONE
        try {
            block()
        } finally {
            overlay.visibility = previousVisibility
        }
    }
}
