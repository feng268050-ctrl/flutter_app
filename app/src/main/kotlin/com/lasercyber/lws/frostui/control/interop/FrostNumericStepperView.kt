package com.lasercyber.lws.frostui.control.interop

import android.content.Context
import android.text.InputFilter
import android.util.AttributeSet
import android.widget.EditText
import android.widget.TextView
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.AbstractComposeView
import com.lasercyber.lws.frostui.control.FrostNumericStepper
import com.lasercyber.lws.frostui.control.FrostNumericStepperLogic
import com.lasercyber.lws.ui.R
import java.math.BigDecimal

/** Notified when the embedded [EditText] is composed and ready for IME attachment. */
fun interface OnEditTextReadyListener {
    fun onEditTextReady(editText: EditText)
}

/** XML/Java bridge embedding [FrostNumericStepper]. */
class FrostNumericStepperView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = R.attr.frostNumericStepperStyle,
) : AbstractComposeView(context, attrs, defStyleAttr) {

    private var appearance by mutableStateOf(
        FrostControlAttrs.readNumericStepper(context, attrs, defStyleAttr).appearance,
    )
    private var textValue by mutableStateOf("")
    private var descriptionTextValue by mutableStateOf<String?>(null)
    private var stepperVisible by mutableStateOf(true)
    private var frostEnabled by mutableStateOf(true)
    private var inputTypeValue by mutableStateOf(
        android.text.InputType.TYPE_CLASS_NUMBER or
            android.text.InputType.TYPE_NUMBER_FLAG_DECIMAL,
    )
    private var inputFiltersValue by mutableStateOf<Array<InputFilter>?>(null)
    private var decimalStepEnabled by mutableStateOf(false)
    private var decimalStepSizeValue by mutableStateOf(FrostNumericStepperLogic.METRIC_DECIMAL_STEP)
    private var minValueLimit by mutableStateOf(0)
    private var maxValueLimit by mutableStateOf(Int.MAX_VALUE)
    private var editTextRef: EditText? = null
    private var editorActionListener: TextView.OnEditorActionListener? = null
    private var editTextReadyListener: OnEditTextReadyListener? = null

    fun getEditText(): EditText? = editTextRef

    fun setOnEditTextReadyListener(listener: OnEditTextReadyListener?) {
        editTextReadyListener = listener
        editTextRef?.let { listener?.onEditTextReady(it) }
    }

    fun getText(): CharSequence = textValue

    fun setText(text: CharSequence?) {
        textValue = text?.toString() ?: ""
    }

    fun setDescriptionText(text: CharSequence?) {
        descriptionTextValue = text?.toString()
    }

    fun setShowStepper(show: Boolean) {
        stepperVisible = show
    }

    fun setInputType(type: Int) {
        inputTypeValue = type
    }

    fun setInputFilters(filters: Array<InputFilter>?) {
        inputFiltersValue = filters
    }

    fun setDecimalStep(enabled: Boolean, stepSize: BigDecimal) {
        decimalStepEnabled = enabled
        decimalStepSizeValue = stepSize
    }

    fun setMinMax(min: Int, max: Int) {
        minValueLimit = min
        maxValueLimit = max
    }

    fun setOnEditorActionListener(listener: TextView.OnEditorActionListener?) {
        editorActionListener = listener
    }

    fun applyDefaultInput(defaultInput: String?, type: Int) {
        setText(FrostNumericStepperLogic.formatDefaultInput(defaultInput, type))
    }

    override fun setEnabled(enabled: Boolean) {
        super.setEnabled(enabled)
        frostEnabled = enabled
    }

    @Composable
    override fun Content() {
        FrostNumericStepper(
            text = textValue,
            onTextChange = { textValue = it },
            descriptionText = descriptionTextValue,
            showStepper = stepperVisible,
            enabled = frostEnabled,
            inputType = inputTypeValue,
            inputFilters = inputFiltersValue,
            decimalStep = decimalStepEnabled,
            decimalStepSize = decimalStepSizeValue,
            minValue = minValueLimit,
            maxValue = maxValueLimit,
            appearance = appearance,
            onEditTextReady = { editText ->
                editTextRef = editText
                editTextReadyListener?.onEditTextReady(editText)
            },
            onEditorActionListener = editorActionListener,
        )
    }
}
