package com.lasercyber.lws.frostui.control.interop

import android.content.Context
import android.util.AttributeSet
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.AbstractComposeView
import com.lasercyber.lws.frostui.control.FrostStatusIndicator
import com.lasercyber.lws.frostui.control.FrostStatusState
import com.lasercyber.lws.frostui.control.FrostStatusVariant
import com.lasercyber.lws.ui.R

/** XML/Java bridge embedding [FrostStatusIndicator]. Read-only status light. */
class FrostStatusIndicatorView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = R.attr.frostStatusIndicatorStyle,
) : AbstractComposeView(context, attrs, defStyleAttr) {

    private val initial = FrostControlAttrs.readStatusIndicator(context, attrs, defStyleAttr)
    private var statusState by mutableStateOf(initial.state)
    private var statusVariant by mutableStateOf(initial.variant)
    private var appearance by mutableStateOf(initial.appearance)

    fun getState(): FrostStatusState = statusState

    fun setState(state: FrostStatusState) {
        if (statusState != state) {
            statusState = state
        }
    }

    fun getVariant(): FrostStatusVariant = statusVariant

    fun setVariant(variant: FrostStatusVariant) {
        if (statusVariant != variant) {
            statusVariant = variant
        }
    }

    @Composable
    override fun Content() {
        FrostStatusIndicator(
            state = statusState,
            variant = statusVariant,
            appearance = appearance,
            modifier = Modifier,
        )
    }
}
