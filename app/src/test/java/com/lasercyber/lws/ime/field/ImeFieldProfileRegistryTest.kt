package com.lasercyber.lws.ime.field

import com.lasercyber.lws.ime.field.policy.NumericPolicy
import com.lasercyber.lws.ime.keyboard.KeyboardKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ImeFieldProfileRegistryTest {

    @Test
    fun textProfile_allowsQwertyAndSymbolLayers() {
        val profile = ImeFieldProfileRegistry.profile(ImeFieldType.Text)
        assertEquals(KeyboardLayoutId.QwertyGlobal, profile.initialLayoutId)
        assertEquals(KeyboardKind.EnglishGlobal, profile.initialKind)
        assertTrue(profile.allowedLayoutIds.contains(KeyboardLayoutId.SymbolsPrimaryA))
        assertTrue(profile.allowedLayoutIds.contains(KeyboardLayoutId.SymbolsExtendedA))
    }

    @Test
    fun numberProfile_usesDedicatedKeyboardOnly() {
        val profile = ImeFieldProfileRegistry.profile(ImeFieldType.Number)
        assertEquals(KeyboardLayoutId.NumericDedicatedB, profile.initialLayoutId)
        assertEquals(setOf(KeyboardLayoutId.NumericDedicatedB), profile.allowedLayoutIds)
        assertEquals(NumericPolicy.forInteger(), profile.numericPolicyConfig)
    }

    @Test
    fun signedDecimalProfile_usesSignedDecimalPolicy() {
        val profile = ImeFieldProfileRegistry.profile(ImeFieldType.SignedDecimal)
        assertEquals(NumericPolicy.forSignedDecimal(), profile.numericPolicyConfig)
    }

    @Test
    fun wifiProfile_isDistinctFromPassword() {
        val wifi = ImeFieldProfileRegistry.profile(ImeFieldType.WiFi)
        val password = ImeFieldProfileRegistry.profile(ImeFieldType.Password)
        assertTrue(wifi.maskInput)
        assertTrue(password.maskInput)
        assertTrue(wifi.bottomRowProfile is ImeBottomRowProfile.WiFi)
        assertTrue(password.bottomRowProfile is ImeBottomRowProfile.Password)
    }

    @Test
    fun wifiBottomRow_usesDefaultRowWithoutPasswordReveal() {
        val layout = com.lasercyber.lws.ime.keyboard.KeyboardLanguageSelector.layoutForKind(
            kind = com.lasercyber.lws.ime.keyboard.KeyboardKind.EnglishGlobal,
            bottomRowProfile = ImeBottomRowProfile.WiFi,
        )
        val bottom = layout.rows.last().keys
        assertEquals(listOf("123", " ", ".", "⏎"), bottom.map { it.primary })
        assertTrue(bottom.none { it.id == com.lasercyber.lws.ime.keyboard.KeyId.PasswordReveal })
    }

    @Test
    fun emailProfile_usesEmailBottomRow() {
        val profile = ImeFieldProfileRegistry.profile(ImeFieldType.Email)
        assertTrue(profile.bottomRowProfile is ImeBottomRowProfile.Email)
    }
}
