package com.lasercyber.lws.frostui.border

import android.content.Context
import androidx.annotation.ColorInt
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.TextUnitType
import androidx.compose.ui.unit.dp

/**
 * Resolves app resources by name string without depending on generated `R` classes.
 */
object FrostResources {

    fun colorId(context: Context, name: String): Int =
        context.resources.getIdentifier(name, "color", context.packageName)

    fun dimenId(context: Context, name: String): Int =
        context.resources.getIdentifier(name, "dimen", context.packageName)

    fun integerId(context: Context, name: String): Int =
        context.resources.getIdentifier(name, "integer", context.packageName)

    fun layoutId(context: Context, name: String): Int =
        context.resources.getIdentifier(name, "layout", context.packageName)

    fun styleableId(context: Context, name: String): Int =
        context.resources.getIdentifier(name, "styleable", context.packageName)

    fun attrId(context: Context, name: String): Int =
        context.resources.getIdentifier(name, "attr", context.packageName)

    fun color(context: Context, name: String): Color {
        val id = colorId(context, name)
        require(id != 0) { "Unknown color resource: $name" }
        return Color(context.getColor(id))
    }

    @ColorInt
    fun colorInt(context: Context, name: String): Int {
        val id = colorId(context, name)
        require(id != 0) { "Unknown color resource: $name" }
        return context.getColor(id)
    }

    /** Dimension in px. */
    fun dimenPx(context: Context, name: String): Float {
        val id = dimenId(context, name)
        require(id != 0) { "Unknown dimen resource: $name" }
        return context.resources.getDimension(id)
    }

    /** Converts a dimen resource to Compose [Dp] (px from [dimenPx] ÷ display density). */
    fun dimenDp(context: Context, name: String): Dp {
        val px = dimenPx(context, name)
        return (px / context.resources.displayMetrics.density).dp
    }

    /** Converts a dimen resource (sp/dp) px value from [dimenPx] to Compose sp. */
    fun dimenSp(context: Context, name: String): TextUnit {
        val px = dimenPx(context, name)
        return TextUnit(px / context.resources.displayMetrics.scaledDensity, TextUnitType.Sp)
    }

    /** Converts [Resources.getDimension] / TypedArray px to Compose sp (matches legacy TextView px sizing). */
    fun dimensionPxToSp(context: Context, rawPx: Float): TextUnit =
        TextUnit(rawPx / context.resources.displayMetrics.scaledDensity, TextUnitType.Sp)

    fun integer(context: Context, name: String): Int {
        val id = integerId(context, name)
        require(id != 0) { "Unknown integer resource: $name" }
        return context.resources.getInteger(id)
    }
}
