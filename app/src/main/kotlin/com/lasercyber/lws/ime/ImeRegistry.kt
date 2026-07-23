package com.lasercyber.lws.ime

import android.app.Activity
import android.view.View
import java.util.Locale

/** App-layer hooks; `ime/core` MUST NOT import frostui or ui packages. */
object ImeRegistry {
    @JvmField
    var languageProvider: (() -> Locale)? = null

    @JvmField
    var onKeyboardShown: ((Activity, Int) -> Unit)? = null

    @JvmField
    var onAnchorLiftApplied: ((View) -> Unit)? = null

    @JvmField
    var onCardBackdropRefresh: ((View) -> Unit)? = null

    @JvmStatic
    fun setLanguageProvider(provider: () -> Locale) {
        languageProvider = provider
    }

    @JvmStatic
    fun setOnKeyboardShown(listener: (Activity, Int) -> Unit) {
        onKeyboardShown = listener
    }

    @JvmStatic
    fun setOnAnchorLiftApplied(listener: (View) -> Unit) {
        onAnchorLiftApplied = listener
    }

    @JvmStatic
    fun setOnCardBackdropRefresh(listener: (View) -> Unit) {
        onCardBackdropRefresh = listener
    }
}
