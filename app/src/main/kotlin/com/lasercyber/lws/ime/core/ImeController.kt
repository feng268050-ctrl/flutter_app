package com.lasercyber.lws.ime.core

import android.app.Activity
import android.content.Context
import android.graphics.Rect
import android.os.Build
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.view.Window
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.lasercyber.lws.ime.ImeRegistry
import com.lasercyber.lws.ime.interop.ViewImeAnchor
import java.util.WeakHashMap

object ImeController {
    private val sessions = WeakHashMap<Activity, ImeSession>()

    @JvmStatic
    fun attach(
        activity: Activity,
        sessionKey: Any,
        anchor: ImeAnchor,
        cardView: View,
        overlayRoot: View,
        config: ImeConfig = ImeConfig.defaults(),
    ) {
        val session = sessions.getOrPut(activity) { ImeSession(activity, config) }
        if (session.refCount == 0) {
            val window = activity.window
            if (window != null && config.hostAdjustPolicy == HostAdjustPolicy.AdjustNothing) {
                session.savedSoftInputMode = window.attributes.softInputMode
                session.softInputModeSaved = true
                window.setSoftInputMode(session.withAdjustNothing(session.savedSoftInputMode))
            }
            val decor = activity.window?.decorView
            if (decor != null) {
                session.layoutListener = ViewTreeObserver.OnGlobalLayoutListener {
                    syncCardPosition(activity)
                }
                decor.viewTreeObserver.addOnGlobalLayoutListener(session.layoutListener)
            }
        }
        session.refCount++
        session.anchor = anchor
        session.overlayRef = java.lang.ref.WeakReference(overlayRoot)
        session.cardRef = java.lang.ref.WeakReference(cardView)
        ViewCompat.setOnApplyWindowInsetsListener(overlayRoot) { view, insets ->
            syncCardPosition(activity)
            ViewCompat.onApplyWindowInsets(view, insets)
        }
        cardView.translationY = 0f
        overlayRoot.translationY = 0f
        ViewCompat.requestApplyInsets(overlayRoot)
        cardView.post {
            syncCardPosition(activity)
            ImeRegistry.onCardBackdropRefresh?.invoke(cardView)
        }
        @Suppress("UNUSED_VARIABLE")
        val ignoredKey = sessionKey
    }

    @JvmStatic
    fun attach(
        activity: Activity,
        sessionKey: Any,
        overlayRoot: View,
        cardView: View,
        config: ImeConfig = ImeConfig.defaults(),
    ) {
        attach(activity, sessionKey, ViewImeAnchor(cardView), cardView, overlayRoot, config)
    }

    @JvmStatic
    fun detach(activity: Activity?, overlayRoot: View?) {
        if (activity == null) {
            return
        }
        val session = sessions[activity] ?: return
        session.anchor?.resetLift()
        session.cardRef?.get()?.translationY = 0f
        if (overlayRoot != null) {
            ViewCompat.setOnApplyWindowInsetsListener(overlayRoot, null)
            overlayRoot.translationY = 0f
        }
        session.refCount = maxOf(0, session.refCount - 1)
        if (session.refCount > 0) {
            return
        }
        session.overlayRef?.get()?.let { overlay ->
            ViewCompat.setOnApplyWindowInsetsListener(overlay, null)
        }
        removeLayoutListener(activity, session)
        session.anchor = null
        session.cardRef = null
        session.overlayRef = null
        session.customPanelHeightPx = 0
        session.keyboardShownNotified = false
        restoreHostWindow(activity, session)
        sessions.remove(activity)
    }

    @JvmStatic
    fun showCustomKeyboard(activity: Activity, panelHeightPx: Int) {
        val session = sessions[activity] ?: return
        session.customPanelHeightPx = panelHeightPx
        session.keyboardShownNotified = false
        syncCardPosition(activity)
    }

    @JvmStatic
    fun hideCustomKeyboard(activity: Activity) {
        val session = sessions[activity] ?: return
        session.customPanelHeightPx = 0
        session.keyboardShownNotified = false
        syncCardPosition(activity)
    }

    @JvmStatic
    fun syncCardPosition(activity: Activity) {
        val session = sessions[activity] ?: return
        val card = session.cardRef?.get() ?: return
        if (card.height <= 0) {
            return
        }
        val window = activity.window ?: return
        val decor = window.decorView
        val systemIme = resolveSystemImeHeight(decor)
        val keyboardHeight = ImeInsets.effectiveKeyboardHeightPx(systemIme, session.customPanelHeightPx)
        val translationY = if (session.config.cardLiftPolicy == CardLiftPolicy.None) {
            0f
        } else if (keyboardHeight < ImeInsets.KEYBOARD_VISIBLE_THRESHOLD_PX) {
            0f
        } else {
            ImeInsets.computeCardTranslationY(activity, decor, card, keyboardHeight, session.config.keyboardMarginDp)
        }
        val translationChanged = card.translationY != translationY
        if (translationChanged) {
            session.anchor?.applyLift(translationY) ?: run { card.translationY = translationY }
            ImeRegistry.onAnchorLiftApplied?.invoke(card)
            ImeRegistry.onCardBackdropRefresh?.invoke(card)
        }
        if (keyboardHeight >= ImeInsets.KEYBOARD_VISIBLE_THRESHOLD_PX && !session.keyboardShownNotified) {
            session.keyboardShownNotified = true
            ImeRegistry.onKeyboardShown?.invoke(activity, keyboardHeight)
        }
    }

    @JvmStatic
    fun hideSystemIme(activity: Activity) {
        hideKeyboardFromActivity(activity)
    }

    @JvmStatic
    fun hideKeyboard(focusedView: View?) {
        focusedView?.clearFocus()
        val imm = focusedView?.context?.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
        imm?.hideSoftInputFromWindow(focusedView?.windowToken, 0)
    }

    @JvmStatic
    fun prepareFocusForCustomKeyboard(input: EditText?, activity: Activity?) {
        if (input == null) {
            return
        }
        val reveal = Runnable {
            if (!input.isAttachedToWindow) {
                return@Runnable
            }
            hideKeyboard(input)
            input.isFocusableInTouchMode = true
            input.requestFocus()
            input.showSoftInputOnFocus = false
            activity?.let { hideSystemIme(it) }
            activity?.let { syncCardPosition(it) }
        }
        if (input.isLaidOut) {
            input.post(reveal)
        } else {
            input.viewTreeObserver.addOnGlobalLayoutListener(object : ViewTreeObserver.OnGlobalLayoutListener {
                override fun onGlobalLayout() {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
                        input.viewTreeObserver.removeOnGlobalLayoutListener(this)
                    } else {
                        @Suppress("DEPRECATION")
                        input.viewTreeObserver.removeGlobalOnLayoutListener(this)
                    }
                    input.post(reveal)
                }
            })
        }
        longArrayOf(50L, 150L, 350L, 600L).forEach { delay ->
            input.postDelayed(reveal, delay)
        }
    }

    private fun resolveSystemImeHeight(decor: View): Int {
        val insets = ViewCompat.getRootWindowInsets(decor)
        if (insets != null) {
            return insets.getInsets(WindowInsetsCompat.Type.ime()).bottom
        }
        val visible = Rect()
        decor.getWindowVisibleDisplayFrame(visible)
        val decorHeight = if (decor.height > 0) decor.height else visible.bottom
        return ImeInsets.resolveKeyboardHeightPx(decorHeight, visible.bottom, 0)
    }

    private fun removeLayoutListener(activity: Activity, session: ImeSession) {
        val listener = session.layoutListener ?: return
        val observer = activity.window?.decorView?.viewTreeObserver ?: return
        if (observer.isAlive) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
                observer.removeOnGlobalLayoutListener(listener)
            } else {
                @Suppress("DEPRECATION")
                observer.removeGlobalOnLayoutListener(listener)
            }
        }
        session.layoutListener = null
    }

    private fun restoreHostWindow(activity: Activity, session: ImeSession) {
        hideKeyboardFromActivity(activity)
        val window = activity.window
        if (window != null && session.softInputModeSaved) {
            window.setSoftInputMode(session.savedSoftInputMode)
            session.softInputModeSaved = false
        }
        val root = activity.findViewById<View>(android.R.id.content) ?: return
        root.post { applyHostWindowInsetsReset(activity, root) }
        root.postDelayed({ applyHostWindowInsetsReset(activity, root) }, 80)
        root.postDelayed({ applyHostWindowInsetsReset(activity, root) }, 200)
    }

    private fun applyHostWindowInsetsReset(activity: Activity, root: View) {
        activity.window?.let { window ->
            WindowCompat.getInsetsController(window, root)
                .hide(WindowInsetsCompat.Type.ime())
        }
        hideKeyboardFromActivity(activity)
        ViewCompat.requestApplyInsets(root)
        requestLayoutDeep(root)
    }

    private fun hideKeyboardFromActivity(activity: Activity) {
        val imm = activity.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager ?: return
        val decor = activity.window?.decorView
        if (decor?.windowToken != null) {
            imm.hideSoftInputFromWindow(decor.windowToken, 0)
        }
        val root = activity.findViewById<View>(android.R.id.content)
        if (root?.windowToken != null) {
            imm.hideSoftInputFromWindow(root.windowToken, 0)
        }
    }

    private fun requestLayoutDeep(view: View?) {
        if (view == null) {
            return
        }
        view.requestLayout()
        view.invalidate()
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                requestLayoutDeep(view.getChildAt(i))
            }
        }
    }
}
