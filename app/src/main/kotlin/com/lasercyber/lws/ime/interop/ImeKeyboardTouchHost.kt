package com.lasercyber.lws.ime.interop

import android.content.Context
import android.util.Log
import android.view.MotionEvent
import android.widget.FrameLayout

/**
 * Wraps the IME [androidx.compose.ui.platform.ComposeView] within the bottom keyboard band.
 *
 * Bounds must match the bottom IME slot height (see [ImeKeyboardOverlay.show]); a full-screen
 * host steals touches from the dialog and prevents Compose keys from receiving clicks.
 */
internal class ImeKeyboardTouchHost(context: Context) : FrameLayout(context) {
    init {
        isClickable = false
        isFocusable = false
        isFocusableInTouchMode = false
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        if (event.actionMasked == MotionEvent.ACTION_DOWN) {
            Log.d(
                TAG,
                "dispatch action=${event.actionMasked}, x=${event.x}, y=${event.y}, w=$width, h=$height",
            )
        }
        parent?.requestDisallowInterceptTouchEvent(true)
        return super.dispatchTouchEvent(event)
    }
}

private const val TAG = "FrostImeTouch"
