package com.lasercyber.lws.frostui.common

object FrostUiClickSoundRegistry {
    @Volatile
    private var clickSound: FrostUiClickSound? = null

    @JvmStatic
    fun register(provider: FrostUiClickSound) {
        clickSound = provider
    }

    internal fun playClick() {
        clickSound?.playClick()
    }
}
