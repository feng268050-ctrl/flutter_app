package com.lasercyber.lws.frostui.border

import android.content.Context
import androidx.annotation.ColorInt
import kotlin.jvm.JvmStatic
import androidx.compose.ui.graphics.Color
import kotlin.math.min
import kotlin.math.roundToInt

/** Preset backdrop blur strength and fill mode for frost cards. */
enum class FrostBlurIntensity(
    private val mode: Mode,
    private val overlayAlpha: Int,
    val blurRadius: Float,
) {
    /** Border-only chrome with no fill or blur. */
    TRANSPARENT(Mode.BORDER_ONLY, 0, 0f),
    /** Lightest blur tier — home stat cards when LOW reads too heavy on snapshot blur. */
    MINIMAL(Mode.BLUR, 0x0C, 8f),
    /** Light frost — subtle blur and overlay (legacy home stat cards on dev BlurView). */
    LOW(Mode.BLUR, 0x15, 12f),
    /** Default card blur (matches pre-intensity dark cards). */
    MIDDLE(Mode.BLUR, 0x30, 20f),
    /** Stronger blur between middle and extreme. */
    HIGH(Mode.BLUR, 0x40, 23f),
    /** Maximum frost (matches light-tone warm overlay concentration). */
    EXTREME(Mode.BLUR, 0x50, 25f),
    /** Opaque panel fill with no backdrop blur. */
    SOLID(Mode.SOLID_FILL, 0xFF, 0f);

    private enum class Mode {
        BORDER_ONLY,
        BLUR,
        SOLID_FILL,
    }

    fun drawsFill(): Boolean = mode != Mode.BORDER_ONLY

    fun usesBackdropBlur(): Boolean = mode == Mode.BLUR

    fun usesSolidFill(): Boolean = mode == Mode.SOLID_FILL

    /** BlurView / RenderScript radius in pixels (legacy BlurView presets on device). */
    fun blurViewRadiusPx(): Int = blurRadius.toInt().coerceIn(0, 25)

    /** @deprecated Use [blurViewRadiusPx]; retained for tests. */
    fun stackBlurRadiusPx(): Int = blurViewRadiusPx()

    /** RenderScript Gaussian radius for dialog frozen snapshots (legacy dev parity). */
    fun dialogGaussianBlurRadiusPx(): Int = min(25, blurRadius.roundToInt())

    /** Snapshot blur pass count (legacy BlurUtils / BlurView: single pass per intensity). */
    fun stackBlurPasses(): Int = 1

    /** Legacy {@code overlayAlpha} for parity tests (dev {@code FrostedGlassBlurIntensity}). */
    internal fun legacyOverlayAlpha(): Int = overlayAlpha

    fun resolveOverlayColor(context: Context, tint: FrostBlurTint): Color {
        val rgb = tint.resolveColorInt(context) and 0x00FFFFFF
        return Color((overlayAlpha shl 24) or rgb)
    }

    @ColorInt
    fun resolveOverlayColorInt(context: Context, tint: FrostBlurTint): Int {
        val rgb = tint.resolveColorInt(context) and 0x00FFFFFF
        return (overlayAlpha shl 24) or rgb
    }

    companion object {
        @JvmStatic
        fun fromXmlValue(xmlValue: Int): FrostBlurIntensity = when (xmlValue) {
            0 -> LOW
            1 -> MIDDLE
            2 -> HIGH
            3 -> EXTREME
            4 -> TRANSPARENT
            5 -> SOLID
            6 -> MINIMAL
            else -> MIDDLE
        }
    }
}
