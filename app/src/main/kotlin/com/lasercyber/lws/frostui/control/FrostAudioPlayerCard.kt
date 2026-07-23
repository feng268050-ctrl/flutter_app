package com.lasercyber.lws.frostui.control

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.dimensionResource
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.lasercyber.lws.frostui.button.FrostButton
import com.lasercyber.lws.frostui.button.FrostButtonShape
import com.lasercyber.lws.frostui.button.FrostButtonVariant
import com.lasercyber.lws.ui.R

/**
 * Standard audio transport card: rewind / play-pause / fast-forward, seek slider,
 * elapsed and duration below the slider (same label tokens as [FrostFlankedSliderView]).
 *
 * Content padding and vertical gaps between transport, slider, and time labels use
 * [R.dimen.frost_audio_player_card_padding] (same as [inset_list_horizontal_inset]).
 */
@Composable
fun FrostAudioPlayerCard(
    isPlaying: Boolean,
    positionMs: Long,
    durationMs: Long,
    onRewind: () -> Unit,
    onPlayPause: () -> Unit,
    onFastForward: () -> Unit,
    onSeek: (positionMs: Long) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    seekEnabled: Boolean = false,
) {
    val context = LocalContext.current
    val sliderAppearance = defaultFrostSliderAppearance(context)
    val timeLabelColor = FrostControlColors.sliderLabel(context)
    val timeLabelSize = FrostControlDimens.sliderLabelTextSize(context)
    val seekBarMax = AUDIO_SEEK_BAR_MAX
    val safeDurationMs = durationMs.coerceAtLeast(1L)
    var userSeeking by remember { mutableStateOf(false) }
    var seekProgress by remember { mutableIntStateOf(0) }
    val positionProgress = ((positionMs * seekBarMax) / safeDurationMs).toInt().coerceIn(0, seekBarMax)
    if (!userSeeking) {
        seekProgress = positionProgress
    }

    val seekButtonSize = dimensionResource(R.dimen.frost_action_button_height)
    val playButtonSize = dimensionResource(R.dimen.process_video_player_play_button_size)
    val playButtonPadding = dimensionResource(R.dimen.process_video_player_play_button_padding)
    val seekButtonPadding = dimensionResource(R.dimen.process_video_player_seek_button_padding)
    val transportSpacing = dimensionResource(R.dimen.process_video_player_transport_button_spacing)
    val contentSpacing = dimensionResource(R.dimen.frost_audio_player_card_padding)
    val seekIconSize = dimensionResource(R.dimen.process_video_player_seek_icon_size)
    val playIconSize = dimensionResource(R.dimen.process_video_player_play_icon_size)

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(contentSpacing),
        verticalArrangement = Arrangement.spacedBy(contentSpacing),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            FrostAudioPlayerIconButton(
                iconRes = R.drawable.ic_process_video_rewind,
                contentDescription = stringResource(R.string.process_video_rewind),
                onClick = onRewind,
                enabled = enabled,
                buttonSize = seekButtonSize,
                iconSize = seekIconSize,
                contentPadding = seekButtonPadding,
            )
            Spacer(modifier = Modifier.width(transportSpacing))
            FrostAudioPlayerIconButton(
                iconRes = if (isPlaying) {
                    R.drawable.ic_process_video_pause
                } else {
                    R.drawable.ic_process_video_play
                },
                contentDescription = stringResource(
                    if (isPlaying) {
                        R.string.ai_vision_video_pause
                    } else {
                        R.string.ai_vision_video_play
                    },
                ),
                onClick = onPlayPause,
                enabled = enabled,
                buttonSize = playButtonSize,
                iconSize = playIconSize,
                contentPadding = playButtonPadding,
            )
            Spacer(modifier = Modifier.width(transportSpacing))
            FrostAudioPlayerIconButton(
                iconRes = R.drawable.ic_process_video_fast_forward,
                contentDescription = stringResource(R.string.process_video_fast_forward),
                onClick = onFastForward,
                enabled = enabled,
                buttonSize = seekButtonSize,
                iconSize = seekIconSize,
                contentPadding = seekButtonPadding,
            )
        }
        FrostSlider(
            progress = if (userSeeking) seekProgress else positionProgress,
            onProgressChange = { value, fromUser ->
                if (!fromUser) return@FrostSlider
                seekProgress = value
            },
            min = 0,
            max = seekBarMax,
            enabled = enabled && seekEnabled,
            longPressDragEnabled = true,
            appearance = sliderAppearance,
            onStartTracking = { userSeeking = true },
            onStopTracking = { cancelled ->
                if (!cancelled) {
                    onSeek((seekProgress.toLong() * safeDurationMs) / seekBarMax)
                }
                userSeeking = false
            },
            modifier = Modifier.fillMaxWidth(),
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = formatAudioPlayerTimeMs(
                    if (userSeeking) {
                        (seekProgress.toLong() * safeDurationMs) / seekBarMax
                    } else {
                        positionMs
                    },
                ),
                color = timeLabelColor,
                fontSize = timeLabelSize,
                maxLines = 1,
            )
            Text(
                text = formatAudioPlayerTimeMs(durationMs),
                color = timeLabelColor,
                fontSize = timeLabelSize,
                maxLines = 1,
            )
        }
    }
}

@Composable
private fun FrostAudioPlayerIconButton(
    iconRes: Int,
    contentDescription: String,
    onClick: () -> Unit,
    enabled: Boolean,
    buttonSize: androidx.compose.ui.unit.Dp,
    iconSize: androidx.compose.ui.unit.Dp,
    contentPadding: androidx.compose.ui.unit.Dp,
    modifier: Modifier = Modifier,
) {
    FrostButton(
        onClick = onClick,
        modifier = modifier.size(buttonSize),
        variant = FrostButtonVariant.LIGHT,
        shape = FrostButtonShape.ROUNDED,
        enabled = enabled,
        horizontalPaddingStart = contentPadding,
        horizontalPaddingEnd = contentPadding,
        verticalPaddingTop = contentPadding,
        verticalPaddingBottom = contentPadding,
        minWidth = 0.dp,
        playClickSound = true,
    ) {
        Icon(
            painter = painterResource(iconRes),
            contentDescription = contentDescription,
            tint = Color.White,
            modifier = Modifier.size(iconSize),
        )
    }
}

fun formatAudioPlayerTimeMs(ms: Long): String {
    if (ms <= 0L) {
        return "00:00"
    }
    val totalSeconds = ms / 1000L
    val minutes = totalSeconds / 60L
    val seconds = totalSeconds % 60L
    return "%02d:%02d".format(minutes, seconds)
}

/** @deprecated Use [FrostAudioPlayerCard] */
@Deprecated("Renamed to FrostAudioPlayerCard", ReplaceWith("FrostAudioPlayerCard"))
@Composable
fun FrostMediaTransportCard(
    nowPlayingLine: String,
    isPlaying: Boolean,
    positionMs: Long,
    durationMs: Long,
    onRewind: () -> Unit,
    onPlayPause: () -> Unit,
    onFastForward: () -> Unit,
    onSeek: (positionMs: Long) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    seekEnabled: Boolean = false,
) {
    FrostAudioPlayerCard(
        isPlaying = isPlaying,
        positionMs = positionMs,
        durationMs = durationMs,
        onRewind = onRewind,
        onPlayPause = onPlayPause,
        onFastForward = onFastForward,
        onSeek = onSeek,
        modifier = modifier,
        enabled = enabled,
        seekEnabled = seekEnabled,
    )
}

/** @deprecated Use [formatAudioPlayerTimeMs] */
@Deprecated("Renamed to formatAudioPlayerTimeMs", ReplaceWith("formatAudioPlayerTimeMs(ms)"))
fun formatMediaTimeMs(ms: Long): String = formatAudioPlayerTimeMs(ms)

private const val AUDIO_SEEK_BAR_MAX = 1000
