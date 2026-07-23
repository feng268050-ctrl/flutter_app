package com.lasercyber.lws.frostui.border

import android.content.Context

/**
 * Visual tone for frost overlays.
 *
 * - [DARK] — centered frosted card on dim scrim (default prompts)
 * - [LIGHT] — large light panel with warm gradient, snapshot blur, and shell frost
 */
enum class FrostTone(private val overlayLayoutName: String) {
    DARK("dialog_frost_prompt"),
    LIGHT("dialog_frost_light_overlay");

    fun overlayLayoutId(context: Context): Int = FrostResources.layoutId(context, overlayLayoutName)

    fun blurTint(): FrostBlurTint = if (this == LIGHT) FrostBlurTint.WARM else FrostBlurTint.DARK

    fun blurIntensity(): FrostBlurIntensity =
        if (this == LIGHT) FrostBlurIntensity.EXTREME else FrostBlurIntensity.MIDDLE
}
