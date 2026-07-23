package com.lasercyber.lws.frostui.control

import android.content.Context
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.lasercyber.lws.ui.R

object FrostControlColors {
    fun switchTrackOff(context: Context): Color =
        color(context, R.color.frost_control_switch_track_off)

    fun switchTrackOn(context: Context): Color =
        color(context, R.color.frost_control_switch_track_on)

    fun switchThumb(context: Context): Color =
        color(context, R.color.frost_control_switch_thumb)

    fun checkboxFill(context: Context): Color =
        color(context, R.color.frost_control_checkbox_fill)

    fun checkboxStroke(context: Context): Color =
        color(context, R.color.frost_control_checkbox_stroke)

    fun checkboxCheckmark(context: Context): Color =
        color(context, R.color.frost_control_checkbox_checkmark)

    fun checkboxLabel(context: Context): Color =
        color(context, R.color.frost_control_checkbox_label)

    fun sliderTrackInactive(context: Context): Color =
        color(context, R.color.frost_control_slider_track_inactive)

    fun sliderTrackActive(context: Context): Color =
        color(context, R.color.frost_control_slider_track_active)

    fun sliderThumb(context: Context): Color =
        color(context, R.color.frost_control_slider_thumb)

    fun sliderLabel(context: Context): Color =
        color(context, R.color.frost_control_slider_label)

    fun capsuleFill(context: Context): Color =
        color(context, R.color.frost_control_capsule_fill)

    fun capsuleBorder(context: Context): Color =
        color(context, R.color.frost_control_capsule_border)

    fun segmentSelectedFill(context: Context): Color =
        color(context, R.color.frost_control_segment_selected_fill)

    fun segmentUnselectedFill(context: Context): Color =
        color(context, R.color.frost_control_segment_unselected_fill)

    fun segmentSelectedText(context: Context): Color =
        color(context, R.color.frost_control_segment_selected_text)

    fun segmentUnselectedText(context: Context): Color =
        color(context, R.color.frost_control_segment_unselected_text)

    fun capsuleSliderTrackInactive(context: Context): Color =
        color(context, R.color.frost_control_capsule_slider_track_inactive)

    fun capsuleSliderTrackActive(context: Context): Color =
        color(context, R.color.frost_control_capsule_slider_track_active)

    fun capsuleSliderOverlayLight(context: Context): Color =
        color(context, R.color.frost_control_capsule_slider_overlay_light)

    fun capsuleSliderOverlayDark(context: Context): Color =
        color(context, R.color.frost_control_capsule_slider_overlay_dark)

    fun statusIdleRing(context: Context): Color =
        color(context, R.color.frost_status_idle_ring)

    fun statusInProgressDot(context: Context): Color =
        color(context, R.color.frost_status_in_progress_dot)

    fun statusSuccess(context: Context): Color =
        color(context, R.color.frost_status_success)

    fun statusFailure(context: Context): Color =
        color(context, R.color.frost_status_failure)

    fun statusGlyph(context: Context): Color =
        color(context, R.color.frost_status_glyph)

    private fun color(context: Context, resId: Int): Color {
        return Color(ContextCompat.getColor(context, resId))
    }
}

object FrostControlDimens {
    fun switchTrackWidth(context: Context) =
        context.pxToDp(context.resources.getDimension(R.dimen.frost_switch_track_width))

    fun switchTrackHeight(context: Context) =
        context.pxToDp(context.resources.getDimension(R.dimen.frost_switch_track_height))

    fun switchTrackCornerRadius(context: Context) =
        context.pxToDp(context.resources.getDimension(R.dimen.frost_switch_track_corner_radius))

    fun switchThumbSize(context: Context) =
        context.pxToDp(context.resources.getDimension(R.dimen.frost_switch_thumb_size))

    fun switchThumbInsetVertical(context: Context) =
        context.pxToDp(context.resources.getDimension(R.dimen.frost_switch_thumb_inset_vertical))

    fun checkboxSize(context: Context) =
        context.pxToDp(context.resources.getDimension(R.dimen.frost_checkbox_size))

    fun checkboxStrokeWidth(context: Context) =
        context.pxToDp(context.resources.getDimension(R.dimen.frost_checkbox_stroke_width))

    fun checkboxLabelSpacing(context: Context) =
        context.pxToDp(context.resources.getDimension(R.dimen.frost_checkbox_label_spacing))

    fun checkboxLabelTextSize(context: Context) =
        context.pxToSp(context.resources.getDimension(R.dimen.frost_checkbox_label_text_size))

    fun statusIndicatorSize(context: Context) =
        context.pxToDp(context.resources.getDimension(R.dimen.frost_status_indicator_size))

    fun statusStrokeWidth(context: Context) =
        context.pxToDp(context.resources.getDimension(R.dimen.frost_status_stroke_width))

    fun statusDotRadius(context: Context) =
        context.pxToDp(context.resources.getDimension(R.dimen.frost_status_dot_radius))

    fun sliderLabelTextSize(context: Context) =
        context.pxToSp(context.resources.getDimension(R.dimen.frost_slider_label_text_size))

    fun sliderThumbSize(context: Context) =
        context.pxToDp(context.resources.getDimension(R.dimen.frost_slider_thumb_size))

    fun sliderTrackHeight(context: Context) =
        context.pxToDp(context.resources.getDimension(R.dimen.frost_slider_track_height))

    fun sliderTrackCornerRadius(context: Context) =
        context.pxToDp(context.resources.getDimension(R.dimen.frost_slider_track_corner_radius))

    fun sliderTouchHeight(context: Context) =
        context.pxToDp(context.resources.getDimension(R.dimen.frost_slider_touch_height))

    fun sliderLongPressThresholdMs(context: Context): Long =
        context.resources.getInteger(R.integer.frost_slider_long_press_threshold_ms).toLong()

    fun segmentLongPressThresholdMs(context: Context): Long =
        context.resources.getInteger(R.integer.frost_segment_long_press_threshold_ms).toLong()

    fun sliderThumbDragScale(context: Context): Float =
        context.resources.getInteger(R.integer.frost_slider_thumb_drag_scale_tenths) / 10f

    fun sliderThumbDragOverflow(context: Context) =
        context.pxToDp(context.resources.getDimension(R.dimen.frost_slider_thumb_drag_overflow))

    fun sliderCenterSnapThreshold(context: Context): Int =
        context.resources.getInteger(R.integer.frost_slider_center_snap_threshold)

    fun sliderCenterSnapDwellMs(context: Context): Long =
        context.resources.getInteger(R.integer.frost_slider_center_snap_dwell_ms).toLong()

    fun sliderSnapEscapeDistancePx(context: Context): Float =
        context.resources.getDimension(R.dimen.frost_slider_snap_escape_distance)

    fun sliderCenterSnapConfig(context: Context, min: Int, max: Int): FrostSliderCenterSnapConfig? =
        frostSliderCenterSnapConfig(
            min = min,
            max = max,
            centerValue = FrostControlDefaults.SLIDER_CENTER_SNAP_VALUE,
            threshold = sliderCenterSnapThreshold(context),
            escapeDistancePx = sliderSnapEscapeDistancePx(context),
            dwellMs = sliderCenterSnapDwellMs(context).let { configured ->
                if (configured > 0) configured else FrostControlDefaults.SLIDER_CENTER_SNAP_DWELL_MS.toLong()
            },
        )

    fun capsuleControlHeight(context: Context) =
        context.pxToDp(context.resources.getDimension(R.dimen.frost_capsule_control_height))

    fun segmentedAppearance(
        context: Context,
        segmentTextSize: TextUnit? = null,
    ): FrostSegmentedAppearance =
        FrostSegmentedAppearance(
            capsuleFillColor = FrostControlColors.capsuleFill(context),
            capsuleBorderColor = FrostControlColors.capsuleBorder(context),
            capsuleCornerRadius = capsuleOuterCornerRadius(context),
            capsuleInset = capsuleInset(context),
            capsuleBorderWidth = capsuleBorderWidth(context),
            segmentSelectedFillColor = FrostControlColors.segmentSelectedFill(context),
            segmentUnselectedFillColor = FrostControlColors.segmentUnselectedFill(context),
            segmentSelectedTextColor = FrostControlColors.segmentSelectedText(context),
            segmentUnselectedTextColor = FrostControlColors.segmentUnselectedText(context),
            segmentTextSize = segmentTextSize ?: context.pxToSp(
                context.resources.getDimension(R.dimen.frost_segment_text_size_large),
            ),
            crossfadeDurationMs = FrostControlDefaults.SEGMENT_CROSSFADE_DURATION_MS,
        )

    fun capsuleOuterCornerRadius(context: Context) =
        context.pxToDp(context.resources.getDimension(R.dimen.frost_capsule_outer_corner_radius))

    fun capsuleInset(context: Context) =
        context.pxToDp(context.resources.getDimension(R.dimen.frost_capsule_inset))

    fun capsuleBorderWidth(context: Context) =
        context.pxToDp(context.resources.getDimension(R.dimen.frost_capsule_border_width))

    fun capsuleSliderAppearance(context: Context, valueSuffix: String = "%"): FrostCapsuleSliderAppearance =
        FrostCapsuleSliderAppearance(
            capsuleFillColor = FrostControlColors.capsuleFill(context),
            capsuleBorderColor = FrostControlColors.capsuleBorder(context),
            capsuleCornerRadius = capsuleOuterCornerRadius(context),
            capsuleInset = capsuleInset(context),
            capsuleBorderWidth = capsuleBorderWidth(context),
            trackInactiveColor = FrostControlColors.capsuleSliderTrackInactive(context),
            trackActiveColor = FrostControlColors.capsuleSliderTrackActive(context),
            overlayLightColor = FrostControlColors.capsuleSliderOverlayLight(context),
            overlayDarkColor = FrostControlColors.capsuleSliderOverlayDark(context),
            sliderHeight = context.pxToDp(context.resources.getDimension(R.dimen.frost_capsule_slider_height)),
            sliderCornerRadius = context.pxToDp(context.resources.getDimension(R.dimen.frost_capsule_slider_corner_radius)),
            valueTextSize = context.pxToSp(context.resources.getDimension(R.dimen.frost_capsule_slider_value_text_size)),
            trailingIconSize = context.pxToDp(context.resources.getDimension(R.dimen.frost_capsule_slider_trailing_icon_size)),
            valuePaddingHorizontal = context.pxToDp(context.resources.getDimension(R.dimen.frost_capsule_slider_value_padding_horizontal)),
            valueSuffix = valueSuffix,
        )
}
