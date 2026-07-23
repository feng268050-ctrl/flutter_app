package com.lasercyber.lws.ime.field.policy

import com.lasercyber.lws.ime.keyboard.KeyDef
import com.lasercyber.lws.ime.keyboard.KeyId
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NumericPolicyTest {

    private val minus = KeyDef(id = KeyId.Minus, primary = "-")
    private val decimal = KeyDef(id = KeyId.DecimalPeriod, primary = ".")
    private val doubleZero = KeyDef(id = KeyId.Custom, primary = "00")
    private val digit = KeyDef(id = KeyId.Digit, primary = "5")

    @Test
    fun integerPolicy_allowsDigitsBlocksSignAndDecimal() {
        val config = NumericPolicy.forInteger()
        assertTrue(NumericPolicy.shouldCommit(digit, "", config))
        assertFalse(NumericPolicy.shouldCommit(minus, "", config))
        assertFalse(NumericPolicy.shouldCommit(decimal, "1", config))
    }

    @Test
    fun signedIntegerPolicy_allowsLeadingMinusOnce() {
        val config = NumericPolicy.forSignedInteger()
        assertTrue(NumericPolicy.shouldCommit(minus, "", config))
        assertFalse(NumericPolicy.shouldCommit(minus, "-1", config))
        assertFalse(NumericPolicy.shouldCommit(decimal, "1", config))
    }

    @Test
    fun signedDecimalPolicy_allowsSingleDecimalPoint() {
        val config = NumericPolicy.forSignedDecimal()
        assertTrue(NumericPolicy.shouldCommit(decimal, "1", config))
        assertFalse(NumericPolicy.shouldCommit(decimal, "1.2", config))
        assertTrue(NumericPolicy.shouldCommit(minus, "", config))
    }

    @Test
    fun doubleZero_respectsAllowDoubleZeroFlag() {
        val allowed = NumericPolicyConfig(allowDoubleZero = true)
        val blocked = NumericPolicyConfig(allowDoubleZero = false)
        assertTrue(NumericPolicy.shouldCommit(doubleZero, "", allowed))
        assertFalse(NumericPolicy.shouldCommit(doubleZero, "", blocked))
    }
}
