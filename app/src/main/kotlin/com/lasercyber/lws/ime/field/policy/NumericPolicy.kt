package com.lasercyber.lws.ime.field.policy

import com.lasercyber.lws.ime.keyboard.KeyDef
import com.lasercyber.lws.ime.keyboard.KeyId

data class NumericPolicyConfig(
    val allowSign: Boolean = false,
    val allowDecimal: Boolean = false,
    val allowDoubleZero: Boolean = true,
)

object NumericPolicy {
    fun forInteger(): NumericPolicyConfig = NumericPolicyConfig()

    fun forSignedInteger(): NumericPolicyConfig =
        NumericPolicyConfig(allowSign = true, allowDecimal = false)

    fun forSignedDecimal(): NumericPolicyConfig =
        NumericPolicyConfig(allowSign = true, allowDecimal = true)

    fun shouldCommit(key: KeyDef, currentText: String, config: NumericPolicyConfig): Boolean {
        return when (key.id) {
            KeyId.Digit -> true
            KeyId.Custom -> {
                if (key.primary == "00") {
                    config.allowDoubleZero
                } else {
                    true
                }
            }
            KeyId.Minus -> config.allowSign && canInsertSign(currentText)
            KeyId.DecimalPeriod -> config.allowDecimal && canInsertDecimal(currentText)
            KeyId.Plus -> false
            else -> true
        }
    }

    private fun canInsertSign(text: String): Boolean {
        if (text.isEmpty()) {
            return true
        }
        return !text.contains('-')
    }

    private fun canInsertDecimal(text: String): Boolean = !text.contains('.')
}
