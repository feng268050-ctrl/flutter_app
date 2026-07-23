package com.lasercyber.lws.frostui.control

import android.text.InputFilter
import android.text.InputType
import android.util.Log
import android.widget.EditText
import java.math.BigDecimal
import java.math.RoundingMode

/** Parse, clamp, step, and format helpers for frosted-glass numeric parameter input. */
object FrostNumericStepperLogic {
    private const val TAG = "FrostNumericStepper"

    @JvmField
    val METRIC_DECIMAL_STEP: BigDecimal = BigDecimal("0.1")

    @JvmField
    val IMPERIAL_DECIMAL_STEP: BigDecimal = BigDecimal("0.01")

    @JvmStatic
    fun parseInputNumber(inputData: String?): BigDecimal {
        if (inputData.isNullOrBlank()) {
            return BigDecimal.ZERO
        }
        return try {
            BigDecimal(inputData.trim())
        } catch (exception: NumberFormatException) {
            Log.w(TAG, "parseInputNumber: invalid number: $inputData", exception)
            BigDecimal.ZERO
        }
    }

    @JvmStatic
    fun clampNumeric(data: BigDecimal, minValue: Int, maxValue: Int): BigDecimal {
        val minBig = BigDecimal(minValue)
        val maxBig = BigDecimal(maxValue)
        return when {
            data < minBig -> minBig
            data > maxBig -> maxBig
            else -> data
        }
    }

    @JvmStatic
    fun formatNumericResult(
        value: BigDecimal,
        decimalStep: Boolean,
        decimalStepSize: BigDecimal,
    ): String {
        return if (decimalStep) {
            val scale = decimalStepSize.scale()
            value.setScale(scale, RoundingMode.HALF_UP).stripTrailingZeros().toPlainString()
        } else {
            value.setScale(0, RoundingMode.HALF_UP).toPlainString()
        }
    }

    @JvmStatic
    fun applyStep(
        currentInput: String?,
        increment: Boolean,
        decimalStep: Boolean,
        decimalStepSize: BigDecimal,
        minValue: Int,
        maxValue: Int,
    ): String {
        val current = parseInputNumber(currentInput)
        val delta = if (decimalStep) decimalStepSize else BigDecimal.ONE
        val result = if (increment) current + delta else current - delta
        return formatNumericResult(
            clampNumeric(result, minValue, maxValue),
            decimalStep,
            decimalStepSize,
        )
    }

    @JvmStatic
    fun formatDefaultInput(defaultInput: String?, inputType: Int): String {
        if (defaultInput.isNullOrEmpty()) {
            return ""
        }
        if (inputType and InputType.TYPE_CLASS_NUMBER == 0) {
            return defaultInput
        }
        return try {
            formatDoubleToString(defaultInput)
        } catch (_: NumberFormatException) {
            defaultInput
        }
    }

    @JvmStatic
    fun formatDoubleToString(defaultInput: String): String {
        val value = defaultInput.toDouble()
        return if (value % 1 == 0.0) {
            value.toLong().toString()
        } else {
            value.toString()
        }
    }

    @JvmStatic
    fun integerDigitFilter(): InputFilter =
        InputFilter { source, _, _, _, _, _ ->
            source.toString().replace(Regex("[^0-9]"), "")
        }

    @JvmStatic
    fun signedIntegerFilter(): InputFilter =
        InputFilter { source, start, end, dest, dstart, dend ->
            if (dest == null) {
                return@InputFilter source
            }
            val newStr = dest.toString().substring(0, dstart) +
                source.toString().substring(start, end) +
                dest.toString().substring(dend)
            if (newStr.isEmpty() || newStr.matches(Regex("^-?\\d+$")) || newStr == "-") {
                source
            } else {
                ""
            }
        }

    @JvmStatic
    fun updateEditText(input: EditText, text: String) {
        input.setText(text)
        input.setSelection(input.text?.length ?: 0)
    }
}
