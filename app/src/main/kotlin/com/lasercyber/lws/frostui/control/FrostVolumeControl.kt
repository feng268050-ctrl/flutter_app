package com.lasercyber.lws.frostui.control

import androidx.annotation.DrawableRes
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.dimensionResource
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.lasercyber.lws.ui.R

/** System stream volume range (0–100%). */
object FrostVolumeControlDefaults {
    const val MIN_PERCENT = 0
    const val MAX_PERCENT = 100

    @DrawableRes
    val LEADING_ICON_RES: Int = R.drawable.ic_frost_volume_low

    @DrawableRes
    val TRAILING_ICON_RES: Int = R.drawable.ic_frost_volume
}

/**
 * [FrostSlider] with optional leading / trailing icons. Icons render only when a resource is
 * provided; omit one side to show a single icon (typically leading).
 *
 * Icon-to-track gap uses [R.dimen.frost_audio_player_content_spacing].
 */
@Composable
fun FrostIconFlankedSlider(
    progress: Int,
    onProgressChange: (Int, Boolean) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    min: Int = 0,
    max: Int = 100,
    @DrawableRes leadingIconRes: Int? = null,
    @DrawableRes trailingIconRes: Int? = null,
    leadingIconGap: Dp? = null,
    trailingIconGap: Dp? = null,
    longPressDragEnabled: Boolean = true,
    reserveThumbOverflow: Boolean = false,
    appearance: FrostSliderAppearance = defaultFrostSliderAppearance(LocalContext.current),
    onStartTracking: (() -> Unit)? = null,
    onStopTracking: ((cancelled: Boolean) -> Unit)? = null,
) {
    val iconSize = appearance.thumbSize
    val defaultIconGap = dimensionResource(R.dimen.frost_audio_player_content_spacing)
    val resolvedLeadingIconGap = leadingIconGap ?: defaultIconGap
    val resolvedTrailingIconGap = trailingIconGap ?: defaultIconGap
    val clampedProgress = progress.coerceIn(min, max)

    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (leadingIconRes != null) {
            Icon(
                painter = painterResource(leadingIconRes),
                contentDescription = null,
                tint = appearance.labelColor,
                modifier = Modifier.size(iconSize),
            )
            Spacer(modifier = Modifier.width(resolvedLeadingIconGap))
        }
        FrostSlider(
            progress = clampedProgress,
            onProgressChange = onProgressChange,
            modifier = Modifier.weight(1f),
            enabled = enabled,
            min = min,
            max = max,
            scaleMinText = null,
            scaleMaxText = null,
            longPressDragEnabled = longPressDragEnabled,
            reserveThumbOverflow = reserveThumbOverflow,
            appearance = appearance,
            onStartTracking = onStartTracking,
            onStopTracking = onStopTracking,
        )
        if (trailingIconRes != null) {
            Spacer(modifier = Modifier.width(resolvedTrailingIconGap))
            Icon(
                painter = painterResource(trailingIconRes),
                contentDescription = null,
                tint = appearance.labelColor,
                modifier = Modifier.size(iconSize),
            )
        }
    }
}

/**
 * System media volume (0–100%) with low / high speaker icons flanking the slider.
 * Card insets match [FrostAudioPlayerCard] ([R.dimen.frost_audio_player_card_padding]).
 */
@Composable
fun FrostVolumeControl(
    volumePercent: Int,
    onVolumeChange: (Int, Boolean) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    contentPadding: Dp = dimensionResource(R.dimen.frost_audio_player_card_padding),
    @DrawableRes leadingIconRes: Int? = FrostVolumeControlDefaults.LEADING_ICON_RES,
    @DrawableRes trailingIconRes: Int? = FrostVolumeControlDefaults.TRAILING_ICON_RES,
) {
    val leadingIconGap = dimensionResource(R.dimen.frost_volume_control_leading_icon_spacing)
    FrostIconFlankedSlider(
        progress = volumePercent,
        onProgressChange = onVolumeChange,
        modifier = modifier
            .fillMaxWidth()
            .padding(contentPadding),
        enabled = enabled,
        min = FrostVolumeControlDefaults.MIN_PERCENT,
        max = FrostVolumeControlDefaults.MAX_PERCENT,
        leadingIconRes = leadingIconRes,
        trailingIconRes = trailingIconRes,
        leadingIconGap = leadingIconGap,
        longPressDragEnabled = true,
    )
}
