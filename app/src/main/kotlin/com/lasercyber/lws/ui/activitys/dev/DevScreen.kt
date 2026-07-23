package com.lasercyber.lws.ui.activitys.dev

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.colorResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lasercyber.lws.frostui.border.FrostBlurIntensity
import com.lasercyber.lws.frostui.border.FrostColors
import com.lasercyber.lws.frostui.button.FrostButton
import com.lasercyber.lws.frostui.card.FrostCard
import com.lasercyber.lws.frostui.control.FrostAudioPlayerCard
import com.lasercyber.lws.frostui.control.FrostHorizontalRhythmBar
import com.lasercyber.lws.frostui.control.FrostSegmentedAppearance
import com.lasercyber.lws.frostui.control.FrostSegmentedControl
import com.lasercyber.lws.frostui.control.FrostSlider
import com.lasercyber.lws.frostui.control.FrostSliderAppearance
import com.lasercyber.lws.frostui.control.FrostVolumeControl
import com.lasercyber.lws.frostui.control.defaultFrostSegmentedAppearance
import com.lasercyber.lws.frostui.control.defaultFrostSliderAppearance
import com.lasercyber.lws.ui.R
import com.lasercyber.lws.ui.common.config.GpioLedConfig
import com.lasercyber.lws.ui.common.gpio.LedIndicatorManager

enum class DevIndicatorColor(val gpioPin: Int, val label: String) {
    RED(GpioLedConfig.GPIO_RED, "Red"),
    YELLOW(GpioLedConfig.GPIO_YELLOW, "Yellow"),
    GREEN(GpioLedConfig.GPIO_GREEN, "Green"),
}

enum class DevIndicatorMode {
    OFF,
    STEADY,
    BLINK,
}

data class DevScreenCallbacks(
    val onIndicatorModeChange: (DevIndicatorColor, DevIndicatorMode, Int) -> Unit,
    val onIndicatorBrightnessChange: (DevIndicatorColor, Int) -> Unit,
    val onAllIndicatorsOff: () -> Unit,
    val onRefreshBusinessLeds: () -> Unit,
    val onMusicPlayPause: () -> Unit,
    val onMusicRewind: () -> Unit,
    val onMusicFastForward: () -> Unit,
    val onMusicSeek: (Long) -> Unit,
    val onMusicVolumeChange: (Int) -> Unit,
    val onPingCamera: () -> Unit,
    val onCheckCamera: () -> Unit,
    val onStartRecord: () -> Unit,
    val onStopRecord: () -> Unit,
    val onPauseRecord: () -> Unit,
    val onContinueRecord: () -> Unit,
    val onAnimationTest: () -> Unit,
)

@Composable
fun DevScreen(
    statusLine: String,
    hardwareReady: Boolean,
    showVirtualRhythmBar: Boolean,
    musicState: DevMusicUiState,
    callbacks: DevScreenCallbacks,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val scrollState = rememberScrollState()
    val segmentAppearance = defaultFrostSegmentedAppearance(context)
    val sliderAppearance = defaultFrostSliderAppearance(context)
    val primaryText = FrostColors.textPrimary(context)
    val secondaryText = FrostColors.textSecondary(context)
    val pageBackground = colorResource(R.color.safety_black)

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(pageBackground)
            .verticalScroll(scrollState)
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            text = "Developer Debug",
            color = primaryText,
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = statusLine,
            color = secondaryText,
            fontSize = 14.sp,
            lineHeight = 20.sp,
        )
        Text(
            text = "Side panel GPIO R/Y/G (pins ${GpioLedConfig.GPIO_RED}/${GpioLedConfig.GPIO_YELLOW}/${GpioLedConfig.GPIO_GREEN}). " +
                "Steady brightness experiment: GPIO PWM (${LedIndicatorManager.EXPERIMENTAL_PWM_FREQUENCY_HZ}–" +
                "${LedIndicatorManager.EXPERIMENTAL_PWM_MAX_FREQUENCY_HZ} Hz adaptive boost when dim, γ=${LedIndicatorManager.EXPERIMENTAL_PWM_GAMMA}).",
            color = secondaryText,
            fontSize = 12.sp,
            lineHeight = 18.sp,
        )

        DevIndicatorColor.entries.forEach { color ->
            IndicatorSection(
                color = color,
                hardwareReady = hardwareReady,
                sliderAppearance = sliderAppearance,
                segmentAppearance = segmentAppearance,
                primaryText = primaryText,
                secondaryText = secondaryText,
                onModeChange = { mode, brightness ->
                    callbacks.onIndicatorModeChange(color, mode, brightness)
                },
                onBrightnessChange = { brightness ->
                    callbacks.onIndicatorBrightnessChange(color, brightness)
                },
            )
        }

        Text(
            text = "Music Rhythm LEDs",
            color = primaryText,
            fontSize = 18.sp,
            fontWeight = FontWeight.SemiBold,
        )
        Text(
            text = "Now Playing: ${musicState.trackFileName}",
            color = secondaryText,
            fontSize = 14.sp,
            lineHeight = 20.sp,
        )
        FrostCard(
            modifier = Modifier.fillMaxWidth(),
            blurIntensity = FrostBlurIntensity.TRANSPARENT,
            contentPadding = 0.dp,
        ) {
            FrostAudioPlayerCard(
                isPlaying = musicState.isPlaying,
                positionMs = musicState.positionMs,
                durationMs = musicState.durationMs,
                seekEnabled = musicState.isPrepared && musicState.durationMs > 0L,
                onRewind = callbacks.onMusicRewind,
                onPlayPause = callbacks.onMusicPlayPause,
                onFastForward = callbacks.onMusicFastForward,
                onSeek = callbacks.onMusicSeek,
            )
        }
        FrostCard(
            modifier = Modifier.fillMaxWidth(),
            blurIntensity = FrostBlurIntensity.TRANSPARENT,
            contentPadding = 0.dp,
        ) {
            FrostVolumeControl(
                volumePercent = musicState.volumePercent,
                onVolumeChange = { value, fromUser ->
                    if (fromUser) {
                        callbacks.onMusicVolumeChange(value)
                    }
                },
                enabled = true,
            )
        }
        if (showVirtualRhythmBar) {
            FrostCard(
                modifier = Modifier.fillMaxWidth(),
                blurIntensity = FrostBlurIntensity.TRANSPARENT,
                contentPadding = 16.dp,
            ) {
                FrostHorizontalRhythmBar(
                    litSegments = musicState.barSegments,
                    pulseLevel = musicState.pulseLevel,
                )
            }
        }

        FrostCard(
            modifier = Modifier.fillMaxWidth(),
            blurIntensity = FrostBlurIntensity.TRANSPARENT,
            contentPadding = 16.dp,
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Indicator Actions", color = primaryText, fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
                FlowActionRow {
                    FrostButton(
                        text = "All Off",
                        onClick = callbacks.onAllIndicatorsOff,
                        enabled = hardwareReady,
                    )
                    FrostButton(
                        text = "Refresh Business LEDs",
                        onClick = callbacks.onRefreshBusinessLeds,
                    )
                }
            }
        }

        FrostCard(
            modifier = Modifier.fillMaxWidth(),
            blurIntensity = FrostBlurIntensity.TRANSPARENT,
            contentPadding = 16.dp,
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Camera / Record", color = primaryText, fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
                FlowActionRow {
                    FrostButton(text = "Ping Camera", onClick = callbacks.onPingCamera)
                    FrostButton(text = "Check Camera", onClick = callbacks.onCheckCamera)
                }
                FlowActionRow {
                    FrostButton(text = "Start Record", onClick = callbacks.onStartRecord)
                    FrostButton(text = "Stop Record", onClick = callbacks.onStopRecord)
                    FrostButton(text = "Pause Record", onClick = callbacks.onPauseRecord)
                    FrostButton(text = "Resume Record", onClick = callbacks.onContinueRecord)
                }
                FrostButton(text = "Animation Dialog Test", onClick = callbacks.onAnimationTest)
            }
        }
    }
}

@Composable
private fun IndicatorSection(
    color: DevIndicatorColor,
    hardwareReady: Boolean,
    sliderAppearance: FrostSliderAppearance,
    segmentAppearance: FrostSegmentedAppearance,
    primaryText: Color,
    secondaryText: Color,
    onModeChange: (DevIndicatorMode, Int) -> Unit,
    onBrightnessChange: (Int) -> Unit,
) {
    var modeIndex by rememberSaveable(color.name) { mutableIntStateOf(DevIndicatorMode.STEADY.ordinal) }
    var brightness by rememberSaveable(color.name) { mutableIntStateOf(128) }
    val modes = listOf("Off", "Steady", "Blink")
    val dividerColor = colorResource(R.color.inset_divider_color)

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = "${color.label} · GPIO ${color.gpioPin}",
            color = primaryText,
            fontSize = 24.sp,
            fontWeight = FontWeight.Normal,
            maxLines = 1,
        )
        FrostCard(
            modifier = Modifier.fillMaxWidth(),
            blurIntensity = FrostBlurIntensity.TRANSPARENT,
            contentPadding = 0.dp,
        ) {
            Column(modifier = Modifier.fillMaxWidth()) {
                DevSettingsInsetRow(label = "Mode", labelColor = primaryText) {
                    FrostSegmentedControl(
                        selectedIndex = modeIndex,
                        onSelectedIndexChange = { index ->
                            modeIndex = index
                            if (index == DevIndicatorMode.STEADY.ordinal && brightness == 0) {
                                brightness = 128
                            }
                            onModeChange(DevIndicatorMode.entries[index], brightness)
                        },
                        options = modes,
                        enabled = hardwareReady,
                        appearance = segmentAppearance,
                        modifier = Modifier
                            .weight(1f)
                            .height(56.dp),
                    )
                }
                DevInsetDivider(color = dividerColor)
                DevSettingsInsetRow(
                    label = "Brightness",
                    labelColor = primaryText,
                    rowHeight = 96.dp,
                ) {
                    FrostSlider(
                        progress = brightness,
                        onProgressChange = { value, fromUser ->
                            if (!fromUser) return@FrostSlider
                            brightness = value
                            if (modeIndex != DevIndicatorMode.STEADY.ordinal) {
                                modeIndex = DevIndicatorMode.STEADY.ordinal
                                onModeChange(DevIndicatorMode.STEADY, value)
                            } else {
                                onBrightnessChange(value)
                            }
                        },
                        min = 0,
                        max = 255,
                        enabled = hardwareReady,
                        longPressDragEnabled = false,
                        scaleMinText = "0",
                        scaleMaxText = "255",
                        appearance = sliderAppearance,
                        modifier = Modifier.weight(1f),
                    )
                }
                if (!hardwareReady) {
                    Text(
                        text = "YNHAPI / GPIO not ready — controls are preview only",
                        color = secondaryText,
                        fontSize = 12.sp,
                        modifier = Modifier.padding(horizontal = 24.dp, vertical = 12.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun DevInsetDivider(color: Color) {
    HorizontalDivider(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp),
        thickness = 1.dp,
        color = color,
    )
}

@Composable
private fun DevSettingsInsetRow(
    label: String,
    labelColor: Color,
    modifier: Modifier = Modifier,
    rowHeight: Dp = 80.dp,
    controlVerticalAlignment: Alignment.Vertical = Alignment.CenterVertically,
    control: @Composable RowScope.() -> Unit,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(rowHeight)
            .padding(horizontal = 24.dp),
        verticalAlignment = controlVerticalAlignment,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = label,
            color = labelColor,
            fontSize = 24.sp,
            maxLines = 1,
            modifier = Modifier.weight(1f),
        )
        control()
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun FlowActionRow(
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    FlowRow(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        content = { content() },
    )
}
