package com.lasercyber.lws.frostui.control.interop

import android.content.Context
import android.util.AttributeSet
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.TextView
import androidx.core.content.ContextCompat
import com.lasercyber.lws.ui.R

/**
 * Horizontal [FrostSliderView] with start/end value labels (e.g. playback position and duration).
 * Replaces legacy FlankedSeekBar + ScaledSeekBar playback row.
 */
class FrostFlankedSliderView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
) : LinearLayout(context, attrs, defStyleAttr) {

    private val startLabel: TextView
    private val slider: FrostSliderView
    private val endLabel: TextView

    init {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL

        val typedArray = context.obtainStyledAttributes(
            attrs,
            R.styleable.FrostFlankedSlider,
            defStyleAttr,
            0,
        )
        val startLabelText = typedArray.getString(R.styleable.FrostFlankedSlider_frostFlankStartLabelText)
        val endLabelText = typedArray.getString(R.styleable.FrostFlankedSlider_frostFlankEndLabelText)
        val startLabelId = typedArray.getResourceId(
            R.styleable.FrostFlankedSlider_frostFlankStartLabelId,
            View.NO_ID,
        )
        val endLabelId = typedArray.getResourceId(
            R.styleable.FrostFlankedSlider_frostFlankEndLabelId,
            View.NO_ID,
        )
        val labelSpacingPx = typedArray.getDimensionPixelSize(
            R.styleable.FrostFlankedSlider_frostFlankLabelSpacing,
            resources.getDimensionPixelSize(R.dimen.scaled_seekbar_flank_label_spacing),
        )
        val min = typedArray.getInt(R.styleable.FrostFlankedSlider_android_min, 0)
        val max = typedArray.getInt(R.styleable.FrostFlankedSlider_android_max, 100)
        val progress = typedArray.getInt(R.styleable.FrostFlankedSlider_android_progress, min)
        val longPressDragEnabled = typedArray.getBoolean(
            R.styleable.FrostFlankedSlider_frostLongPressDragEnabled,
            true,
        )
        typedArray.recycle()

        val labelTextSizePx = resources.getDimension(R.dimen.frost_slider_label_text_size)
        val labelColor = ContextCompat.getColor(context, R.color.frost_control_slider_label)

        startLabel = TextView(context).apply {
            if (startLabelId != View.NO_ID) id = startLabelId
            setTextColor(labelColor)
            setTextSize(TypedValue.COMPLEX_UNIT_PX, labelTextSizePx)
            if (startLabelText != null) text = startLabelText
        }

        endLabel = TextView(context).apply {
            if (endLabelId != View.NO_ID) id = endLabelId
            setTextColor(labelColor)
            setTextSize(TypedValue.COMPLEX_UNIT_PX, labelTextSizePx)
            if (endLabelText != null) text = endLabelText
        }

        slider = FrostSliderView(context).apply {
            setMin(min)
            setMax(max)
            setProgress(progress.coerceIn(min, max))
            setLongPressDragEnabled(longPressDragEnabled)
        }

        addView(startLabel, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT))
        addView(
            slider,
            LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f).apply {
                marginStart = labelSpacingPx
                marginEnd = labelSpacingPx
            },
        )
        addView(endLabel, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT))
    }

    fun getSlider(): FrostSliderView = slider

    fun getStartLabel(): TextView = startLabel

    fun getEndLabel(): TextView = endLabel

    fun setStartLabelText(text: CharSequence?) {
        startLabel.text = text
    }

    fun setEndLabelText(text: CharSequence?) {
        endLabel.text = text
    }

    fun getProgress(): Int = slider.getProgress()

    fun setProgress(progress: Int) {
        slider.setProgress(progress)
    }

    fun getMax(): Int = slider.getMax()

    fun setMax(max: Int) {
        slider.setMax(max)
    }

    fun setOnSeekBarChangeListener(listener: SeekBar.OnSeekBarChangeListener?) {
        slider.setOnSeekBarChangeListener(listener)
    }

    override fun setEnabled(enabled: Boolean) {
        super.setEnabled(enabled)
        startLabel.isEnabled = enabled
        slider.isEnabled = enabled
        endLabel.isEnabled = enabled
    }
}
