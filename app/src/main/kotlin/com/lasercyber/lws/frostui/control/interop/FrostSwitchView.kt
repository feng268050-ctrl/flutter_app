package com.lasercyber.lws.frostui.control.interop

import android.content.Context
import android.util.AttributeSet
import android.widget.Checkable
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.AbstractComposeView
import com.lasercyber.lws.frostui.control.FrostSwitch
import com.lasercyber.lws.frostui.control.FrostControlDefaults
import com.lasercyber.lws.frostui.control.shouldNotifyCheckedChange
import com.lasercyber.lws.ui.R

/** XML/Java bridge embedding [FrostSwitch]. */
class FrostSwitchView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = R.attr.frostSwitchStyle,
) : AbstractComposeView(context, attrs, defStyleAttr), Checkable {

    private val initial = FrostControlAttrs.readSwitch(context, attrs, defStyleAttr)
    private var checkedState by mutableStateOf(initial.checked)
    private var appearance by mutableStateOf(initial.appearance)
    private var frostEnabled by mutableStateOf(true)
    private var checkedChangeListener: OnCheckedChangeListener? = null

    fun interface OnCheckedChangeListener {
        fun onCheckedChanged(switchView: FrostSwitchView, isChecked: Boolean)
    }

    fun setOnCheckedChangeListener(listener: OnCheckedChangeListener?) {
        checkedChangeListener = listener
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
        FrostSwitch(
            checked = checkedState,
            onCheckedChange = ::setCheckedFromUser,
            enabled = frostEnabled,
            appearance = appearance,
            hostView = this,
        )
    }

    /** Keeps [isPressed] true on this interop view while user listeners run (Java `isPressed()` guard). */
    private fun setCheckedFromUser(checked: Boolean) {
        if (checkedState == checked) {
            return
        }
        isPressed = true
        try {
            setChecked(checked)
        } finally {
            isPressed = false
        }
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
