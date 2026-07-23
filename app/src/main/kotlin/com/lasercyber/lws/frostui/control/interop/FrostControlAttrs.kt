package com.lasercyber.lws.frostui.control.interop

import android.content.Context
import android.util.AttributeSet
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.lasercyber.lws.frostui.control.FrostCapsuleSliderAppearance
import com.lasercyber.lws.frostui.control.FrostCheckboxAppearance
import com.lasercyber.lws.frostui.control.FrostControlColors
import com.lasercyber.lws.frostui.control.FrostControlDefaults
import com.lasercyber.lws.frostui.control.FrostControlDimens
import com.lasercyber.lws.frostui.control.FrostNumericStepperAppearance
import com.lasercyber.lws.frostui.control.FrostNumericStepperDefaults
import com.lasercyber.lws.frostui.control.FrostSegmentedAppearance
import com.lasercyber.lws.frostui.control.FrostSliderAppearance
import com.lasercyber.lws.frostui.control.FrostStatusIndicatorAppearance
import com.lasercyber.lws.frostui.control.FrostStatusState
import com.lasercyber.lws.frostui.control.FrostStatusVariant
import com.lasercyber.lws.frostui.control.FrostSwitchAppearance
import com.lasercyber.lws.frostui.control.pxToDp
import com.lasercyber.lws.frostui.control.pxToSp
import com.lasercyber.lws.ui.R

internal data class FrostSwitchAttrs(
    val checked: Boolean = false,
    val appearance: FrostSwitchAppearance,
)

internal data class FrostCheckboxAttrs(
    val checked: Boolean = false,
    val labelText: String? = null,
    val appearance: FrostCheckboxAppearance,
)

internal data class FrostSliderAttrs(
    val min: Int = 0,
    val max: Int = 100,
    val progress: Int = 0,
    val scaleMinText: String? = null,
    val scaleMaxText: String? = null,
    val scaleZeroText: String = "0",
    val appearance: FrostSliderAppearance,
    val longPressDragEnabled: Boolean = true,
    val reserveThumbOverflow: Boolean = true,
)

internal data class FrostSegmentedAttrs(
    val appearance: FrostSegmentedAppearance,
    val clickSoundEnabled: Boolean = true,
)

internal data class FrostCapsuleSliderAttrs(
    val min: Int = 0,
    val max: Int = 100,
    val progress: Int = 0,
    val trailingIconRes: Int = 0,
    val appearance: FrostCapsuleSliderAppearance,
)

internal data class FrostNumericStepperAttrs(
    val appearance: FrostNumericStepperAppearance,
)

internal data class FrostStatusIndicatorAttrs(
    val state: FrostStatusState,
    val variant: FrostStatusVariant,
    val appearance: FrostStatusIndicatorAppearance,
)

internal object FrostControlAttrs {
    fun readSwitch(
        context: Context,
        attrs: AttributeSet?,
        defStyleAttr: Int = R.attr.frostSwitchStyle,
        defStyleRes: Int = R.style.FrostSwitch,
    ): FrostSwitchAttrs {
        val typedArray = context.obtainStyledAttributes(
            attrs,
            R.styleable.FrostSwitch,
            defStyleAttr,
            defStyleRes,
        )
        return try {
            val appearance = FrostSwitchAppearance(
                trackOffColor = typedArray.getColor(
                    R.styleable.FrostSwitch_frostSwitchTrackOffColor,
                    ContextCompat.getColor(context, R.color.frost_control_switch_track_off),
                ).toComposeColor(),
                trackOnColor = typedArray.getColor(
                    R.styleable.FrostSwitch_frostSwitchTrackOnColor,
                    ContextCompat.getColor(context, R.color.frost_control_switch_track_on),
                ).toComposeColor(),
                thumbColor = typedArray.getColor(
                    R.styleable.FrostSwitch_frostSwitchThumbColor,
                    ContextCompat.getColor(context, R.color.frost_control_switch_thumb),
                ).toComposeColor(),
                trackWidth = context.pxToDp(
                    typedArray.getDimension(
                        R.styleable.FrostSwitch_frostSwitchTrackWidth,
                        context.resources.getDimension(R.dimen.frost_switch_track_width),
                    ),
                ),
                trackHeight = context.pxToDp(
                    typedArray.getDimension(
                        R.styleable.FrostSwitch_frostSwitchTrackHeight,
                        context.resources.getDimension(R.dimen.frost_switch_track_height),
                    ),
                ),
                trackCornerRadius = context.pxToDp(
                    typedArray.getDimension(
                        R.styleable.FrostSwitch_frostSwitchTrackCornerRadius,
                        context.resources.getDimension(R.dimen.frost_switch_track_corner_radius),
                    ),
                ),
                thumbSize = context.pxToDp(
                    typedArray.getDimension(
                        R.styleable.FrostSwitch_frostSwitchThumbSize,
                        context.resources.getDimension(R.dimen.frost_switch_thumb_size),
                    ),
                ),
                thumbInsetVertical = context.pxToDp(
                    typedArray.getDimension(
                        R.styleable.FrostSwitch_frostSwitchThumbInsetVertical,
                        context.resources.getDimension(R.dimen.frost_switch_thumb_inset_vertical),
                    ),
                ),
                animationDurationMs = typedArray.getInt(
                    R.styleable.FrostSwitch_frostSwitchAnimationDuration,
                    200,
                ),
            )
            FrostSwitchAttrs(
                checked = typedArray.getBoolean(R.styleable.FrostSwitch_android_checked, false),
                appearance = appearance,
            )
        } finally {
            typedArray.recycle()
        }
    }

    fun readCheckbox(
        context: Context,
        attrs: AttributeSet?,
        defStyleAttr: Int = R.attr.frostCheckboxStyle,
        defStyleRes: Int = R.style.FrostCheckbox,
    ): FrostCheckboxAttrs {
        val typedArray = context.obtainStyledAttributes(
            attrs,
            R.styleable.FrostCheckbox,
            defStyleAttr,
            defStyleRes,
        )
        return try {
            val labelSizePx = typedArray.getDimension(
                R.styleable.FrostCheckbox_labelTextSize,
                typedArray.getDimension(
                    R.styleable.FrostCheckbox_frostCheckboxLabelTextSize,
                    spToPx(context, 24f),
                ),
            )
            val labelSpacingPx = typedArray.getDimension(
                R.styleable.FrostCheckbox_labelSpacing,
                typedArray.getDimension(
                    R.styleable.FrostCheckbox_frostCheckboxLabelSpacing,
                    context.resources.getDimension(R.dimen.frost_checkbox_label_spacing),
                ),
            )
            val appearance = FrostCheckboxAppearance(
                checkedFillColor = typedArray.getColor(
                    R.styleable.FrostCheckbox_frostCheckboxCheckedFillColor,
                    ContextCompat.getColor(context, R.color.frost_control_checkbox_fill),
                ).toComposeColor(),
                uncheckedStrokeColor = typedArray.getColor(
                    R.styleable.FrostCheckbox_frostCheckboxUncheckedStrokeColor,
                    ContextCompat.getColor(context, R.color.frost_control_checkbox_stroke),
                ).toComposeColor(),
                checkmarkColor = typedArray.getColor(
                    R.styleable.FrostCheckbox_frostCheckboxCheckmarkColor,
                    ContextCompat.getColor(context, R.color.frost_control_checkbox_checkmark),
                ).toComposeColor(),
                boxSize = context.pxToDp(
                    typedArray.getDimension(
                        R.styleable.FrostCheckbox_frostCheckboxSize,
                        context.resources.getDimension(R.dimen.frost_checkbox_size),
                    ),
                ),
                strokeWidth = context.pxToDp(
                    typedArray.getDimension(
                        R.styleable.FrostCheckbox_frostCheckboxStrokeWidth,
                        context.resources.getDimension(R.dimen.frost_checkbox_stroke_width),
                    ),
                ),
                labelSpacing = context.pxToDp(labelSpacingPx),
                labelColor = typedArray.getColor(
                    R.styleable.FrostCheckbox_labelTextColor,
                    typedArray.getColor(
                        R.styleable.FrostCheckbox_frostCheckboxLabelTextColor,
                        ContextCompat.getColor(context, R.color.frost_control_checkbox_label),
                    ),
                ).toComposeColor(),
                labelSize = context.pxToSp(labelSizePx),
                animationDurationMs = typedArray.getInt(
                    R.styleable.FrostCheckbox_frostCheckboxAnimationDuration,
                    200,
                ),
            )
            FrostCheckboxAttrs(
                checked = typedArray.getBoolean(R.styleable.FrostCheckbox_android_checked, false),
                labelText = typedArray.getText(R.styleable.FrostCheckbox_labelText)?.toString(),
                appearance = appearance,
            )
        } finally {
            typedArray.recycle()
        }
    }

    fun readSlider(
        context: Context,
        attrs: AttributeSet?,
        defStyleAttr: Int = R.attr.frostSliderStyle,
        defStyleRes: Int = R.style.FrostSlider,
    ): FrostSliderAttrs {
        val typedArray = context.obtainStyledAttributes(
            attrs,
            R.styleable.FrostSlider,
            defStyleAttr,
            defStyleRes,
        )
        return try {
            val min = typedArray.getInt(R.styleable.FrostSlider_android_min, 0)
            val max = typedArray.getInt(R.styleable.FrostSlider_android_max, 100)
            val progress = typedArray.getInt(R.styleable.FrostSlider_android_progress, min)
            val appearance = FrostSliderAppearance(
                trackInactiveColor = FrostControlColors.sliderTrackInactive(context),
                trackActiveColor = FrostControlColors.sliderTrackActive(context),
                thumbColor = FrostControlColors.sliderThumb(context),
                labelColor = FrostControlColors.sliderLabel(context),
                labelSize = FrostControlDimens.sliderLabelTextSize(context),
                thumbSize = FrostControlDimens.sliderThumbSize(context),
                trackHeight = FrostControlDimens.sliderTrackHeight(context),
                trackCornerRadius = FrostControlDimens.sliderTrackCornerRadius(context),
                touchHeight = FrostControlDimens.sliderTouchHeight(context),
            )
            FrostSliderAttrs(
                min = min,
                max = max,
                progress = progress.coerceIn(min, max),
                scaleMinText = typedArray.getString(R.styleable.FrostSlider_frostScaleMinText),
                scaleMaxText = typedArray.getString(R.styleable.FrostSlider_frostScaleMaxText),
                scaleZeroText = typedArray.getString(R.styleable.FrostSlider_frostScaleZeroText) ?: "0",
                appearance = appearance,
                longPressDragEnabled = typedArray.getBoolean(
                    R.styleable.FrostSlider_frostLongPressDragEnabled,
                    true,
                ),
                reserveThumbOverflow = typedArray.getBoolean(
                    R.styleable.FrostSlider_frostReserveThumbOverflow,
                    true,
                ),
            )
        } finally {
            typedArray.recycle()
        }
    }

    fun readSegmented(
        context: Context,
        attrs: AttributeSet?,
        defStyleAttr: Int = R.attr.frostSegmentedControlStyle,
        defStyleRes: Int = R.style.FrostSegmentedControl,
    ): FrostSegmentedAttrs {
        val typedArray = context.obtainStyledAttributes(
            attrs,
            R.styleable.FrostSegmentedControl,
            defStyleAttr,
            defStyleRes,
        )
        return try {
            val textSizePx = typedArray.getDimension(
                R.styleable.FrostSegmentedControl_frostSegmentTextSize,
                context.resources.getDimension(R.dimen.frost_segment_text_size_large),
            )
            val appearance = FrostSegmentedAppearance(
                capsuleFillColor = typedArray.getColor(
                    R.styleable.FrostSegmentedControl_frostCapsuleFillColor,
                    ContextCompat.getColor(context, R.color.frost_control_capsule_fill),
                ).toComposeColor(),
                capsuleBorderColor = typedArray.getColor(
                    R.styleable.FrostSegmentedControl_frostCapsuleBorderColor,
                    ContextCompat.getColor(context, R.color.frost_control_capsule_border),
                ).toComposeColor(),
                capsuleCornerRadius = context.pxToDp(
                    typedArray.getDimension(
                        R.styleable.FrostSegmentedControl_frostCapsuleCornerRadius,
                        context.resources.getDimension(R.dimen.frost_capsule_outer_corner_radius),
                    ),
                ),
                capsuleInset = context.pxToDp(
                    typedArray.getDimension(
                        R.styleable.FrostSegmentedControl_frostCapsuleInset,
                        context.resources.getDimension(R.dimen.frost_capsule_inset),
                    ),
                ),
                capsuleBorderWidth = context.pxToDp(
                    context.resources.getDimension(R.dimen.frost_capsule_border_width),
                ),
                segmentSelectedFillColor = typedArray.getColor(
                    R.styleable.FrostSegmentedControl_frostSegmentSelectedFillColor,
                    ContextCompat.getColor(context, R.color.frost_control_segment_selected_fill),
                ).toComposeColor(),
                segmentUnselectedFillColor = typedArray.getColor(
                    R.styleable.FrostSegmentedControl_frostSegmentUnselectedFillColor,
                    ContextCompat.getColor(context, R.color.frost_control_segment_unselected_fill),
                ).toComposeColor(),
                segmentSelectedTextColor = typedArray.getColor(
                    R.styleable.FrostSegmentedControl_frostSegmentSelectedTextColor,
                    ContextCompat.getColor(context, R.color.frost_control_segment_selected_text),
                ).toComposeColor(),
                segmentUnselectedTextColor = typedArray.getColor(
                    R.styleable.FrostSegmentedControl_frostSegmentUnselectedTextColor,
                    ContextCompat.getColor(context, R.color.frost_control_segment_unselected_text),
                ).toComposeColor(),
                segmentTextSize = context.pxToSp(textSizePx),
                crossfadeDurationMs = typedArray.getInt(
                    R.styleable.FrostSegmentedControl_frostSegmentCrossfadeDuration,
                    FrostControlDefaults.SEGMENT_CROSSFADE_DURATION_MS,
                ),
            )
            val clickSoundEnabled = typedArray.getBoolean(
                R.styleable.FrostSegmentedControl_frostClickSoundEnabled,
                true,
            )
            FrostSegmentedAttrs(appearance = appearance, clickSoundEnabled = clickSoundEnabled)
        } finally {
            typedArray.recycle()
        }
    }

    fun readCapsuleSlider(
        context: Context,
        attrs: AttributeSet?,
        defStyleAttr: Int = R.attr.frostCapsuleSliderStyle,
        defStyleRes: Int = R.style.FrostCapsuleSlider,
    ): FrostCapsuleSliderAttrs {
        val typedArray = context.obtainStyledAttributes(
            attrs,
            R.styleable.FrostCapsuleSlider,
            defStyleAttr,
            defStyleRes,
        )
        return try {
            val min = typedArray.getInt(R.styleable.FrostCapsuleSlider_android_min, 0)
            val max = typedArray.getInt(R.styleable.FrostCapsuleSlider_android_max, 100)
            val progress = typedArray.getInt(R.styleable.FrostCapsuleSlider_android_progress, min)
            val valueSuffix = typedArray.getString(R.styleable.FrostCapsuleSlider_frostCapsuleValueSuffix) ?: "%"
            val appearance = FrostCapsuleSliderAppearance(
                capsuleFillColor = typedArray.getColor(
                    R.styleable.FrostCapsuleSlider_frostCapsuleFillColor,
                    ContextCompat.getColor(context, R.color.frost_control_capsule_fill),
                ).toComposeColor(),
                capsuleBorderColor = typedArray.getColor(
                    R.styleable.FrostCapsuleSlider_frostCapsuleBorderColor,
                    ContextCompat.getColor(context, R.color.frost_control_capsule_border),
                ).toComposeColor(),
                capsuleCornerRadius = context.pxToDp(
                    typedArray.getDimension(
                        R.styleable.FrostCapsuleSlider_frostCapsuleCornerRadius,
                        context.resources.getDimension(R.dimen.frost_capsule_outer_corner_radius),
                    ),
                ),
                capsuleInset = context.pxToDp(
                    typedArray.getDimension(
                        R.styleable.FrostCapsuleSlider_frostCapsuleInset,
                        context.resources.getDimension(R.dimen.frost_capsule_inset),
                    ),
                ),
                capsuleBorderWidth = context.pxToDp(
                    context.resources.getDimension(R.dimen.frost_capsule_border_width),
                ),
                trackInactiveColor = typedArray.getColor(
                    R.styleable.FrostCapsuleSlider_frostCapsuleSliderTrackInactiveColor,
                    ContextCompat.getColor(context, R.color.frost_control_capsule_slider_track_inactive),
                ).toComposeColor(),
                trackActiveColor = typedArray.getColor(
                    R.styleable.FrostCapsuleSlider_frostCapsuleSliderTrackActiveColor,
                    ContextCompat.getColor(context, R.color.frost_control_capsule_slider_track_active),
                ).toComposeColor(),
                overlayLightColor = typedArray.getColor(
                    R.styleable.FrostCapsuleSlider_frostCapsuleSliderOverlayLightColor,
                    ContextCompat.getColor(context, R.color.frost_control_capsule_slider_overlay_light),
                ).toComposeColor(),
                overlayDarkColor = typedArray.getColor(
                    R.styleable.FrostCapsuleSlider_frostCapsuleSliderOverlayDarkColor,
                    ContextCompat.getColor(context, R.color.frost_control_capsule_slider_overlay_dark),
                ).toComposeColor(),
                sliderHeight = context.pxToDp(
                    typedArray.getDimension(
                        R.styleable.FrostCapsuleSlider_frostCapsuleSliderHeight,
                        context.resources.getDimension(R.dimen.frost_capsule_slider_height),
                    ),
                ),
                sliderCornerRadius = context.pxToDp(
                    typedArray.getDimension(
                        R.styleable.FrostCapsuleSlider_frostCapsuleSliderCornerRadius,
                        context.resources.getDimension(R.dimen.frost_capsule_slider_corner_radius),
                    ),
                ),
                valueTextSize = context.pxToSp(
                    typedArray.getDimension(
                        R.styleable.FrostCapsuleSlider_frostCapsuleSliderValueTextSize,
                        context.resources.getDimension(R.dimen.frost_capsule_slider_value_text_size),
                    ),
                ),
                trailingIconSize = context.pxToDp(
                    typedArray.getDimension(
                        R.styleable.FrostCapsuleSlider_frostCapsuleSliderTrailingIconSize,
                        context.resources.getDimension(R.dimen.frost_capsule_slider_trailing_icon_size),
                    ),
                ),
                valuePaddingHorizontal = context.pxToDp(
                    context.resources.getDimension(R.dimen.frost_capsule_slider_value_padding_horizontal),
                ),
                valueSuffix = valueSuffix,
            )
            FrostCapsuleSliderAttrs(
                min = min,
                max = max,
                progress = progress.coerceIn(min, max),
                trailingIconRes = typedArray.getResourceId(
                    R.styleable.FrostCapsuleSlider_frostCapsuleTrailingIcon,
                    0,
                ),
                appearance = appearance,
            )
        } finally {
            typedArray.recycle()
        }
    }

    fun readNumericStepper(
        context: Context,
        attrs: AttributeSet?,
        defStyleAttr: Int = R.attr.frostNumericStepperStyle,
        defStyleRes: Int = R.style.FrostNumericStepper,
    ): FrostNumericStepperAttrs {
        val defaults = FrostNumericStepperDefaults.appearance(context)
        val typedArray = context.obtainStyledAttributes(
            attrs,
            R.styleable.FrostNumericStepper,
            defStyleAttr,
            defStyleRes,
        )
        return try {
            val appearance = defaults.copy(
                descriptionTextColor = typedArray.getColor(
                    R.styleable.FrostNumericStepper_frostStepperDescriptionTextColor,
                    defaults.descriptionTextColor.toArgb(),
                ).toComposeColor(),
                descriptionTextSize = context.pxToSp(
                    typedArray.getDimension(
                        R.styleable.FrostNumericStepper_frostStepperDescriptionTextSize,
                        spToPx(context, defaults.descriptionTextSize.value),
                    ),
                ),
                stepButtonSize = context.pxToDp(
                    typedArray.getDimension(
                        R.styleable.FrostNumericStepper_frostStepperStepButtonSize,
                        with(defaults.stepButtonSize) { value * context.resources.displayMetrics.density },
                    ),
                ),
                stepButtonTextSize = context.pxToSp(
                    typedArray.getDimension(
                        R.styleable.FrostNumericStepper_frostStepperStepButtonTextSize,
                        spToPx(context, defaults.stepButtonTextSize.value),
                    ),
                ),
                stepButtonTextColor = typedArray.getColor(
                    R.styleable.FrostNumericStepper_frostStepperStepButtonTextColor,
                    defaults.stepButtonTextColor.toArgb(),
                ).toComposeColor(),
                fieldWidth = context.pxToDp(
                    typedArray.getDimension(
                        R.styleable.FrostNumericStepper_frostStepperFieldWidth,
                        defaults.fieldWidth.value * context.resources.displayMetrics.density,
                    ),
                ),
                fieldMinHeight = context.pxToDp(
                    typedArray.getDimension(
                        R.styleable.FrostNumericStepper_frostStepperFieldMinHeight,
                        defaults.fieldMinHeight.value * context.resources.displayMetrics.density,
                    ),
                ),
                fieldTextSize = context.pxToSp(
                    typedArray.getDimension(
                        R.styleable.FrostNumericStepper_frostStepperFieldTextSize,
                        spToPx(context, defaults.fieldTextSize.value),
                    ),
                ),
                horizontalPadding = context.pxToDp(
                    typedArray.getDimension(
                        R.styleable.FrostNumericStepper_frostStepperHorizontalPadding,
                        defaults.horizontalPadding.value * context.resources.displayMetrics.density,
                    ),
                ),
            )
            FrostNumericStepperAttrs(appearance = appearance)
        } finally {
            typedArray.recycle()
        }
    }

    fun readStatusIndicator(
        context: Context,
        attrs: AttributeSet?,
        defStyleAttr: Int = R.attr.frostStatusIndicatorStyle,
        defStyleRes: Int = R.style.FrostStatusIndicator,
    ): FrostStatusIndicatorAttrs {
        val typedArray = context.obtainStyledAttributes(
            attrs,
            R.styleable.FrostStatusIndicator,
            defStyleAttr,
            defStyleRes,
        )
        return try {
            val stateOrdinal = typedArray.getInt(
                R.styleable.FrostStatusIndicator_frostStatusState,
                FrostStatusState.Idle.ordinal,
            )
            val variantOrdinal = typedArray.getInt(
                R.styleable.FrostStatusIndicator_frostStatusVariant,
                FrostStatusVariant.Dot.ordinal,
            )
            val appearance = FrostStatusIndicatorAppearance(
                indicatorSize = context.pxToDp(
                    typedArray.getDimension(
                        R.styleable.FrostStatusIndicator_frostStatusIndicatorSize,
                        context.resources.getDimension(R.dimen.frost_status_indicator_size),
                    ),
                ),
                strokeWidth = context.pxToDp(
                    typedArray.getDimension(
                        R.styleable.FrostStatusIndicator_frostStatusStrokeWidth,
                        context.resources.getDimension(R.dimen.frost_status_stroke_width),
                    ),
                ),
                dotRadius = context.pxToDp(
                    typedArray.getDimension(
                        R.styleable.FrostStatusIndicator_frostStatusDotRadius,
                        context.resources.getDimension(R.dimen.frost_status_dot_radius),
                    ),
                ),
                idleRingColor = typedArray.getColor(
                    R.styleable.FrostStatusIndicator_frostStatusIdleRingColor,
                    ContextCompat.getColor(context, R.color.frost_status_idle_ring),
                ).toComposeColor(),
                inProgressDotColor = typedArray.getColor(
                    R.styleable.FrostStatusIndicator_frostStatusInProgressDotColor,
                    ContextCompat.getColor(context, R.color.frost_status_in_progress_dot),
                ).toComposeColor(),
                successColor = typedArray.getColor(
                    R.styleable.FrostStatusIndicator_frostStatusSuccessColor,
                    ContextCompat.getColor(context, R.color.frost_status_success),
                ).toComposeColor(),
                failureColor = typedArray.getColor(
                    R.styleable.FrostStatusIndicator_frostStatusFailureColor,
                    ContextCompat.getColor(context, R.color.frost_status_failure),
                ).toComposeColor(),
                glyphColor = typedArray.getColor(
                    R.styleable.FrostStatusIndicator_frostStatusGlyphColor,
                    ContextCompat.getColor(context, R.color.frost_status_glyph),
                ).toComposeColor(),
            )
            FrostStatusIndicatorAttrs(
                state = FrostStatusState.entries.getOrElse(stateOrdinal) { FrostStatusState.Idle },
                variant = FrostStatusVariant.entries.getOrElse(variantOrdinal) { FrostStatusVariant.Dot },
                appearance = appearance,
            )
        } finally {
            typedArray.recycle()
        }
    }

    private fun Int.toComposeColor(): Color = Color(this)

    private fun spToPx(context: Context, sp: Float): Float =
        sp * context.resources.displayMetrics.scaledDensity
}
