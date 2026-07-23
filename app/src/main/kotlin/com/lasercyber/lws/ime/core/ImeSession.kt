package com.lasercyber.lws.ime.core

import android.app.Activity
import android.graphics.Rect
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.view.WindowManager
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.lasercyber.lws.ime.ImeRegistry
import java.lang.ref.WeakReference

internal class ImeSession internal constructor(
    val activity: Activity,
    val config: ImeConfig,
) {
    var refCount: Int = 0
    var savedSoftInputMode: Int = 0
    var softInputModeSaved: Boolean = false
    var overlayRef: WeakReference<View>? = null
    var anchor: ImeAnchor? = null
    var cardRef: WeakReference<View>? = null
    var layoutListener: ViewTreeObserver.OnGlobalLayoutListener? = null
    var customPanelHeightPx: Int = 0
    var keyboardShownNotified: Boolean = false

    fun withAdjustNothing(savedMode: Int): Int =
        (savedMode and WindowManager.LayoutParams.SOFT_INPUT_MASK_ADJUST.inv()) or
            WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING
}
