package com.lasercyber.lws.frostui.dialog

import android.content.Context

/** Resolves app resource ids by name without depending on generated `R` classes. */
object FrostResourceIds {

    fun viewId(context: Context, name: String): Int =
        context.resources.getIdentifier(name, "id", context.packageName)

    fun colorId(context: Context, name: String): Int =
        context.resources.getIdentifier(name, "color", context.packageName)

    fun integerId(context: Context, name: String): Int =
        context.resources.getIdentifier(name, "integer", context.packageName)

    fun dimenId(context: Context, name: String): Int =
        context.resources.getIdentifier(name, "dimen", context.packageName)

    fun layoutId(context: Context, name: String): Int =
        context.resources.getIdentifier(name, "layout", context.packageName)
}
