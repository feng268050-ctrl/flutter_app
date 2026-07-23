package com.lasercyber.lws.ime.interop

import android.view.View
import com.lasercyber.lws.ime.core.ImeAnchor

class ViewImeAnchor(private val cardView: View) : ImeAnchor {
    override fun applyLift(translationPx: Float) {
        cardView.translationY = translationPx
    }

    override fun resetLift() {
        cardView.translationY = 0f
    }
}
