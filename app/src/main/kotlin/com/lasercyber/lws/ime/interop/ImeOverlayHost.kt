package com.lasercyber.lws.ime.interop

import android.app.Activity
import android.view.View
import android.widget.EditText
import com.lasercyber.lws.ime.core.ImeController
import java.util.WeakHashMap

/** View interop for frost overlay IME attach, keyboard reveal, and teardown. */
object ImeOverlayHost {
    private data class OverlayState(
        val spec: ImeOverlaySpec,
        var editText: EditText? = null,
        var focusListenerInstalled: Boolean = false,
        /** Set by [scheduleKeyboardAfterDialogShown]; cleared when enter animation finishes. */
        var awaitingDialogEnter: Boolean = false,
    )

    private val states = WeakHashMap<View, OverlayState>()

    @JvmStatic
    fun hasImeSession(overlay: View): Boolean = states.containsKey(overlay)

    @JvmStatic
    fun attachOverlay(
        activity: Activity,
        overlay: View,
        cardView: View,
        spec: ImeOverlaySpec,
    ) {
        states[overlay] = OverlayState(spec)
        ImeController.attach(activity, overlay, overlay, cardView, spec.config)
        ImeKeyboardOverlay.restoreDialogTouchLayerOrder(overlay)
    }

    /**
     * Waits for the input dialog enter animation to finish before focusing and showing the keyboard.
     */
    @JvmStatic
    fun scheduleKeyboardAfterDialogShown(
        activity: Activity,
        overlay: View,
        editText: EditText,
    ) {
        val state = states[overlay] ?: return
        state.editText = editText
        state.awaitingDialogEnter = true
        editText.showSoftInputOnFocus = false
        ensureEditTextFocusListener(activity, overlay, editText, state)
    }

    /** Called by [com.lasercyber.lws.frostui.dialog.FrostOverlayHost] when the dialog fade-in completes. */
    @JvmStatic
    fun onInputDialogEnterAnimationEnd(activity: Activity, overlay: View) {
        val state = states[overlay] ?: return
        if (!state.awaitingDialogEnter) {
            return
        }
        state.awaitingDialogEnter = false
        val editText = state.editText ?: return
        requestFocusAndShowKeyboard(activity, overlay, editText, state)
    }

    @JvmStatic
    fun showKeyboardFor(
        activity: Activity,
        overlay: View,
        editText: EditText,
    ) {
        val state = states[overlay] ?: return
        state.editText = editText
        editText.showSoftInputOnFocus = false
        ensureEditTextFocusListener(activity, overlay, editText, state)
        revealKeyboard(activity, overlay, editText, state)
    }

    /** Hides the custom keyboard while keeping the dialog IME session attached. */
    @JvmStatic
    fun hideKeyboardFor(activity: Activity, overlay: View) {
        if (!ImeKeyboardOverlay.isShowing(overlay)) {
            return
        }
        val editText = states[overlay]?.editText
        editText?.clearFocus()
        ImeKeyboardOverlay.hide(overlay)
        ImeController.hideKeyboard(editText)
    }

    /**
     * Called after the input dialog fade-out completes; clears focus then animates the keyboard away.
     */
    @JvmStatic
    fun hideKeyboardAfterDialogExit(
        activity: Activity,
        overlay: View,
        onComplete: Runnable,
    ) {
        states[overlay]?.awaitingDialogEnter = false
        val editText = states[overlay]?.editText
        editText?.clearFocus()
        ImeController.hideKeyboard(editText)
        if (!ImeKeyboardOverlay.isShowing(overlay)) {
            onComplete.run()
            return
        }
        ImeKeyboardOverlay.hide(overlay, animated = true, onHidden = onComplete)
    }

    @JvmStatic
    fun detachOverlay(activity: Activity?, overlay: View?) {
        if (activity == null || overlay == null) {
            return
        }
        val state = states.remove(overlay)
        val editText = state?.editText
        if (state?.focusListenerInstalled == true) {
            editText?.onFocusChangeListener = null
        }
        ImeKeyboardOverlay.hideImmediate(overlay)
        ImeController.hideKeyboard(editText)
        ImeController.detach(activity, overlay)
    }

    private fun requestFocusAndShowKeyboard(
        activity: Activity,
        overlay: View,
        editText: EditText,
        state: OverlayState,
    ) {
        editText.requestFocus()
        editText.post {
            if (!editText.isFocused) {
                editText.requestFocus()
            }
            editText.post {
                revealKeyboard(activity, overlay, editText, state)
            }
        }
    }

    private fun revealKeyboard(
        activity: Activity,
        overlay: View,
        editText: EditText,
        state: OverlayState,
    ) {
        if (ImeKeyboardOverlay.isShowingForEditText(overlay, editText)) {
            return
        }
        ImeKeyboardOverlay.showForEditText(
            activity = activity,
            hostOverlay = overlay,
            editText = editText,
            fieldType = state.spec.fieldType,
            numericPolicyOverride = state.spec.numericPolicyOverride,
            enterKey = state.spec.config.enterKey,
            onEditorAction = state.spec::onEditorAction,
        )
        ImeController.prepareFocusForCustomKeyboard(editText, activity)
    }

    private fun ensureEditTextFocusListener(
        activity: Activity,
        overlay: View,
        editText: EditText,
        state: OverlayState,
    ) {
        if (state.focusListenerInstalled) {
            return
        }
        state.focusListenerInstalled = true
        editText.setOnFocusChangeListener { focused, hasFocus ->
            if (!hasFocus || state.awaitingDialogEnter) {
                return@setOnFocusChangeListener
            }
            val focusedEdit = focused as? EditText ?: return@setOnFocusChangeListener
            if (!ImeKeyboardOverlay.isShowingForEditText(overlay, focusedEdit)) {
                showKeyboardFor(activity, overlay, focusedEdit)
            }
        }
    }
}
