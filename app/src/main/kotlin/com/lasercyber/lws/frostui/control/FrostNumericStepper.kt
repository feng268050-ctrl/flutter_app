package com.lasercyber.lws.frostui.control

import android.text.InputFilter
import android.text.TextWatcher
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.lasercyber.lws.frostui.button.FrostButton
import com.lasercyber.lws.frostui.button.FrostButtonShape
import com.lasercyber.lws.frostui.button.FrostButtonVariant
import com.lasercyber.lws.ui.R
import java.math.BigDecimal

data class FrostNumericStepperAppearance(
    val descriptionTextColor: Color,
    val descriptionTextSize: TextUnit,
    val descriptionLineSpacingExtra: Dp,
    val descriptionBottomMargin: Dp,
    val stepButtonSize: Dp,
    val stepButtonTextSize: TextUnit,
    val stepButtonTextColor: Color,
    val fieldWidth: Dp,
    val fieldMinHeight: Dp,
    val fieldHorizontalMargin: Dp,
    val fieldBackgroundRes: Int,
    val fieldTextColor: Color,
    val fieldTextSize: TextUnit,
    val fieldPaddingHorizontal: Dp,
    val fieldPaddingVertical: Dp,
    val horizontalPadding: Dp,
)

object FrostNumericStepperDefaults {
    fun appearance(context: android.content.Context): FrostNumericStepperAppearance {
        val resources = context.resources
        return FrostNumericStepperAppearance(
            descriptionTextColor = Color(
                ContextCompat.getColor(context, R.color.frost_text_secondary),
            ),
            descriptionTextSize = context.pxToSp(
                resources.getDimension(R.dimen.frost_stepper_description_text_size),
            ),
            descriptionLineSpacingExtra = 4.dp,
            descriptionBottomMargin = 12.dp,
            stepButtonSize = context.pxToDp(resources.getDimension(R.dimen.frost_stepper_step_button_size)),
            stepButtonTextSize = context.pxToSp(
                resources.getDimension(R.dimen.frost_stepper_step_button_text_size),
            ),
            stepButtonTextColor = Color(
                ContextCompat.getColor(context, R.color.frost_button_secondary_text),
            ),
            fieldWidth = context.pxToDp(resources.getDimension(R.dimen.frost_dialog_numeric_input_field_width)),
            fieldMinHeight = context.pxToDp(resources.getDimension(R.dimen.frost_stepper_field_min_height)),
            fieldHorizontalMargin = 12.dp,
            fieldBackgroundRes = R.drawable.dialog_edit_bg,
            fieldTextColor = Color(
                ContextCompat.getColor(context, R.color.frost_text_primary),
            ),
            fieldTextSize = context.pxToSp(resources.getDimension(R.dimen.frost_stepper_field_text_size)),
            fieldPaddingHorizontal = 16.dp,
            fieldPaddingVertical = 12.dp,
            horizontalPadding = context.pxToDp(resources.getDimension(R.dimen.frost_stepper_horizontal_padding)),
        )
    }
}

@Composable
fun FrostNumericStepper(
    text: String,
    onTextChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    descriptionText: String? = null,
    showStepper: Boolean = true,
    enabled: Boolean = true,
    inputType: Int = android.text.InputType.TYPE_CLASS_NUMBER or
        android.text.InputType.TYPE_NUMBER_FLAG_DECIMAL,
    inputFilters: Array<InputFilter>? = null,
    decimalStep: Boolean = false,
    decimalStepSize: BigDecimal = FrostNumericStepperLogic.METRIC_DECIMAL_STEP,
    minValue: Int = 0,
    maxValue: Int = Int.MAX_VALUE,
    appearance: FrostNumericStepperAppearance = FrostNumericStepperDefaults.appearance(LocalContext.current),
    onEditTextReady: ((EditText) -> Unit)? = null,
    onEditorActionListener: android.widget.TextView.OnEditorActionListener? = null,
) {
    val context = LocalContext.current
    val density = LocalDensity.current
    val fieldMinHeightPx = with(density) { appearance.fieldMinHeight.roundToPx() }
    val fieldPaddingHorizontalPx = with(density) { appearance.fieldPaddingHorizontal.roundToPx() }
    val fieldPaddingVerticalPx = with(density) { appearance.fieldPaddingVertical.roundToPx() }
    val fieldTextColorInt = appearance.fieldTextColor.toArgb()
    val fieldTextSizePx = with(density) { appearance.fieldTextSize.toPx() }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = appearance.horizontalPadding),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (!descriptionText.isNullOrEmpty()) {
            Text(
                text = descriptionText,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = appearance.descriptionBottomMargin),
                color = appearance.descriptionTextColor,
                fontSize = appearance.descriptionTextSize,
                textAlign = TextAlign.Center,
                lineHeight = (appearance.descriptionTextSize.value + appearance.descriptionLineSpacingExtra.value).sp,
            )
        }

        Row(
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (showStepper) {
                FrostButton(
                    text = "−",
                    onClick = {
                        onTextChange(
                            FrostNumericStepperLogic.applyStep(
                                text,
                                increment = false,
                                decimalStep,
                                decimalStepSize,
                                minValue,
                                maxValue,
                            ),
                        )
                    },
                    modifier = Modifier.size(appearance.stepButtonSize),
                    variant = FrostButtonVariant.DEFAULT,
                    shape = FrostButtonShape.RECTANGLE,
                    enabled = enabled,
                    horizontalPadding = 0.dp,
                    textSize = appearance.stepButtonTextSize,
                )
            }

            AndroidView(
                modifier = Modifier
                    .width(appearance.fieldWidth)
                    .defaultMinSize(minHeight = appearance.fieldMinHeight)
                    .padding(horizontal = appearance.fieldHorizontalMargin),
                factory = { context ->
                    EditText(context).apply {
                        gravity = Gravity.CENTER
                        textAlignment = View.TEXT_ALIGNMENT_CENTER
                        isSingleLine = true
                        imeOptions = EditorInfo.IME_ACTION_DONE
                        minHeight = fieldMinHeightPx
                        setBackgroundResource(appearance.fieldBackgroundRes)
                        setTextColor(fieldTextColorInt)
                        setTextSize(TypedValue.COMPLEX_UNIT_PX, fieldTextSizePx)
                        setPadding(
                            fieldPaddingHorizontalPx,
                            fieldPaddingVerticalPx,
                            fieldPaddingHorizontalPx,
                            fieldPaddingVerticalPx,
                        )
                        onEditTextReady?.invoke(this)
                    }
                },
                update = { editText ->
                    editText.isEnabled = enabled
                    editText.inputType = inputType
                    editText.filters = inputFilters ?: emptyArray()
                    if (editText.text?.toString() != text) {
                        FrostNumericStepperLogic.updateEditText(editText, text)
                    }
                    editText.setOnEditorActionListener(onEditorActionListener)

                    if (editText.getTag() !is TextWatcher) {
                        val watcher = object : TextWatcher {
                            override fun beforeTextChanged(
                                s: CharSequence?,
                                start: Int,
                                count: Int,
                                after: Int,
                            ) = Unit

                            override fun onTextChanged(
                                s: CharSequence?,
                                start: Int,
                                before: Int,
                                count: Int,
                            ) = Unit

                            override fun afterTextChanged(s: android.text.Editable?) {
                                onTextChange(s?.toString() ?: "")
                            }
                        }
                        editText.addTextChangedListener(watcher)
                        editText.setTag(watcher)
                    }
                },
            )

            if (showStepper) {
                FrostButton(
                    text = "+",
                    onClick = {
                        onTextChange(
                            FrostNumericStepperLogic.applyStep(
                                text,
                                increment = true,
                                decimalStep,
                                decimalStepSize,
                                minValue,
                                maxValue,
                            ),
                        )
                    },
                    modifier = Modifier.size(appearance.stepButtonSize),
                    variant = FrostButtonVariant.DEFAULT,
                    shape = FrostButtonShape.RECTANGLE,
                    enabled = enabled,
                    horizontalPadding = 0.dp,
                    textSize = appearance.stepButtonTextSize,
                )
            }
        }
    }
}
