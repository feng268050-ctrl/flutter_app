package com.lasercyber.lws.ime.interop

import com.lasercyber.lws.ime.field.ImeFieldType
import com.lasercyber.lws.ime.field.policy.NumericPolicy
import com.lasercyber.lws.ime.field.policy.NumericPolicyConfig

/** Java-friendly helpers for numeric dialog field typing. */
object ImeNumericFieldBridge {
    @JvmStatic
    fun fieldTypeForDialog(signed: Boolean, decimal: Boolean): ImeFieldType =
        if (decimal || signed) ImeFieldType.SignedDecimal else ImeFieldType.Number

    @JvmStatic
    fun policyOverrideForDialog(signed: Boolean, decimal: Boolean): NumericPolicyConfig? = when {
        decimal -> NumericPolicy.forSignedDecimal()
        signed -> NumericPolicy.forSignedInteger()
        else -> null
    }
}
