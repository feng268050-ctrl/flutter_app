package com.lasercyber.lws.frostui.dialog

import android.app.Activity
import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView
import com.lasercyber.lws.frostui.border.FrostTone
import com.lasercyber.lws.frostui.button.interop.FrostButtonView
import com.lasercyber.lws.ime.interop.ImeOverlayHost
import kotlin.math.roundToInt

/** Java-visible handle returned from [FrostPromptDialogController.show]. */
interface FrostPromptHandle {
    fun dismiss()
    fun dismissImmediate()
    fun isShowing(): Boolean
    fun getRootView(): View?
    fun getTitleSlot(): View?
    fun getBodySlot(): View?
    fun getActionSlot(): View?
    fun findViewById(id: Int): View?
}

object FrostPromptDialogController {

    @JvmStatic
    fun show(config: FrostPromptConfig): FrostPromptHandle? {
        val activity = FrostOverlayHost.findActivity(config.context)
        if (activity == null || activity.isFinishing || activity.isDestroyed) {
            return null
        }

        val overlay = LayoutInflater.from(activity)
            .inflate(config.tone.overlayLayoutId(activity), null, false)
        if (config.tone == FrostTone.LIGHT) {
            FrostOverlayHostRegistry.panelShellInstaller?.invoke(overlay, activity)
        }
        applyChrome(overlay, config.showTitle, config.showActionBar, activity)
        bindTitleSlot(overlay, config, activity)

        val onDismiss = Runnable {
            if (config.imeOverlay != null) {
                ImeOverlayHost.detachOverlay(activity, overlay)
            }
            config.onDismiss?.run()
        }
        val handle = DialogHandleImpl(activity, overlay, onDismiss)
        val onDismissTag = FrostResourceIds.viewId(activity, "frost_dialog_on_dismiss")
        overlay.setTag(onDismissTag, onDismiss)
        val dismissUi = Runnable { handle.dismiss() }
        bindActionSlot(overlay, config, activity, dismissUi)

        val cancelAction = Runnable {
            dismissUi.run()
            config.onCancel?.run()
        }
        val scrimDismiss = if (config.dismissOnScrimClick) cancelAction else null

        if (config.replaceExistingIfOccupied && !config.bootSelfCheckActive) {
            if (!com.lasercyber.lws.ui.component.dialog.WarnDialogUtil.isDialogShowing()) {
                if (!com.lasercyber.lws.ui.component.dialog.WarnDialogUtil.blocksExternalOverlayDismiss()) {
                    com.lasercyber.lws.ui.component.dialog.WarnDialogUtil.beginExternalOverlayReplace()
                    FrostOverlayHost.dismissAllOnActivity(activity, overlay)
                }
            }
        }

        val cardWidth = resolveCardWidth(config) ?: return null
        val deferUntilIme = config.deferFrozenBackdropUntilIme || config.imeOverlay != null
        if (FrostOverlayHost.attachOverlay(
                config.context,
                overlay,
                config.dismissOnScrimClick,
                scrimDismiss,
                cardWidth,
                config.tone,
                deferUntilIme,
                config.deferFrozenBackdropUntilManualCapture,
                config.imeOverlay != null,
            ) == null
        ) {
            return null
        }
        bindBodySlot(overlay, config, activity)
        config.imeOverlay?.let { spec ->
            val card = overlay.findViewById<View>(
                FrostResourceIds.viewId(activity, "frost_dialog_content"),
            )
            if (card != null) {
                ImeOverlayHost.attachOverlay(activity, overlay, card, spec)
            }
        }
        return handle
    }

    private fun resolveCardWidth(config: FrostPromptConfig): FrostOverlayHost.CardWidth? {
        var cardWidth = when {
            config.contentInsetPx != null && config.contentInsetPx > 0 ->
                FrostOverlayHost.CardWidth.inset(config.contentInsetPx)
            config.widthPx != null ->
                FrostOverlayHost.CardWidth.px(
                    config.widthPx,
                    config.heightPx,
                    config.expandBodyScroll,
                    config.minHeightPx,
                )
            config.widthFraction != null ->
                FrostOverlayHost.CardWidth.fraction(config.widthFraction, config.heightPx)
            else ->
                FrostOverlayHost.CardWidth.defaults(config.expandBodyScroll)
        }
        if (config.maxHeightPx > 0) {
            cardWidth = cardWidth.withMaxHeight(config.maxHeightPx, config.expandBodyScroll)
        }
        return cardWidth
    }

    private fun applyChrome(overlay: View, showTitle: Boolean, showActionBar: Boolean, context: Context) {
        overlay.findViewById<View>(
            FrostResourceIds.viewId(context, "frost_dialog_title_section"),
        )?.visibility = if (showTitle) View.VISIBLE else View.GONE
        overlay.findViewById<View>(
            FrostResourceIds.viewId(context, "frost_dialog_action_section"),
        )?.visibility = if (showActionBar) View.VISIBLE else View.GONE
    }

    private fun bindTitleSlot(overlay: View, config: FrostPromptConfig, context: Context) {
        val customTitle = config.customTitle
        if (customTitle != null && customTitle.hasCustomContent()) {
            customTitle.install(context, overlay, FrostResourceIds.viewId(context, "frost_dialog_title_slot"))
            return
        }
        val titleView = overlay.findViewById<TextView>(FrostResourceIds.viewId(context, "tv_title"))
        if (config.title != null && titleView != null) {
            titleView.text = config.title
        }
    }

    private fun bindBodySlot(overlay: View, config: FrostPromptConfig, context: Context) {
        val customBody = config.customBody
        if (customBody != null && customBody.hasCustomContent()) {
            customBody.install(context, overlay, FrostResourceIds.viewId(context, "frost_dialog_body_slot"))
            return
        }
        val messageView = overlay.findViewById<TextView>(
            FrostResourceIds.viewId(context, "tv_frost_dialog_message"),
        )
        if (config.message != null && messageView != null) {
            messageView.text = config.message
        }
    }

    private fun bindActionSlot(
        overlay: View,
        config: FrostPromptConfig,
        context: Context,
        dismissUi: Runnable,
    ) {
        val customActionBar = config.customActionBar
        if (customActionBar != null && customActionBar.hasCustomContent()) {
            customActionBar.install(
                context,
                overlay,
                FrostResourceIds.viewId(context, "frost_dialog_action_slot"),
            )
            return
        }
        if (!config.showActionBar) {
            return
        }
        val confirmId = FrostResourceIds.viewId(context, "tv_frost_dialog_confirm")
        val cancelId = FrostResourceIds.viewId(context, "tv_frost_dialog_cancel")
        val confirmView = overlay.findViewById<FrostButtonView>(confirmId)
        val cancelView = overlay.findViewById<FrostButtonView>(cancelId)
        if (config.confirmText != null && confirmView != null) {
            confirmView.setText(config.confirmText)
        }
        if (config.cancelText != null && cancelView != null) {
            cancelView.setText(config.cancelText)
        }
        if (confirmView != null) {
            confirmView.isClickable = true
            confirmView.isFocusable = true
            confirmView.visibility = if (config.showConfirm) View.VISIBLE else View.GONE
            confirmView.setOnClickListener {
                config.onConfirm?.run()
                if (config.autoDismissOnConfirm) {
                    dismissUi.run()
                }
            }
        }
        applyDefaultActionButtonLayout(context, cancelView, confirmView, config.showConfirm, config.showCancel)
        val actionDefault = overlay.findViewById<ViewGroup>(
            FrostResourceIds.viewId(context, "frost_dialog_action_default"),
        )
        if (actionDefault != null && confirmView != null && cancelView != null) {
            val spacer = actionDefault.getChildAt(1)
            spacer?.visibility =
                if (config.showConfirm && config.showCancel) View.VISIBLE else View.GONE
            cancelView.visibility = if (config.showCancel) View.VISIBLE else View.GONE
        }
        val cancelAction = Runnable {
            dismissUi.run()
            config.onCancel?.run()
        }
        if (cancelView != null && config.showCancel) {
            cancelView.isClickable = true
            cancelView.isFocusable = true
            cancelView.setOnClickListener { cancelAction.run() }
        }
    }

    private fun applyDefaultActionButtonLayout(
        context: Context,
        cancelView: FrostButtonView?,
        confirmView: FrostButtonView?,
        showConfirm: Boolean,
        showCancel: Boolean,
    ) {
        if (cancelView == null && confirmView == null) {
            return
        }
        val height = context.resources.getDimensionPixelSize(
            FrostResourceIds.dimenId(context, "frost_action_button_height"),
        )
        val padH = context.resources.getDimensionPixelSize(
            FrostResourceIds.dimenId(context, "frost_action_button_padding_horizontal"),
        )
        val minWidth = resolveActionButtonMinWidth(
            context,
            cancelView,
            confirmView,
            showConfirm,
            showCancel,
            padH,
        )
        if (cancelView != null && showCancel) {
            applyActionButtonSizing(cancelView, height, padH, minWidth)
        }
        if (confirmView != null && showConfirm) {
            applyActionButtonSizing(confirmView, height, padH, minWidth)
        }
    }

    private fun resolveActionButtonMinWidth(
        context: Context,
        cancelView: FrostButtonView?,
        confirmView: FrostButtonView?,
        showConfirm: Boolean,
        showCancel: Boolean,
        horizontalPaddingPx: Int,
    ): Int {
        var minWidth = 0
        if (showConfirm && confirmView != null) {
            minWidth = maxOf(
                minWidth,
                measureActionButtonContentWidth(context, confirmView.getText(), horizontalPaddingPx),
            )
        }
        if (showCancel && cancelView != null) {
            minWidth = maxOf(
                minWidth,
                measureActionButtonContentWidth(context, cancelView.getText(), horizontalPaddingPx),
            )
        }
        return minWidth
    }

    private fun measureActionButtonContentWidth(
        context: Context,
        label: CharSequence,
        horizontalPaddingPx: Int,
    ): Int {
        val paint = android.graphics.Paint().apply {
            textSize = context.resources.getDimension(
                FrostResourceIds.dimenId(context, "frost_action_button_text_size"),
            )
        }
        return (paint.measureText(label, 0, label.length) + horizontalPaddingPx * 2L + 0.5f).roundToInt()
    }

    private fun applyActionButtonSizing(
        button: FrostButtonView,
        heightPx: Int,
        horizontalPaddingPx: Int,
        minWidthPx: Int,
    ) {
        val existing = button.layoutParams
        if (existing != null && existing.width > 0) {
            existing.height = heightPx
            button.layoutParams = existing
            button.setPadding(horizontalPaddingPx, 0, horizontalPaddingPx, 0)
            return
        }
        button.applyExternalMinimumWidth(minWidthPx)
        button.setPadding(horizontalPaddingPx, 0, horizontalPaddingPx, 0)
        button.layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            heightPx,
        )
    }

    private class DialogHandleImpl(
        private val activity: Activity,
        private val overlay: View,
        private val onDismiss: Runnable?,
    ) : FrostPromptHandle {
        override fun dismiss() {
            FrostOverlayHost.dismiss(activity, overlay, onDismiss)
        }

        override fun dismissImmediate() {
            FrostOverlayHost.dismissImmediate(activity, overlay, onDismiss)
        }

        override fun isShowing(): Boolean = overlay.parent is ViewGroup

        override fun getRootView(): View = overlay

        override fun getTitleSlot(): View? =
            overlay.findViewById(FrostResourceIds.viewId(overlay.context, "frost_dialog_title_slot"))

        override fun getBodySlot(): View? =
            overlay.findViewById(FrostResourceIds.viewId(overlay.context, "frost_dialog_body_slot"))

        override fun getActionSlot(): View? =
            overlay.findViewById(FrostResourceIds.viewId(overlay.context, "frost_dialog_action_slot"))

        override fun findViewById(id: Int): View? = overlay.findViewById(id)
    }
}
