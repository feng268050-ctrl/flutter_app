package com.lasercyber.lws.frostui.button

import android.content.Context
import androidx.compose.ui.unit.Dp
import com.lasercyber.lws.frostui.border.FrostDimens

/**
 * Compose defaults for [FrostButton], aligned with [com.lasercyber.lws.ui.R.style.FrostButton]
 * and tokens in `frostui_dimens.xml` (`frost_action_button_*`).
 */
object FrostButtonDefaults {

    fun minHeight(context: Context, size: FrostButtonSize): Dp = when (size) {
        FrostButtonSize.DEFAULT -> FrostDimens.actionButtonHeight(context)
        FrostButtonSize.SMALL -> FrostDimens.actionButtonSmallHeight(context)
    }

    fun horizontalPadding(context: Context, size: FrostButtonSize): Dp = when (size) {
        FrostButtonSize.DEFAULT -> FrostDimens.actionButtonPaddingHorizontal(context)
        FrostButtonSize.SMALL -> FrostDimens.actionButtonSmallPaddingHorizontal(context)
    }

    /** `null` edge → size default; explicit `0.dp` is preserved by callers. */
    fun resolveHorizontalPaddingStart(
        context: Context,
        size: FrostButtonSize,
        horizontalPadding: Dp?,
        horizontalPaddingStart: Dp?,
    ): Dp = horizontalPaddingStart ?: horizontalPadding ?: horizontalPadding(context, size)

    fun resolveHorizontalPaddingEnd(
        context: Context,
        size: FrostButtonSize,
        horizontalPadding: Dp?,
        horizontalPaddingEnd: Dp?,
    ): Dp = horizontalPaddingEnd ?: horizontalPadding ?: horizontalPadding(context, size)
}
