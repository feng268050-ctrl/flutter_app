package com.lasercyber.lws.frostui.border

import android.content.Context
import androidx.compose.ui.graphics.Color

/** Typed accessors for frost design-token colors. */
object FrostColors {

    // Panel fill — dark
    fun fillTop(context: Context): Color = FrostResources.color(context, "frost_fill_top")
    fun fillMid(context: Context): Color = FrostResources.color(context, "frost_fill_mid")
    fun fillBottom(context: Context): Color = FrostResources.color(context, "frost_fill_bottom")

    // Panel fill — solid
    fun fillSolidTop(context: Context): Color = FrostResources.color(context, "frost_fill_solid_top")
    fun fillSolidMid(context: Context): Color = FrostResources.color(context, "frost_fill_solid_mid")
    fun fillSolidBottom(context: Context): Color = FrostResources.color(context, "frost_fill_solid_bottom")

    // Panel fill — light
    fun lightFillTop(context: Context): Color = FrostResources.color(context, "frost_light_fill_top")
    fun lightFillMid(context: Context): Color = FrostResources.color(context, "frost_light_fill_mid")
    fun lightFillBottom(context: Context): Color = FrostResources.color(context, "frost_light_fill_bottom")

    // Panel border — dark
    fun borderHighlight(context: Context): Color = FrostResources.color(context, "frost_border_highlight")
    fun borderMid(context: Context): Color = FrostResources.color(context, "frost_border_mid")
    fun borderShadow(context: Context): Color = FrostResources.color(context, "frost_border_shadow")

    // Panel border — light
    fun lightBorderHighlight(context: Context): Color =
        FrostResources.color(context, "frost_light_border_highlight")
    fun lightBorderMid(context: Context): Color = FrostResources.color(context, "frost_light_border_mid")
    fun lightBorderShadow(context: Context): Color = FrostResources.color(context, "frost_light_border_shadow")

    // Blur / scrim / text
    fun blurTint(context: Context): Color = FrostResources.color(context, "frost_blur_tint")
    fun blurTintWarm(context: Context): Color = FrostResources.color(context, "frost_blur_tint_warm")
    fun scrim(context: Context): Color = FrostResources.color(context, "frost_dialog_scrim")
    fun textPrimary(context: Context): Color = FrostResources.color(context, "frost_text_primary")
    fun textSecondary(context: Context): Color = FrostResources.color(context, "frost_text_secondary")
    fun buttonSecondaryText(context: Context): Color =
        FrostResources.color(context, "frost_button_secondary_text")

    fun buttonPrimaryAccent(context: Context): Color =
        FrostResources.color(context, "frost_button_primary_stroke")

    fun buttonPrimaryFillTop(context: Context): Color =
        FrostResources.color(context, "frost_button_primary_fill_top")
    fun buttonPrimaryFillMid(context: Context): Color =
        FrostResources.color(context, "frost_button_primary_fill_mid")
    fun buttonPrimaryFillBottom(context: Context): Color =
        FrostResources.color(context, "frost_button_primary_fill_bottom")
    fun buttonPrimaryBorderHighlight(context: Context): Color =
        FrostResources.color(context, "frost_button_primary_border_highlight")
    fun buttonPrimaryBorderMid(context: Context): Color =
        FrostResources.color(context, "frost_button_primary_border_mid")
    fun buttonPrimaryBorderShadow(context: Context): Color =
        FrostResources.color(context, "frost_button_primary_border_shadow")

    fun buttonLightBorderHighlight(context: Context): Color =
        FrostResources.color(context, "frost_button_light_border_highlight")
    fun buttonLightBorderMid(context: Context): Color =
        FrostResources.color(context, "frost_button_light_border_mid")
    fun buttonLightBorderShadow(context: Context): Color =
        FrostResources.color(context, "frost_button_light_border_shadow")

    // Shell frost (light overlay)
    fun lightShellFrostEdge(context: Context): Color =
        FrostResources.color(context, "frost_light_shell_frost_edge")
    fun lightShellFrostCenter(context: Context): Color =
        FrostResources.color(context, "frost_light_shell_frost_center")

    // Divider
    fun dividerCenter(context: Context): Color = FrostResources.color(context, "frost_divider_center")
    fun dividerEdge(context: Context): Color = FrostResources.color(context, "frost_divider_edge")
}
