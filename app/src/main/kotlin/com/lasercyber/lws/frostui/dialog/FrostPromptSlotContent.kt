package com.lasercyber.lws.frostui.dialog

import android.content.Context
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import java.util.function.Consumer

/** Custom slot content for frost prompt dialogs. */
class FrostPromptSlotContent private constructor(
    private val view: View?,
    private val layoutRes: Int,
    private val binder: Consumer<View>?,
) {
    fun hasCustomContent(): Boolean = view != null || layoutRes != 0

    fun install(context: Context, overlay: View, slotId: Int): View? {
        if (!hasCustomContent()) {
            return null
        }
        val slot = overlay.findViewById<FrameLayout>(slotId) ?: return null
        slot.removeAllViews()
        val content: View = view ?: LayoutInflater.from(context).inflate(layoutRes, slot, false)
        val layoutParams = content.layoutParams
        if (layoutParams is FrameLayout.LayoutParams) {
            layoutParams.width = ViewGroup.LayoutParams.MATCH_PARENT
            layoutParams.gravity = Gravity.CENTER_HORIZONTAL
            content.layoutParams = layoutParams
        } else {
            content.layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER_HORIZONTAL,
            )
        }
        slot.addView(content)
        binder?.accept(content)
        return content
    }

    companion object {
        @JvmStatic
        fun ofView(view: View?): FrostPromptSlotContent = FrostPromptSlotContent(view, 0, null)

        @JvmStatic
        fun ofLayout(layoutRes: Int, binder: Consumer<View>?): FrostPromptSlotContent =
            FrostPromptSlotContent(null, layoutRes, binder)
    }
}
