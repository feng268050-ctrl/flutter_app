package com.lasercyber.lws.ime.field

import com.lasercyber.lws.ime.keyboard.KeyDef
import com.lasercyber.lws.ime.keyboard.KeyId

/** Replaces default QWERTY bottom-row keys without duplicating the full layout. */
sealed class ImeBottomRowProfile {
    abstract fun fourthRowKeys(numericModeLabel: Boolean): List<KeyDef>

    data object Default : ImeBottomRowProfile() {
        override fun fourthRowKeys(numericModeLabel: Boolean): List<KeyDef> = defaultBottomRow(numericModeLabel)
    }

    data class Email(val comSuffixKey: Boolean = true) : ImeBottomRowProfile() {
        override fun fourthRowKeys(numericModeLabel: Boolean): List<KeyDef> = listOf(
            modeSwitch(numericModeLabel),
            space(),
            if (comSuffixKey) {
                KeyDef(id = KeyId.Custom, primary = ".com", widthWeight = 1f)
            } else {
                commaPeriod()
            },
            KeyDef(id = KeyId.At, primary = "@", widthWeight = 1f),
            enter(),
        )
    }

    data object Uri : ImeBottomRowProfile() {
        override fun fourthRowKeys(numericModeLabel: Boolean): List<KeyDef> = listOf(
            modeSwitch(numericModeLabel),
            space(),
            KeyDef(id = KeyId.Custom, primary = "/", widthWeight = 1f),
            KeyDef(id = KeyId.Custom, primary = ":", widthWeight = 1f),
            enter(),
        )
    }

    data class Password(val showHideKey: Boolean = true) : ImeBottomRowProfile() {
        override fun fourthRowKeys(numericModeLabel: Boolean): List<KeyDef> = listOf(
            modeSwitch(numericModeLabel),
            space(),
            commaPeriod(),
            if (showHideKey) {
                KeyDef(id = KeyId.PasswordReveal, primary = "👁", widthWeight = 1f)
            } else {
                KeyDef(id = KeyId.At, primary = "@", widthWeight = 1f)
            },
            enter(),
        )
    }

    /** 123 · space · . · Connect — password reveal lives on the input field, not the keyboard. */
    data object WiFi : ImeBottomRowProfile() {
        override fun fourthRowKeys(numericModeLabel: Boolean): List<KeyDef> =
            Default.fourthRowKeys(numericModeLabel)
    }

    companion object {
        private fun modeSwitch(numericModeLabel: Boolean) = KeyDef(
            id = KeyId.ModeSwitch,
            primary = if (numericModeLabel) "abc" else "123",
            widthWeight = 1.2f,
        )

        private fun space() = KeyDef(id = KeyId.Space, primary = " ", widthWeight = 5f)

        private fun commaPeriod() = KeyDef(
            id = KeyId.CommaPeriod,
            primary = ".",
            secondary = ",",
            widthWeight = 1f,
        )

        private fun enter() = KeyDef(id = KeyId.Enter, primary = "⏎", widthWeight = 1.4f)

        private fun defaultBottomRow(numericModeLabel: Boolean): List<KeyDef> = listOf(
            modeSwitch(numericModeLabel),
            space(),
            commaPeriod(),
            enter(),
        )
    }
}
