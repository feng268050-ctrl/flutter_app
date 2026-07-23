package com.lasercyber.lws.ime.interop

import com.lasercyber.lws.ime.ImeAction
import com.lasercyber.lws.ime.core.ImeConfig
import com.lasercyber.lws.ime.field.ImeFieldType
import com.lasercyber.lws.ime.field.policy.NumericPolicyConfig

/** IME keyboard + controller configuration for a frost overlay prompt. */
class ImeOverlaySpec private constructor(
    val config: ImeConfig,
    val fieldType: ImeFieldType,
    val numericPolicyOverride: NumericPolicyConfig?,
    private val editorActionHandler: (ImeAction) -> Boolean,
) {
    fun onEditorAction(action: ImeAction): Boolean = editorActionHandler(action)

    /** @deprecated Use [fieldType] == [ImeFieldType.Number] or dedicated numeric types. */
    @Deprecated("Use fieldType", ReplaceWith("fieldType == ImeFieldType.Number || fieldType == ImeFieldType.SignedDecimal"))
    val numericInput: Boolean
        get() = fieldType == ImeFieldType.Number || fieldType == ImeFieldType.SignedDecimal

    companion object {
        @JvmStatic
        @JvmOverloads
        fun create(
            config: ImeConfig,
            fieldType: ImeFieldType,
            onEditorAction: (ImeAction) -> Boolean,
            numericPolicyOverride: NumericPolicyConfig? = null,
        ): ImeOverlaySpec = ImeOverlaySpec(config, fieldType, numericPolicyOverride, onEditorAction)

        @JvmStatic
        @Deprecated("Use create(config, fieldType, onEditorAction)")
        fun create(
            config: ImeConfig,
            numericInput: Boolean,
            onEditorAction: (ImeAction) -> Boolean,
        ): ImeOverlaySpec = create(
            config = config,
            fieldType = if (numericInput) ImeFieldType.Number else ImeFieldType.Text,
            onEditorAction = onEditorAction,
        )
    }
}
