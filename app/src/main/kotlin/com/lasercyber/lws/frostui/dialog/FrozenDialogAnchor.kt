package com.lasercyber.lws.frostui.dialog

/**
 * Dialog card bounds relative to [android.R.id.content], captured together with the frozen backdrop.
 * Used to crop a fixed blur region so list growth does not slide the in-card blur texture.
 */
data class FrozenDialogAnchor(
    val leftPx: Int,
    val topPx: Int,
    val widthPx: Int,
    val heightPx: Int,
) {
    fun isValid(): Boolean = widthPx > 0 && heightPx > 0

    fun matchesScreenBounds(other: FrozenDialogAnchor?): Boolean =
        other != null &&
            leftPx == other.leftPx &&
            topPx == other.topPx &&
            widthPx == other.widthPx &&
            heightPx == other.heightPx
}
