package com.lasercyber.lws.frostui.dialog

import com.lasercyber.lws.frostui.border.FrostTone
import com.lasercyber.lws.ime.core.ImeConfig
import com.lasercyber.lws.ime.interop.ImeOverlayHost
import com.lasercyber.lws.ime.interop.ImeOverlaySpec

/** Configuration for [FrostPromptDialogController.show]. */
class FrostPromptConfig private constructor(
    val context: android.content.Context,
    val tone: FrostTone,
    val title: CharSequence?,
    val message: CharSequence?,
    val confirmText: CharSequence?,
    val cancelText: CharSequence?,
    val customTitle: FrostPromptSlotContent?,
    val customBody: FrostPromptSlotContent?,
    val customActionBar: FrostPromptSlotContent?,
    val showTitle: Boolean,
    val showActionBar: Boolean,
    val showConfirm: Boolean,
    val showCancel: Boolean,
    val dismissOnScrimClick: Boolean,
    val autoDismissOnConfirm: Boolean,
    val onConfirm: Runnable?,
    val onCancel: Runnable?,
    val onDismiss: Runnable?,
    val widthPx: Int?,
    val widthFraction: Float?,
    val contentInsetPx: Int?,
    val heightPx: Int?,
    val maxHeightPx: Int,
    val expandBodyScroll: Boolean,
    val minHeightPx: Int,
    val replaceExistingIfOccupied: Boolean,
    val bootSelfCheckActive: Boolean,
    val deferFrozenBackdropUntilIme: Boolean,
    val deferFrozenBackdropUntilManualCapture: Boolean,
    val imeOverlay: ImeOverlaySpec?,
) {
    val imeConfig: ImeConfig? get() = imeOverlay?.config
    class Builder(private val context: android.content.Context) {
        private var tone: FrostTone = FrostTone.DARK
        private var title: CharSequence? = null
        private var message: CharSequence? = null
        private var confirmText: CharSequence? = null
        private var cancelText: CharSequence? = null
        private var customTitle: FrostPromptSlotContent? = null
        private var customBody: FrostPromptSlotContent? = null
        private var customActionBar: FrostPromptSlotContent? = null
        private var showTitle: Boolean = true
        private var showActionBar: Boolean = true
        private var showConfirm: Boolean = true
        private var showCancel: Boolean = true
        private var dismissOnScrimClick: Boolean = true
        private var autoDismissOnConfirm: Boolean = true
        private var onConfirm: Runnable? = null
        private var onCancel: Runnable? = null
        private var onDismiss: Runnable? = null
        private var widthPx: Int? = null
        private var widthFraction: Float? = null
        private var contentInsetPx: Int? = null
        private var heightPx: Int? = null
        private var maxHeightPx: Int = 0
        private var expandBodyScroll: Boolean = true
        private var minHeightPx: Int = 0
        private var replaceExistingIfOccupied: Boolean = false
        private var bootSelfCheckActive: Boolean = false
        private var deferFrozenBackdropUntilIme: Boolean = false
        private var deferFrozenBackdropUntilManualCapture: Boolean = false
        private var imeOverlay: ImeOverlaySpec? = null

        fun tone(tone: FrostTone) = apply { this.tone = tone }
        fun title(title: CharSequence?) = apply { this.title = title }
        fun message(message: CharSequence?) = apply { this.message = message }
        fun confirmText(confirmText: CharSequence?) = apply { this.confirmText = confirmText }
        fun cancelText(cancelText: CharSequence?) = apply { this.cancelText = cancelText }
        fun customTitle(customTitle: FrostPromptSlotContent?) = apply { this.customTitle = customTitle }
        fun customBody(customBody: FrostPromptSlotContent?) = apply { this.customBody = customBody }
        fun customActionBar(customActionBar: FrostPromptSlotContent?) =
            apply { this.customActionBar = customActionBar }
        fun showTitle(showTitle: Boolean) = apply { this.showTitle = showTitle }
        fun showActionBar(showActionBar: Boolean) = apply { this.showActionBar = showActionBar }
        fun showConfirm(showConfirm: Boolean) = apply { this.showConfirm = showConfirm }
        fun showCancel(showCancel: Boolean) = apply { this.showCancel = showCancel }
        fun dismissOnScrimClick(dismissOnScrimClick: Boolean) =
            apply { this.dismissOnScrimClick = dismissOnScrimClick }
        fun autoDismissOnConfirm(autoDismissOnConfirm: Boolean) =
            apply { this.autoDismissOnConfirm = autoDismissOnConfirm }
        fun onConfirm(onConfirm: Runnable?) = apply { this.onConfirm = onConfirm }
        fun onCancel(onCancel: Runnable?) = apply { this.onCancel = onCancel }
        fun onDismiss(onDismiss: Runnable?) = apply { this.onDismiss = onDismiss }
        fun widthPx(widthPx: Int) = apply {
            this.widthPx = widthPx
            this.widthFraction = null
        }
        fun widthFraction(widthFraction: Float) = apply {
            this.widthFraction = widthFraction
            this.widthPx = null
        }
        fun contentInsetPx(contentInsetPx: Int) = apply {
            this.contentInsetPx = contentInsetPx
            this.widthPx = null
            this.widthFraction = null
        }
        fun heightPx(heightPx: Int) = apply { this.heightPx = heightPx }
        fun maxHeightPx(maxHeightPx: Int) = apply { this.maxHeightPx = maxHeightPx }
        fun expandBodyScroll(expandBodyScroll: Boolean) = apply { this.expandBodyScroll = expandBodyScroll }
        fun minHeightPx(minHeightPx: Int) = apply { this.minHeightPx = minHeightPx }
        fun replaceExistingIfOccupied(replaceExistingIfOccupied: Boolean) =
            apply { this.replaceExistingIfOccupied = replaceExistingIfOccupied }
        fun bootSelfCheckActive(bootSelfCheckActive: Boolean) =
            apply { this.bootSelfCheckActive = bootSelfCheckActive }
        fun deferFrozenBackdropUntilIme(deferFrozenBackdropUntilIme: Boolean) =
            apply { this.deferFrozenBackdropUntilIme = deferFrozenBackdropUntilIme }
        fun deferFrozenBackdropUntilManualCapture(deferUntilManualCapture: Boolean) =
            apply { this.deferFrozenBackdropUntilManualCapture = deferUntilManualCapture }

        fun imeOverlay(imeOverlay: ImeOverlaySpec?) = apply { this.imeOverlay = imeOverlay }

        fun build(): FrostPromptConfig = FrostPromptConfig(
            context = context,
            tone = tone,
            title = title,
            message = message,
            confirmText = confirmText,
            cancelText = cancelText,
            customTitle = customTitle,
            customBody = customBody,
            customActionBar = customActionBar,
            showTitle = showTitle,
            showActionBar = showActionBar,
            showConfirm = showConfirm,
            showCancel = showCancel,
            dismissOnScrimClick = dismissOnScrimClick,
            autoDismissOnConfirm = autoDismissOnConfirm,
            onConfirm = onConfirm,
            onCancel = onCancel,
            onDismiss = onDismiss,
            widthPx = widthPx,
            widthFraction = widthFraction,
            contentInsetPx = contentInsetPx,
            heightPx = heightPx,
            maxHeightPx = maxHeightPx,
            expandBodyScroll = expandBodyScroll,
            minHeightPx = minHeightPx,
            replaceExistingIfOccupied = replaceExistingIfOccupied,
            bootSelfCheckActive = bootSelfCheckActive,
            deferFrozenBackdropUntilIme = deferFrozenBackdropUntilIme,
            deferFrozenBackdropUntilManualCapture = deferFrozenBackdropUntilManualCapture,
            imeOverlay = imeOverlay,
        )
    }

    companion object {
        @JvmStatic
        fun builder(context: android.content.Context): Builder = Builder(context)
    }
}
