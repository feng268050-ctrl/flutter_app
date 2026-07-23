package com.lasercyber.lws.frostui.control.interop

import android.content.Context
import android.util.AttributeSet
import android.view.View
import android.widget.FrameLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.ComposeView
import com.lasercyber.lws.frostui.control.FrostSegmentedAppearance
import com.lasercyber.lws.frostui.control.FrostSegmentedControl
import com.lasercyber.lws.ui.R

/**
 * Capsule segmented control with hidden [RadioButton] children for `check(R.id.*)` compatibility.
 */
class FrostSegmentedControlView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = R.attr.frostSegmentedControlStyle,
) : FrameLayout(context, attrs, defStyleAttr) {

    init {
        clipChildren = false
        clipToPadding = false
    }

    private val radioGroup = RadioGroup(context).apply {
        orientation = RadioGroup.HORIZONTAL
        visibility = INVISIBLE
        isClickable = false
        isFocusable = false
    }
    private val composeView = ComposeView(context)
    private val initial = FrostControlAttrs.readSegmented(context, attrs, defStyleAttr)
    private var appearance by mutableStateOf(initial.appearance)
    private var clickSoundEnabled by mutableStateOf(initial.clickSoundEnabled)
    private var selectedIndex by mutableIntStateOf(0)
    private var segmentLabels by mutableStateOf<List<String>>(emptyList())
    private var segmentIds by mutableStateOf<List<Int>>(emptyList())
    private var frostEnabled by mutableStateOf(true)
    private var suppressListener = false

    init {
        isSoundEffectsEnabled = false
        addView(
            composeView,
            LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT),
        )
        addView(
            radioGroup,
            LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT),
        )
        radioGroup.setOnCheckedChangeListener { _, checkedId ->
            if (suppressListener) return@setOnCheckedChangeListener
            val index = segmentIds.indexOf(checkedId)
            if (index >= 0 && index != selectedIndex) {
                selectedIndex = index
            }
            externalListener?.onCheckedChanged(radioGroup, checkedId)
        }
        composeView.setContent {
            if (segmentLabels.isNotEmpty()) {
                FrostSegmentedControl(
                    selectedIndex = selectedIndex,
                    onSelectedIndexChange = { index ->
                        setSelectedIndexInternal(index, notify = true)
                    },
                    options = segmentLabels,
                    enabled = frostEnabled,
                    clickSoundEnabled = clickSoundEnabled,
                    appearance = appearance,
                )
            }
        }
    }

    private var externalListener: RadioGroup.OnCheckedChangeListener? = null

    override fun onFinishInflate() {
        super.onFinishInflate()
        val buttons = mutableListOf<RadioButton>()
        val remove = mutableListOf<View>()
        for (i in 0 until childCount) {
            val child = getChildAt(i)
            if (child is RadioButton && child !== composeView && child.parent === this) {
                buttons.add(child)
                remove.add(child)
            }
        }
        remove.forEach { removeView(it) }
        buttons.forEach { button ->
            button.visibility = GONE
            button.isClickable = false
            button.isFocusable = false
            radioGroup.addView(
                button,
                RadioGroup.LayoutParams(0, 0),
            )
        }
        segmentLabels = buttons.map { it.text?.toString().orEmpty() }
        segmentIds = buttons.map { it.id }
        val checkedIndex = buttons.indexOfFirst { it.isChecked }
        selectedIndex = if (checkedIndex >= 0) checkedIndex else 0
    }

    fun check(id: Int) {
        val index = segmentIds.indexOf(id)
        if (index < 0) return
        suppressListener = true
        selectedIndex = index
        radioGroup.check(id)
        suppressListener = false
    }

    fun getCheckedRadioButtonId(): Int = radioGroup.checkedRadioButtonId

    fun setOnCheckedChangeListener(listener: RadioGroup.OnCheckedChangeListener?) {
        externalListener = listener
    }

    fun applySelectedIndex(index: Int) {
        setSelectedIndexInternal(index, notify = false)
    }

    fun setSuppressListener(suppress: Boolean) {
        suppressListener = suppress
    }

    override fun setEnabled(enabled: Boolean) {
        super.setEnabled(enabled)
        frostEnabled = enabled
        radioGroup.isEnabled = enabled
    }

    private fun setSelectedIndexInternal(index: Int, notify: Boolean) {
        if (index !in segmentIds.indices) return
        selectedIndex = index
        suppressListener = true
        radioGroup.check(segmentIds[index])
        suppressListener = false
        if (notify) {
            externalListener?.onCheckedChanged(radioGroup, segmentIds[index])
        }
    }
}
