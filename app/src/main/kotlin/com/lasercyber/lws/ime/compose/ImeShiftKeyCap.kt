package com.lasercyber.lws.ime.compose

import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.lasercyber.lws.frostui.border.FrostDimens
import com.lasercyber.lws.frostui.button.FrostButton
import com.lasercyber.lws.frostui.button.FrostButtonShape
import com.lasercyber.lws.frostui.button.FrostButtonVariant
import com.lasercyber.lws.frostui.common.FrostUiClickSoundRegistry

private val ImeShiftCapsLockIndicatorActiveColor = Color(0xFF32D74B)

@Composable
private fun imeShiftCapsLockIndicatorColor(locked: Boolean): Color =
    if (locked) {
        ImeShiftCapsLockIndicatorActiveColor
    } else {
        imeSecondaryHintColor()
    }

@Composable
internal fun ImeShiftKeyCap(
    shiftEnabled: Boolean,
    capsLockEnabled: Boolean,
    onShortTap: () -> Unit,
    onLongPress: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val visualState = resolveImeShiftVisualState(shiftEnabled, capsLockEnabled)
    val interactionSource = remember { MutableInteractionSource() }
    val context = LocalContext.current
    val cornerRadius = FrostDimens.rectangleButtonCornerRadius(context)

    Box(
        modifier = modifier
            .fillMaxSize()
            .graphicsLayer { clip = false },
    ) {
        FrostButton(
            onClick = null,
            modifier = Modifier
                .fillMaxSize()
                .imeShiftKeyGestures(
                    interactionSource = interactionSource,
                    onShortTap = {
                        FrostUiClickSoundRegistry.playClick()
                        onShortTap()
                    },
                    onLongPress = {
                        FrostUiClickSoundRegistry.playClick()
                        onLongPress()
                    },
                ),
            variant = FrostButtonVariant.LIGHT,
            shape = FrostButtonShape.RECTANGLE,
            lightToneLocalizedBorder = false,
            interactionSource = interactionSource,
            playClickSound = false,
            horizontalPadding = 0.dp,
        ) {
            ImeShiftKeyIcon(visualState = visualState)
        }
        val dotSize = imeKeyShiftCapsIndicatorSize()
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .offset(
                    x = dotSize / 2 - cornerRadius,
                    y = cornerRadius - dotSize / 2,
                )
                .size(dotSize)
                .background(
                    imeShiftCapsLockIndicatorColor(visualState == ImeShiftVisualState.Lock),
                    CircleShape,
                ),
        )
    }
}
