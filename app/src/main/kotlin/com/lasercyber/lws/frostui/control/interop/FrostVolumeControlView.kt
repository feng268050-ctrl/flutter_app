package com.lasercyber.lws.frostui.control.interop

import android.content.Context
import android.util.AttributeSet
import android.widget.SeekBar
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.AbstractComposeView
import androidx.compose.ui.res.dimensionResource
import androidx.compose.ui.unit.dp
import androidx.databinding.BindingAdapter
import com.lasercyber.lws.frostui.control.FrostIconFlankedSlider
import com.lasercyber.lws.frostui.control.FrostVolumeControlDefaults
import com.lasercyber.lws.ui.R

/** XML/Java bridge embedding [FrostIconFlankedSlider] for system media volume (0–100%). */
class FrostVolumeControlView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
) : AbstractComposeView(context, attrs, defStyleAttr) {

    init {
        clipChildren = false
        clipToPadding = false
    }

    private val typedArray = context.obtainStyledAttributes(attrs, R.styleable.FrostVolumeControl, defStyleAttr, 0)
    private var minValue by mutableIntStateOf(
        typedArray.getInt(R.styleable.FrostVolumeControl_android_min, FrostVolumeControlDefaults.MIN_PERCENT),
    )
    private var maxValue by mutableIntStateOf(
        typedArray.getInt(R.styleable.FrostVolumeControl_android_max, FrostVolumeControlDefaults.MAX_PERCENT),
    )
    private var progressValue by mutableIntStateOf(
        typedArray.getInt(R.styleable.FrostVolumeControl_android_progress, minValue).coerceIn(minValue, maxValue),
    )
    private var contentPaddingDp by mutableStateOf(
        if (typedArray.hasValue(R.styleable.FrostVolumeControl_frostContentPadding)) {
            typedArray.getDimension(R.styleable.FrostVolumeControl_frostContentPadding, 0f).dp
        } else {
            0.dp
        },
    )
    private var reserveThumbOverflow by mutableStateOf(
        typedArray.getBoolean(
            R.styleable.FrostVolumeControl_frostReserveThumbOverflow,
            true,
        ),
    )
    private var frostEnabled by mutableStateOf(true)
    private var userTracking by mutableStateOf(false)
    private var dragProgress by mutableIntStateOf(progressValue)
    private var seekBarChangeListener: SeekBar.OnSeekBarChangeListener? = null

    init {
        typedArray.recycle()
    }

    fun getMin(): Int = minValue

    fun getMax(): Int = maxValue

    fun getProgress(): Int = progressValue

    fun setProgress(progress: Int) {
        if (userTracking) {
            return
        }
        val clamped = progress.coerceIn(minValue, maxValue)
        if (progressValue != clamped) {
            progressValue = clamped
        }
    }

    fun setOnSeekBarChangeListener(listener: SeekBar.OnSeekBarChangeListener?) {
        seekBarChangeListener = listener
    }

    override fun setEnabled(enabled: Boolean) {
        super.setEnabled(enabled)
        frostEnabled = enabled
    }

    @Composable
    override fun Content() {
        FrostIconFlankedSlider(
            progress = progressValue,
            onProgressChange = { value, fromUser ->
                if (fromUser) {
                    dragProgress = value
                    seekBarChangeListener?.onProgressChanged(seekBarShim, value, false)
                } else if (!userTracking && progressValue != value) {
                    progressValue = value
                }
            },
            modifier = Modifier
                .fillMaxWidth()
                .padding(contentPaddingDp),
            enabled = frostEnabled,
            min = minValue,
            max = maxValue,
            leadingIconRes = FrostVolumeControlDefaults.LEADING_ICON_RES,
            trailingIconRes = FrostVolumeControlDefaults.TRAILING_ICON_RES,
            leadingIconGap = dimensionResource(R.dimen.frost_volume_control_leading_icon_spacing),
            longPressDragEnabled = true,
            reserveThumbOverflow = reserveThumbOverflow,
            onStartTracking = {
                userTracking = true
                dragProgress = progressValue
                seekBarChangeListener?.onStartTrackingTouch(seekBarShim)
            },
            onStopTracking = { cancelled ->
                userTracking = false
                if (!cancelled) {
                    if (progressValue != dragProgress) {
                        progressValue = dragProgress
                    }
                    seekBarChangeListener?.onProgressChanged(seekBarShim, dragProgress, true)
                } else {
                    seekBarChangeListener?.onProgressChanged(seekBarShim, progressValue, false)
                }
                seekBarChangeListener?.onStopTrackingTouch(seekBarShim)
            },
        )
    }

    private val seekBarShim: SeekBar by lazy(LazyThreadSafetyMode.NONE) {
        object : SeekBar(context) {
            override fun getProgress(): Int = progressValue
            override fun getMax(): Int = maxValue
            override fun getMin(): Int = minValue
        }
    }

    companion object {
        @JvmStatic
        @BindingAdapter("android:progress")
        fun setProgressBinding(view: FrostVolumeControlView, progress: Int) {
            view.setProgress(progress)
        }
    }
}
