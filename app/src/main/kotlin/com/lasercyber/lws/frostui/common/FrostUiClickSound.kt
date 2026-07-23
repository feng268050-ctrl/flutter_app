package com.lasercyber.lws.frostui.common

/** App-injected click sound contract (delegates to {@code GlobalSoundManager} in ui). */
fun interface FrostUiClickSound {
    fun playClick()
}
