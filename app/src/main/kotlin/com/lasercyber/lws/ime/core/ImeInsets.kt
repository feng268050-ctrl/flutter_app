package com.lasercyber.lws.ime.core

import android.app.Activity
import android.graphics.Rect
import android.view.View
import android.view.ViewGroup

object ImeInsets {
    const val KEYBOARD_MARGIN_DP = 24f
    const val KEYBOARD_VISIBLE_THRESHOLD_PX = 80

    fun resolveKeyboardHeightPx(decorHeight: Int, visibleBottom: Int, imeInsetBottom: Int): Int {
        if (imeInsetBottom >= KEYBOARD_VISIBLE_THRESHOLD_PX) {
            return imeInsetBottom
        }
        return maxOf(0, decorHeight - visibleBottom)
    }

    fun effectiveKeyboardHeightPx(systemImePx: Int, customPanelPx: Int): Int =
        maxOf(systemImePx, customPanelPx)

    fun computeCardTranslationY(
        visibleTopPx: Int,
        visibleBottomPx: Int,
        cardTopOnScreenPx: Float,
        cardHeightPx: Int,
        keyboardHeightPx: Int,
        marginPx: Int,
    ): Float {
        if (keyboardHeightPx < KEYBOARD_VISIBLE_THRESHOLD_PX) {
            return 0f
        }
        val availableHeight = maxOf(0, visibleBottomPx - visibleTopPx)
        val targetTop = if (availableHeight > cardHeightPx + marginPx * 2) {
            visibleTopPx + (availableHeight - cardHeightPx) / 2f
        } else {
            maxOf(
                visibleTopPx + marginPx.toFloat(),
                visibleBottomPx - cardHeightPx - marginPx.toFloat(),
            )
        }
        return targetTop - cardTopOnScreenPx
    }

    fun computeCardTranslationY(
        activity: Activity,
        decor: View,
        card: View,
        keyboardHeightPx: Int,
        marginDp: Float = KEYBOARD_MARGIN_DP,
    ): Float {
        val parent = card.parent as? ViewGroup ?: return 0f
        val visible = Rect()
        decor.getWindowVisibleDisplayFrame(visible)
        var visibleTop = visible.top
        var visibleBottom = decor.height - keyboardHeightPx
        if (visibleBottom <= visibleTop) {
            visibleBottom = if (visible.bottom > 0) visible.bottom else visibleBottom
        }
        val parentLoc = IntArray(2)
        parent.getLocationOnScreen(parentLoc)
        val baseTopOnScreen = parentLoc[1] + card.top
        val marginPx = (marginDp * activity.resources.displayMetrics.density).toInt()
        return computeCardTranslationY(
            visibleTopPx = visibleTop,
            visibleBottomPx = visibleBottom,
            cardTopOnScreenPx = baseTopOnScreen.toFloat(),
            cardHeightPx = card.height,
            keyboardHeightPx = keyboardHeightPx,
            marginPx = marginPx,
        )
    }
}
