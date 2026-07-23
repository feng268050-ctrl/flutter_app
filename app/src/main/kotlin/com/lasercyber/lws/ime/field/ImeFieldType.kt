package com.lasercyber.lws.ime.field

import android.text.InputType

enum class ImeFieldType {
    Text,
    Number,
    SignedDecimal,
    Email,
    Uri,
    Password,
    WiFi,
}

object ImeFieldTypeMapper {
    @JvmStatic
    fun fromAndroidInputType(inputType: Int): ImeFieldType {
        val typeClass = inputType and InputType.TYPE_MASK_CLASS
        val variation = inputType and InputType.TYPE_MASK_VARIATION
        return when {
            typeClass == InputType.TYPE_CLASS_NUMBER -> {
                val signed = inputType and InputType.TYPE_NUMBER_FLAG_SIGNED != 0
                val decimal = inputType and InputType.TYPE_NUMBER_FLAG_DECIMAL != 0
                if (signed || decimal) ImeFieldType.SignedDecimal else ImeFieldType.Number
            }
            variation == InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS -> ImeFieldType.Email
            variation == InputType.TYPE_TEXT_VARIATION_URI -> ImeFieldType.Uri
            variation == InputType.TYPE_TEXT_VARIATION_PASSWORD ||
                variation == InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD -> ImeFieldType.Password
            else -> ImeFieldType.Text
        }
    }
}
