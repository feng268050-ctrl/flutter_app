package com.lasercyber.lws.frostui.border

import android.content.Context
import androidx.compose.ui.unit.Dp

/** Typed accessors for frost design-token dimensions. */
object FrostDimens {

    fun cornerRadius(context: Context): Dp = FrostResources.dimenDp(context, "frost_corner_radius")
    fun cornerRadiusPx(context: Context): Float = FrostResources.dimenPx(context, "frost_corner_radius")

    fun contentPadding(context: Context): Dp = FrostResources.dimenDp(context, "frost_dialog_content_padding")

    fun rectangleButtonCornerRadius(context: Context): Dp =
        FrostResources.dimenDp(context, "frost_rectangle_button_corner_radius")

    /** Rectangular frost controls (IME keys, steppers) share [rectangleButtonCornerRadius]. */
    fun buttonCornerRadius(context: Context): Dp = rectangleButtonCornerRadius(context)
    fun buttonStrokeWidth(context: Context): Dp = FrostResources.dimenDp(context, "frost_button_stroke_width")

    fun actionButtonHeight(context: Context): Dp = FrostResources.dimenDp(context, "frost_action_button_height")
    fun actionButtonPaddingHorizontal(context: Context): Dp =
        FrostResources.dimenDp(context, "frost_action_button_padding_horizontal")
    fun actionButtonTextSize(context: Context): Dp =
        FrostResources.dimenDp(context, "frost_action_button_text_size")
    fun actionButtonSmallHeight(context: Context): Dp =
        FrostResources.dimenDp(context, "frost_action_button_small_height")
    fun actionButtonSmallPaddingHorizontal(context: Context): Dp =
        FrostResources.dimenDp(context, "frost_action_button_small_padding_horizontal")
    fun actionButtonSpacing(context: Context): Dp =
        FrostResources.dimenDp(context, "frost_dialog_content_padding")

    fun promptContentInset(context: Context): Dp =
        FrostResources.dimenDp(context, "frost_dialog_prompt_content_inset")
    fun promptTitleTextSize(context: Context): Dp =
        FrostResources.dimenDp(context, "frost_dialog_prompt_title_text_size")

    fun popupMenuCardPadding(context: Context): Dp =
        FrostResources.dimenDp(context, "frost_popup_menu_card_padding")
    fun popupMenuItemCornerRadius(context: Context): Dp =
        FrostResources.dimenDp(context, "frost_popup_menu_item_corner_radius")

    /** Default 1dp border width matching legacy drawable density-based stroke. */
    fun defaultBorderWidthPx(context: Context): Float = context.resources.displayMetrics.density

    fun buttonStrokeWidthPx(context: Context): Float =
        FrostResources.dimenPx(context, "frost_button_stroke_width")

    fun fadeInDurationMs(context: Context): Int =
        FrostResources.integer(context, "frost_dialog_fade_in_duration_ms")
    fun fadeOutDurationMs(context: Context): Int =
        FrostResources.integer(context, "frost_dialog_fade_out_duration_ms")
}
