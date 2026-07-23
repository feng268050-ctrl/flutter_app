package com.lasercyber.lws.ime

/** Editor action triggered by the custom IME Enter key or hardware Enter. */
sealed class ImeAction {
    data object Done : ImeAction()
    data object Go : ImeAction()
    data class Custom(val actionId: Int, val label: String) : ImeAction()

    companion object {
        const val WIFI_PASSWORD_CONNECT_ACTION_ID = 1001
    }
}
