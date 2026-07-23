package com.lasercyber.lws.ime.engine

import androidx.annotation.DrawableRes
import com.lasercyber.lws.ime.ImeAction

/** Enter key face content; shell is always PRIMARY frosted glass + [ReturnArrowIcon]. */
sealed interface ImeEnterKeyDisplay {
    data class Text(val label: String) : ImeEnterKeyDisplay

    data class Icon(
        @DrawableRes val iconRes: Int,
        val contentDescription: String? = null,
    ) : ImeEnterKeyDisplay

    data class TextAndIcon(
        val label: String,
        @DrawableRes val iconRes: Int,
        val contentDescription: String? = null,
    ) : ImeEnterKeyDisplay

    data object Default : ImeEnterKeyDisplay
}

data class ImeEnterKeyConfig(
    val display: ImeEnterKeyDisplay = ImeEnterKeyDisplay.Default,
    val action: ImeAction = ImeAction.Done,
) {
    companion object {
        @JvmStatic
        fun done(): ImeEnterKeyConfig = ImeEnterKeyConfig()

        @JvmStatic
        fun text(label: String, action: ImeAction = ImeAction.Done): ImeEnterKeyConfig =
            ImeEnterKeyConfig(display = ImeEnterKeyDisplay.Default, action = action)

        @JvmStatic
        fun customConnect(label: String): ImeEnterKeyConfig =
            ImeEnterKeyConfig(
                display = ImeEnterKeyDisplay.Default,
                action = ImeAction.Custom(ImeAction.WIFI_PASSWORD_CONNECT_ACTION_ID, label),
            )
    }
}
