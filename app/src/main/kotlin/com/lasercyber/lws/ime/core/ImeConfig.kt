package com.lasercyber.lws.ime.core

import com.lasercyber.lws.ime.engine.ImeEnterKeyConfig

data class ImeConfig(
    val hostAdjustPolicy: HostAdjustPolicy = HostAdjustPolicy.AdjustNothing,
    val cardLiftPolicy: CardLiftPolicy = CardLiftPolicy.TranslateCenterOrAboveKeyboard,
    val enterKey: ImeEnterKeyConfig = ImeEnterKeyConfig.done(),
    val keyboardMarginDp: Float = 24f,
    val visibleThresholdPx: Int = 80,
    val useCustomKeyboard: Boolean = true,
) {
    companion object {
        @JvmStatic
        fun defaults(): ImeConfig = ImeConfig()

        @JvmStatic
        fun withEnterKey(enterKey: ImeEnterKeyConfig): ImeConfig =
            ImeConfig(enterKey = enterKey)
    }
}
