package com.lasercyber.lws.frostui.control

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

data class FrostSwitchAppearance(
    val trackOffColor: Color,
    val trackOnColor: Color,
    val thumbColor: Color,
    val trackWidth: Dp,
    val trackHeight: Dp,
    val trackCornerRadius: Dp,
    val thumbSize: Dp,
    val thumbInsetVertical: Dp,
    val animationDurationMs: Int,
)

data class FrostCheckboxAppearance(
    val checkedFillColor: Color,
    val uncheckedStrokeColor: Color,
    val checkmarkColor: Color,
    val boxSize: Dp,
    val strokeWidth: Dp,
    val labelSpacing: Dp,
    val labelColor: Color,
    val labelSize: TextUnit,
    val animationDurationMs: Int,
)

data class FrostSliderAppearance(
    val trackInactiveColor: Color,
    val trackActiveColor: Color,
    val thumbColor: Color,
    val labelColor: Color,
    val labelSize: TextUnit,
    val thumbSize: Dp,
    val trackHeight: Dp,
    val trackCornerRadius: Dp,
    val touchHeight: Dp,
)

data class FrostSegmentedAppearance(
    val capsuleFillColor: Color,
    val capsuleBorderColor: Color,
    val capsuleCornerRadius: Dp,
    val capsuleInset: Dp,
    val capsuleBorderWidth: Dp,
    val segmentSelectedFillColor: Color,
    val segmentUnselectedFillColor: Color,
    val segmentSelectedTextColor: Color,
    val segmentUnselectedTextColor: Color,
    val segmentTextSize: TextUnit,
    val crossfadeDurationMs: Int,
)

data class FrostCapsuleSliderAppearance(
    val capsuleFillColor: Color,
    val capsuleBorderColor: Color,
    val capsuleCornerRadius: Dp,
    val capsuleInset: Dp,
    val capsuleBorderWidth: Dp,
    val trackInactiveColor: Color,
    val trackActiveColor: Color,
    val overlayLightColor: Color,
    val overlayDarkColor: Color,
    val sliderHeight: Dp,
    val sliderCornerRadius: Dp,
    val valueTextSize: TextUnit,
    val trailingIconSize: Dp,
    val valuePaddingHorizontal: Dp,
    val valueSuffix: String,
)
