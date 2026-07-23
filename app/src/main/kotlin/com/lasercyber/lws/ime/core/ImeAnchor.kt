package com.lasercyber.lws.ime.core

/** Target that receives vertical lift while the keyboard panel is visible. */
interface ImeAnchor {
    fun applyLift(translationPx: Float)
    fun resetLift()
}
