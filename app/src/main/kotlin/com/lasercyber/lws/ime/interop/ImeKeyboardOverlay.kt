package com.lasercyber.lws.ime.interop

import android.app.Activity
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.ViewParent
import android.view.animation.AccelerateInterpolator
import android.view.animation.DecelerateInterpolator
import android.widget.EditText
import android.widget.FrameLayout
import java.lang.ref.WeakReference
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import com.lasercyber.lws.frostui.border.FrostDimens
import com.lasercyber.lws.frostui.dialog.FrostOverlayHost
import com.lasercyber.lws.frostui.dialog.FrostResourceIds
import com.lasercyber.lws.ime.ImeAction
import com.lasercyber.lws.ime.core.ImeController
import com.lasercyber.lws.ime.compose.ImeKeyboardPanel
import com.lasercyber.lws.ime.engine.EditTextImeInputConnection
import com.lasercyber.lws.ime.engine.ImeEnterKeyConfig
import com.lasercyber.lws.ime.engine.ImeInputConnection
import com.lasercyber.lws.ime.keyboard.KeyboardController
import com.lasercyber.lws.ui.R
import java.util.WeakHashMap

/** Attaches the custom IME keyboard panel above the dialog overlay scrim. */
object ImeKeyboardOverlay {
    private const val TAG = "FrostIme"
    private const val IME_SLOT_ELEVATION_DP = 48f
    private const val DIALOG_CARD_ELEVATION_DP = 8f

    private data class OverlayEntry(
        val hostView: ViewGroup,
        val backdropHost: ImeKeyboardBackdropHost,
        val touchHost: ViewGroup,
        val panelHeightPx: Int,
        val activity: Activity,
        val dialogCard: View?,
        val scrim: View?,
        val savedDialogCardElevation: Float,
        val scrimOutsideTapListener: View.OnTouchListener?,
        val editTextRef: WeakReference<EditText>,
    )

    private val overlays = WeakHashMap<View, OverlayEntry>()
    /** Entries animating out; kept until slide/fade completes. */
    private val hidingEntries = WeakHashMap<View, OverlayEntry>()

    private fun panelViews(entry: OverlayEntry): List<View> =
        listOf(entry.backdropHost, entry.touchHost)

    /**
     * Keeps the bottom IME slot above the dialog card for both draw order and touch dispatch.
     * Call after card lift / backdrop refresh so elevated dialog chrome cannot steal key taps.
     */
    @JvmStatic
    fun maintainLayerOrderForDialogCard(dialogCard: View) {
        val overlayRoot = findOverlayRoot(dialogCard) ?: return
        val slotId = FrostResourceIds.viewId(dialogCard.context, "frost_dialog_ime_slot")
        val imeSlot = overlayRoot.findViewById<View>(slotId) ?: return
        overlayRoot.bringChildToFront(imeSlot)
        imeSlot.elevation = IME_SLOT_ELEVATION_DP
        imeSlot.translationZ = IME_SLOT_ELEVATION_DP
        dialogCard.elevation = 0f
        dialogCard.translationZ = 0f
    }

    @JvmStatic
    fun showForEditText(
        activity: Activity,
        hostOverlay: View,
        editText: EditText,
        fieldType: com.lasercyber.lws.ime.field.ImeFieldType,
        numericPolicyOverride: com.lasercyber.lws.ime.field.policy.NumericPolicyConfig? = null,
        enterKey: ImeEnterKeyConfig = ImeEnterKeyConfig.done(),
        onEditorAction: (ImeAction) -> Boolean,
    ) {
        overlays[hostOverlay]?.let { entry ->
            if (entry.editTextRef.get() === editText) {
                return
            }
            hideImmediate(hostOverlay)
        }
        val connection = EditTextImeInputConnection(editText, onEditorAction)
        show(
            activity = activity,
            hostOverlay = hostOverlay,
            connection = connection,
            fieldType = fieldType,
            numericPolicyOverride = numericPolicyOverride,
            enterKey = enterKey,
            onEditorAction = onEditorAction,
            targetEditText = editText,
        )
        ImeController.prepareFocusForCustomKeyboard(editText, activity)
    }

    @JvmStatic
    @Deprecated("Use showForEditText with fieldType")
    fun showForEditText(
        activity: Activity,
        hostOverlay: View,
        editText: EditText,
        numericInput: Boolean,
        enterKey: ImeEnterKeyConfig = ImeEnterKeyConfig.done(),
        onEditorAction: (ImeAction) -> Boolean,
    ) {
        showForEditText(
            activity = activity,
            hostOverlay = hostOverlay,
            editText = editText,
            fieldType = if (numericInput) {
                com.lasercyber.lws.ime.field.ImeFieldType.Number
            } else {
                com.lasercyber.lws.ime.field.ImeFieldType.Text
            },
            enterKey = enterKey,
            onEditorAction = onEditorAction,
        )
    }

    @JvmStatic
    fun isShowing(hostOverlay: View): Boolean =
        overlays.containsKey(hostOverlay) || hidingEntries.containsKey(hostOverlay)

    /** True while the keyboard panel is shown or entering; false during slide-out. */
    @JvmStatic
    fun isActive(hostOverlay: View): Boolean = overlays.containsKey(hostOverlay)

    @JvmStatic
    fun isShowingForEditText(hostOverlay: View, editText: EditText): Boolean {
        val entry = overlays[hostOverlay] ?: return false
        return entry.editTextRef.get() === editText
    }

    @JvmStatic
    fun show(
        activity: Activity,
        hostOverlay: View,
        connection: ImeInputConnection,
        fieldType: com.lasercyber.lws.ime.field.ImeFieldType,
        numericPolicyOverride: com.lasercyber.lws.ime.field.policy.NumericPolicyConfig? = null,
        enterKey: ImeEnterKeyConfig = ImeEnterKeyConfig.done(),
        onEditorAction: (ImeAction) -> Boolean = { false },
        targetEditText: EditText? = null,
    ) {
        val overlayRoot = hostOverlay as? ViewGroup ?: return
        hideImmediate(hostOverlay)
        val imeHost = resolveImeHost(overlayRoot) ?: run {
            Log.e(TAG, "frost_dialog_ime_slot not found in overlay; aborting keyboard show")
            return
        }
        val cardId = FrostResourceIds.viewId(overlayRoot.context, "frost_dialog_content")
        val scrimId = FrostResourceIds.viewId(overlayRoot.context, "frost_dialog_scrim")
        val dialogCard = overlayRoot.findViewById<View>(cardId)
        val scrim = overlayRoot.findViewById<View>(scrimId)
        val savedDialogCardElevation = dialogCard?.elevation ?: DIALOG_CARD_ELEVATION_DP
        dialogCard?.let { card ->
            card.elevation = 0f
            card.translationZ = 0f
        }

        val panelHeightPx = activity.resources.getDimensionPixelSize(R.dimen.ime_keyboard_height)
        val scrimOutsideTapListener = createScrimOutsideTapListener(activity, hostOverlay)
        scrim?.setOnTouchListener(scrimOutsideTapListener)
        dialogCard?.let { card ->
            card.isClickable = true
            card.setOnClickListener {
                ImeOverlayHost.hideKeyboardFor(activity, hostOverlay)
            }
        }

        val backdropHost = ImeKeyboardBackdropHost(activity).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                panelHeightPx,
                Gravity.BOTTOM,
            )
        }
        imeHost.addView(backdropHost)

        imeHost.isClickable = false
        imeHost.isFocusable = false
        imeHost.setOnClickListener(null)
        imeHost.elevation = IME_SLOT_ELEVATION_DP
        imeHost.translationZ = IME_SLOT_ELEVATION_DP
        imeHost.clipChildren = false
        imeHost.clipToPadding = false
        overlayRoot.clipChildren = false
        overlayRoot.clipToPadding = false

        val controller = KeyboardController.forFieldType(
            fieldType = fieldType,
            connection = connection,
            enterKey = enterKey,
            onEditorAction = onEditorAction,
            numericPolicyOverride = numericPolicyOverride,
        )
        val composeView = ComposeView(activity).apply {
            isClickable = true
            isFocusable = true
            isFocusableInTouchMode = true
            setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            setContent {
                ImeKeyboardPanel(
                    controller = controller,
                    modifier = Modifier.fillMaxSize(),
                )
            }
        }
        val touchHost = ImeKeyboardTouchHost(activity).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                panelHeightPx,
                Gravity.BOTTOM,
            )
            addView(
                composeView,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ),
            )
        }
        imeHost.addView(touchHost)
        overlayRoot.bringChildToFront(imeHost)
        dialogCard?.let { maintainLayerOrderForDialogCard(it) }
        overlays[hostOverlay] = OverlayEntry(
            hostView = imeHost,
            backdropHost = backdropHost,
            touchHost = touchHost,
            panelHeightPx = panelHeightPx,
            activity = activity,
            dialogCard = dialogCard,
            scrim = scrim,
            savedDialogCardElevation = savedDialogCardElevation,
            scrimOutsideTapListener = scrimOutsideTapListener,
            editTextRef = WeakReference(targetEditText),
        )
        ImeController.hideSystemIme(activity)
        ImeController.showCustomKeyboard(activity, panelHeightPx)
        animatePanelIn(backdropHost, touchHost, panelHeightPx, activity) {
            backdropHost.post {
                if (backdropHost.height >= (panelHeightPx * 0.6f).toInt()) {
                    FrostOverlayHost.captureImeBackdropOnce(activity)
                }
            }
        }
        touchHost.post {
            composeView.requestFocus()
            dialogCard?.let { maintainLayerOrderForDialogCard(it) }
        }
    }

    /** Slides the keyboard panel down and fades out, matching frost dialog dismiss timing. */
    @JvmStatic
    @JvmOverloads
    fun hide(
        hostOverlay: View?,
        animated: Boolean = true,
        onHidden: Runnable? = null,
    ) {
        if (hostOverlay == null) {
            onHidden?.run()
            return
        }
        if (hidingEntries.containsKey(hostOverlay)) {
            onHidden?.run()
            return
        }
        val entry = overlays.remove(hostOverlay) ?: run {
            onHidden?.run()
            return
        }
        if (!animated) {
            hideImmediate(hostOverlay, entry)
            onHidden?.run()
            return
        }
        hidingEntries[hostOverlay] = entry
        ImeController.hideCustomKeyboard(entry.activity)
        animatePanelOut(entry) {
            if (hidingEntries.remove(hostOverlay) == null) {
                onHidden?.run()
                return@animatePanelOut
            }
            removeEntryViews(entry)
            finalizeHide(entry)
            onHidden?.run()
        }
    }

    /** Removes the keyboard panel immediately without animation. */
    @JvmStatic
    fun hideImmediate(hostOverlay: View?) {
        if (hostOverlay == null) {
            return
        }
        val entry = overlays.remove(hostOverlay)
            ?: hidingEntries.remove(hostOverlay)
            ?: return
        cancelPanelAnimation(entry)
        hideImmediate(hostOverlay, entry)
    }

    private fun hideImmediate(hostOverlay: View, entry: OverlayEntry) {
        hidingEntries.remove(hostOverlay)
        ImeController.hideCustomKeyboard(entry.activity)
        removeEntryViews(entry)
        finalizeHide(entry)
    }

    private fun removeEntryViews(entry: OverlayEntry) {
        entry.hostView.removeView(entry.touchHost)
        entry.hostView.removeView(entry.backdropHost)
    }

    /** Restores dialog card above the idle IME slot so lower form rows stay tappable. */
    @JvmStatic
    fun restoreDialogTouchLayerOrder(hostOverlay: View?) {
        val overlayRoot = hostOverlay as? ViewGroup ?: return
        val cardId = FrostResourceIds.viewId(overlayRoot.context, "frost_dialog_content")
        val dialogCard = overlayRoot.findViewById<View>(cardId) ?: return
        overlayRoot.bringChildToFront(dialogCard)
    }

    private fun finalizeHide(entry: OverlayEntry) {
        entry.hostView.isClickable = false
        entry.hostView.setOnClickListener(null)
        entry.hostView.elevation = 0f
        entry.hostView.translationZ = 0f
        entry.dialogCard?.let { card ->
            card.elevation = entry.savedDialogCardElevation
            card.translationZ = entry.savedDialogCardElevation
            card.setOnClickListener(null)
        }
        entry.scrim?.setOnTouchListener(null)
        val overlayRoot = entry.hostView.parent as? View
        restoreDialogTouchLayerOrder(overlayRoot)
        FrostOverlayHost.notifyKeyboardHidden(entry.activity)
    }

    private fun cancelPanelAnimation(entry: OverlayEntry) {
        for (view in panelViews(entry)) {
            view.animate().cancel()
        }
    }

    private fun animatePanelIn(
        backdropHost: View,
        touchHost: View,
        panelHeightPx: Int,
        activity: Activity,
        onEnd: () -> Unit = {},
    ) {
        val duration = FrostDimens.fadeInDurationMs(activity).toLong()
        var finished = false
        val finishOnce = Runnable {
            if (finished) {
                return@Runnable
            }
            finished = true
            onEnd()
        }
        var pending = 2
        for (view in listOf(backdropHost, touchHost)) {
            view.animate().cancel()
            view.alpha = 0f
            view.translationY = panelHeightPx.toFloat()
            view.animate()
                .alpha(1f)
                .translationY(0f)
                .setDuration(duration)
                .setInterpolator(DecelerateInterpolator())
                .withEndAction {
                    pending--
                    if (pending <= 0) {
                        finishOnce.run()
                    }
                }
                .start()
        }
        backdropHost.postDelayed(finishOnce, duration + 32L)
    }

    private fun animatePanelOut(entry: OverlayEntry, onEnd: () -> Unit) {
        val duration = FrostDimens.fadeOutDurationMs(entry.activity).toLong()
        val panelHeightPx = entry.panelHeightPx
        var finished = false
        val finishOnce = Runnable {
            if (finished) {
                return@Runnable
            }
            finished = true
            onEnd()
        }
        var pending = panelViews(entry).size
        for (view in panelViews(entry)) {
            view.animate().cancel()
            view.animate()
                .alpha(0f)
                .translationY(panelHeightPx.toFloat())
                .setDuration(duration)
                .setInterpolator(AccelerateInterpolator())
                .withEndAction {
                    pending--
                    if (pending <= 0) {
                        finishOnce.run()
                    }
                }
                .start()
        }
        entry.touchHost.postDelayed(finishOnce, duration + 32L)
    }

    @JvmStatic
    fun panelHeightPx(activity: Activity): Int =
        activity.resources.getDimensionPixelSize(R.dimen.ime_keyboard_height)

    private fun resolveImeHost(overlayRoot: ViewGroup): ViewGroup? {
        val slotId = FrostResourceIds.viewId(overlayRoot.context, "frost_dialog_ime_slot")
        return overlayRoot.findViewById(slotId)
    }

    private fun createScrimOutsideTapListener(
        activity: Activity,
        hostOverlay: View,
    ): View.OnTouchListener = View.OnTouchListener { _, event ->
        if (event.actionMasked != MotionEvent.ACTION_UP || !isShowing(hostOverlay)) {
            return@OnTouchListener false
        }
        val dismissOnScrimTag =
            FrostResourceIds.viewId(hostOverlay.context, "frost_dialog_dismiss_on_scrim_click")
        if (hostOverlay.getTag(dismissOnScrimTag) == true) {
            // Scrim dismiss removes the whole overlay; keep the keyboard attached until fade/remove.
            return@OnTouchListener false
        }
        ImeOverlayHost.hideKeyboardFor(activity, hostOverlay)
        false
    }

    private fun findOverlayRoot(view: View): ViewGroup? {
        val overlayRootId = FrostResourceIds.viewId(view.context, "frost_dialog_root")
        var current: ViewParent? = view.parent
        while (current is View) {
            if (current.id == overlayRootId) {
                return current as ViewGroup
            }
            current = current.parent
        }
        return null
    }
}
