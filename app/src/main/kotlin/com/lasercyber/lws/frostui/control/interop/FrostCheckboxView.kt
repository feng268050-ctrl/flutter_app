package com.lasercyber.lws.frostui.control.interop

import android.content.Context
import android.util.AttributeSet
import android.widget.Checkable
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.AbstractComposeView
import androidx.compose.ui.unit.sp
import com.lasercyber.lws.frostui.control.FrostCheckbox
import com.lasercyber.lws.frostui.control.shouldNotifyCheckedChange
import com.lasercyber.lws.ui.R

/** XML/Java bridge embedding [FrostCheckbox]. */
class FrostCheckboxView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = R.attr.frostCheckboxStyle,
) : AbstractComposeView(context, attrs, defStyleAttr), Checkable {

    private val initial = FrostControlAttrs.readCheckbox(context, attrs, defStyleAttr)
    private var checkedState by mutableStateOf(initial.checked)
    private var labelText by mutableStateOf(initial.labelText)
    private var appearance by mutableStateOf(initial.appearance)
    private var frostEnabled by mutableStateOf(true)
    private var checkedChangeListener: OnCheckedChangeListener? = null

    fun interface OnCheckedChangeListener {
        fun onCheckedChanged(checkbox: FrostCheckboxView, isChecked: Boolean)
    }

    fun setOnCheckedChangeListener(listener: OnCheckedChangeListener?) {
        checkedChangeListener = listener
    }

    fun setLabelText(text: CharSequence?) {
        labelText = text?.toString()
    }

    fun getLabelText(): CharSequence? = labelText

    /** Updates only the label size, keeping all other checkbox appearance tokens. */
    fun setLabelTextSizeSp(sizeSp: Float) {
        appearance = appearance.copy(labelSize = sizeSp.sp)
    }

    /** Updates only the checked fill color (ARGB), keeping other appearance tokens. */
    fun setCheckedFillColor(colorArgb: Int) {
        appearance = appearance.copy(checkedFillColor = Color(colorArgb))
    }

    override fun isChecked(): Boolean = checkedState

    override fun setChecked(checked: Boolean) {
        if (checkedState == checked) {
            return
        }
        val wasChecked = checkedState
        checkedState = checked
        refreshDrawableState()
        if (shouldNotifyCheckedChange(wasChecked, checked)) {
            checkedChangeListener?.onCheckedChanged(this, checked)
        }
    }

    override fun toggle() {
        setChecked(!checkedState)
    }

    override fun setEnabled(enabled: Boolean) {
        super.setEnabled(enabled)
        frostEnabled = enabled
    }

    @Composable
    override fun Content() {
        FrostCheckbox(
            checked = checkedState,
            onCheckedChange = { setChecked(it) },
            enabled = frostEnabled,
            label = labelText,
            appearance = appearance,
        )
    }

    override fun onCreateDrawableState(extraSpace: Int): IntArray {
        val state = super.onCreateDrawableState(extraSpace + 1)
        if (checkedState) {
            mergeDrawableStates(state, CHECKED_STATE_SET)
        }
        return state
    }

    companion object {
        private val CHECKED_STATE_SET = intArrayOf(android.R.attr.state_checked)
    }
}
