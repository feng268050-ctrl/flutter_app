package com.lasercyber.lws.frostui.control.interop

import android.content.Context
import android.util.AttributeSet
import android.widget.SeekBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.AbstractComposeView
import androidx.databinding.BindingAdapter
import com.lasercyber.lws.frostui.control.FrostSlider
import com.lasercyber.lws.ui.R

/** XML/Java bridge embedding [FrostSlider].
 *
 * When [longPressDragEnabled] is true (default), progress is previewed during drag via
 * [SeekBar.OnSeekBarChangeListener.onProgressChanged] with `fromUser=false`; the committed
 * value is delivered once on release with `fromUser=true`. Direct-drag mode emits
 * `fromUser=true` continuously while dragging.
 */
class FrostSliderView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = R.attr.frostSliderStyle,
) : AbstractComposeView(context, attrs, defStyleAttr) {

    init {
        clipChildren = false
        clipToPadding = false
    }

    private val initial = FrostControlAttrs.readSlider(context, attrs, defStyleAttr)
    private var minValue by mutableIntStateOf(initial.min)
    private var maxValue by mutableIntStateOf(initial.max)
    private var progressValue by mutableIntStateOf(initial.progress)
    private var scaleMinText by mutableStateOf(initial.scaleMinText)
    private var scaleMaxText by mutableStateOf(initial.scaleMaxText)
    private var scaleZeroText by mutableStateOf(initial.scaleZeroText)
    private var appearance by mutableStateOf(initial.appearance)
    private var usesLongPressDrag by mutableStateOf(initial.longPressDragEnabled)
    private var reserveThumbOverflow by mutableStateOf(initial.reserveThumbOverflow)
    private var frostEnabled by mutableStateOf(true)
    private var userTracking by mutableStateOf(false)
    private var dragProgress by mutableIntStateOf(initial.progress)
    private var seekBarChangeListener: SeekBar.OnSeekBarChangeListener? = null

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

    fun setMin(min: Int) {
        if (minValue == min) return
        minValue = min
        progressValue = progressValue.coerceIn(minValue, maxValue)
    }

    fun setMax(max: Int) {
        if (maxValue == max) return
        maxValue = max
        progressValue = progressValue.coerceIn(minValue, maxValue)
    }

    fun setOnSeekBarChangeListener(listener: SeekBar.OnSeekBarChangeListener?) {
        seekBarChangeListener = listener
    }

    fun setScaleMinText(text: CharSequence?) {
        scaleMinText = text?.toString()
    }

    fun setScaleMaxText(text: CharSequence?) {
        scaleMaxText = text?.toString()
    }

    fun setScaleZeroText(text: CharSequence?) {
        scaleZeroText = text?.toString() ?: "0"
    }

    fun setLongPressDragEnabled(enabled: Boolean) {
        if (usesLongPressDrag == enabled) return
        usesLongPressDrag = enabled
    }

    override fun setEnabled(enabled: Boolean) {
        super.setEnabled(enabled)
        frostEnabled = enabled
    }

    @Composable
    override fun Content() {
        FrostSlider(
            progress = progressValue,
            onProgressChange = { value, fromUser ->
                if (fromUser) {
                    dragProgress = value
                    if (usesLongPressDrag) {
                        seekBarChangeListener?.onProgressChanged(seekBarShim, value, false)
                    } else {
                        seekBarChangeListener?.onProgressChanged(seekBarShim, value, true)
                    }
                } else if (!userTracking && progressValue != value) {
                    progressValue = value
                }
            },
            enabled = frostEnabled,
            min = minValue,
            max = maxValue,
            scaleMinText = scaleMinText,
            scaleMaxText = scaleMaxText,
            scaleZeroText = scaleZeroText,
            appearance = appearance,
            longPressDragEnabled = usesLongPressDrag,
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
                    if (usesLongPressDrag) {
                        seekBarChangeListener?.onProgressChanged(seekBarShim, dragProgress, true)
                    }
                } else if (usesLongPressDrag) {
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
        fun setProgressBinding(view: FrostSliderView, progress: Int) {
            view.setProgress(progress)
        }
    }
}
