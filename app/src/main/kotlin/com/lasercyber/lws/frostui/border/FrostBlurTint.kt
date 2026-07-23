package com.lasercyber.lws.frostui.border

import android.content.Context
import androidx.annotation.ColorInt
import kotlin.jvm.JvmStatic
import androidx.compose.ui.graphics.Color

/** Preset overlay tints for live backdrop blur. */
enum class FrostBlurTint(private val colorName: String) {
    /** Neutral dark tint for dark or busy backdrops (default). */
    DARK("frost_blur_tint"),
    /** Warm cream tint for yellow-white dialog wallpapers. */
    WARM("frost_blur_tint_warm");

    fun resolveColor(context: Context): Color = FrostResources.color(context, colorName)

    @ColorInt
    fun resolveColorInt(context: Context): Int = FrostResources.colorInt(context, colorName)

    companion object {
        @JvmStatic
        fun fromIndex(index: Int): FrostBlurTint {
            val values = entries
            return if (index in values.indices) values[index] else DARK
        }
    }
}
