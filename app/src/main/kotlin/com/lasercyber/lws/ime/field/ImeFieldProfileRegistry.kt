package com.lasercyber.lws.ime.field

import com.lasercyber.lws.ime.field.policy.NumericPolicy
import com.lasercyber.lws.ime.field.policy.NumericPolicyConfig
import com.lasercyber.lws.ime.keyboard.KeyboardKind

object ImeFieldProfileRegistry {
    fun profile(
        type: ImeFieldType,
        numericPolicyOverride: NumericPolicyConfig? = null,
    ): ImeFieldProfile = when (type) {
        ImeFieldType.Text -> ImeFieldProfile(
            initialLayoutId = KeyboardLayoutId.QwertyGlobal,
            allowedLayoutIds = ImeFieldProfile.symbolLayersPlusQwerty(),
            bottomRowProfile = ImeBottomRowProfile.Default,
        )
        ImeFieldType.Number -> ImeFieldProfile(
            initialLayoutId = KeyboardLayoutId.NumericDedicatedB,
            allowedLayoutIds = setOf(KeyboardLayoutId.NumericDedicatedB),
            numericPolicyConfig = numericPolicyOverride ?: NumericPolicy.forInteger(),
        )
        ImeFieldType.SignedDecimal -> ImeFieldProfile(
            initialLayoutId = KeyboardLayoutId.NumericDedicatedB,
            allowedLayoutIds = setOf(KeyboardLayoutId.NumericDedicatedB),
            numericPolicyConfig = numericPolicyOverride ?: NumericPolicy.forSignedDecimal(),
        )
        ImeFieldType.Email -> ImeFieldProfile(
            initialLayoutId = KeyboardLayoutId.QwertyGlobal,
            allowedLayoutIds = ImeFieldProfile.symbolLayersPlusQwerty(),
            bottomRowProfile = ImeBottomRowProfile.Email(comSuffixKey = true),
        )
        ImeFieldType.Uri -> ImeFieldProfile(
            initialLayoutId = KeyboardLayoutId.QwertyGlobal,
            allowedLayoutIds = ImeFieldProfile.symbolLayersPlusQwerty(),
            bottomRowProfile = ImeBottomRowProfile.Uri,
        )
        ImeFieldType.Password -> ImeFieldProfile(
            initialLayoutId = KeyboardLayoutId.QwertyGlobal,
            allowedLayoutIds = ImeFieldProfile.symbolLayersPlusQwerty(),
            bottomRowProfile = ImeBottomRowProfile.Password(showHideKey = true),
            maskInput = true,
        )
        ImeFieldType.WiFi -> ImeFieldProfile(
            initialLayoutId = KeyboardLayoutId.QwertyGlobal,
            allowedLayoutIds = ImeFieldProfile.symbolLayersPlusQwerty(),
            bottomRowProfile = ImeBottomRowProfile.WiFi,
            maskInput = true,
        )
    }

    fun initialKind(type: ImeFieldType): KeyboardKind = profile(type).initialKind
}
