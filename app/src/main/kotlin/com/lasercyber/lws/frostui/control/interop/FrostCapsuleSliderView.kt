package com.lasercyber.lws.frostui.control.interop

import android.content.Context
import android.graphics.drawable.Drawable
import android.util.AttributeSet
import android.widget.SeekBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.AbstractComposeView
import androidx.compose.ui.res.painterResource
import androidx.core.content.ContextCompat
import androidx.databinding.BindingAdapter
import com.lasercyber.lws.frostui.control.FrostCapsuleSlider
import com.lasercyber.lws.ui.R

/** XML/Java bridge embedding [FrostCapsuleSlider] for common-settings brightness row. */
class FrostCapsuleSliderView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = R.attr.frostCapsuleSliderStyle,
) : AbstractComposeView(context, attrs, defStyleAttr) {

    private val initial = FrostControlAttrs.readCapsuleSlider(context, attrs, defStyleAttr)
    private var minValue by mutableIntStateOf(initial.min)
    private var maxValue by mutableIntStateOf(initial.max)
    private var progressValue by mutableIntStateOf(initial.progress)
    private var appearance by mutableStateOf(initial.appearance)
    private var trailingIconRes by mutableIntStateOf(initial.trailingIconRes)
    private var frostEnabled by mutableStateOf(true)
    private var userTracking by mutableStateOf(false)
    private var dragProgress by mutableIntStateOf(initial.progress)
    private var seekBarChangeListener: SeekBar.OnSeekBarChangeListener? = null

    fun getMin(): Int = minValue

    fun getMax(): Int = maxValue

    fun getProgress(): Int = progressValue

    fun setProgress(progress: Int) {
        if (userTracking) return
        val clamped = progress.coerceIn(minValue, maxValue)
        if (progressValue != clamped) {
            progressValue = clamped
        }
    }

    fun setOnSeekBarChangeListener(listener: SeekBar.OnSeekBarChangeListener?) {
        seekBarChangeListener = listener
    }

    fun setTrailingIcon(drawable: Drawable?) {
        trailingIconRes = 0
        // Drawable instances are not wired yet; brightness row uses XML resource.
    }

    override fun setEnabled(enabled: Boolean) {
        super.setEnabled(enabled)
        frostEnabled = enabled
    }

    @Composable
    override fun Content() {
        val trailingPainter = if (trailingIconRes != 0) {
            painterResource(trailingIconRes)
        } else {
            null
        }
        FrostCapsuleSlider(
            progress = progressValue,
            onProgressChange = { value, fromUser ->
                if (fromUser) {
                    dragProgress = value
                    seekBarChangeListener?.onProgressChanged(seekBarShim, value, true)
                } else if (!userTracking && progressValue != value) {
                    progressValue = value
                }
            },
            enabled = frostEnabled,
            min = minValue,
            max = maxValue,
            appearance = appearance,
            trailingIcon = trailingPainter,
            onStartTracking = {
                userTracking = true
                dragProgress = progressValue
                seekBarChangeListener?.onStartTrackingTouch(seekBarShim)
            },
            onStopTracking = { cancelled ->
                userTracking = false
                if (!cancelled && progressValue != dragProgress) {
                    progressValue = dragProgress
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
        fun setProgressBinding(view: FrostCapsuleSliderView, progress: Int) {
            view.setProgress(progress)
        }
    }
}
