package com.lasercyber.lws.ime.compose

import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupProperties
import com.lasercyber.lws.frostui.border.FrostColors
import com.lasercyber.lws.frostui.button.FrostButton
import com.lasercyber.lws.frostui.button.FrostButtonShape
import com.lasercyber.lws.frostui.button.FrostButtonVariant
import com.lasercyber.lws.frostui.common.FrostUiClickSoundRegistry
import com.lasercyber.lws.ime.keyboard.KeyDef
import com.lasercyber.lws.ime.keyboard.KeyId
import com.lasercyber.lws.ime.keyboard.KeyboardController
import com.lasercyber.lws.ime.keyboard.popupOptions
import com.lasercyber.lws.ime.keyboard.supportsAlternatePopup
import com.lasercyber.lws.ime.keyboard.usesSingleAccentKeycap

private val AlternatePopupOffsetAboveKey = 56.dp

@Composable
fun ImeKeyCap(
    key: KeyDef,
    controller: KeyboardController,
    modifier: Modifier = Modifier,
    displayPrimary: String = controller.resolvePrimary(key),
) {
    var popupVisible by remember(key) { mutableStateOf(false) }
    var popupSelection by remember(key) { mutableIntStateOf(defaultPopupIndex(2)) }
    var keyWidthPx by remember(key) { mutableIntStateOf(0) }
    val popupOptions = remember(key) { key.popupOptions() }
    val hasAlternatePopup = key.supportsAlternatePopup()
    val interactionSource = remember(key) { MutableInteractionSource() }
    val density = LocalDensity.current
    val primaryTextSize = imeKeyPrimaryTextSize()
    val secondaryHintTextSize = imeKeySecondaryHintTextSize()

    if (key.id == KeyId.Enter) {
        ImeEnterKey(
            config = controller.enterKey,
            onClick = { controller.handleKey(key) },
            modifier = modifier.fillMaxSize(),
        )
        return
    }

    if (key.id == KeyId.Shift) {
        ImeShiftKeyCap(
            shiftEnabled = controller.shiftEnabled,
            capsLockEnabled = controller.capsLockEnabled,
            onShortTap = { controller.handleKey(key) },
            onLongPress = { controller.handleShiftLongPress() },
            modifier = modifier,
        )
        return
    }

    if (key.usesSingleAccentKeycap(controller.activeKind)) {
        FrostButton(
            text = displayPrimary,
            onClick = { controller.handleKey(key) },
            modifier = modifier.fillMaxSize(),
            variant = FrostButtonVariant.LIGHT,
            shape = FrostButtonShape.RECTANGLE,
            lightToneLocalizedBorder = false,
            horizontalPadding = 0.dp,
            textColorOverride = imeShiftActiveColor(),
            textSize = primaryTextSize,
        )
        return
    }

    if (!hasAlternatePopup) {
        if (showSecondaryHint(key)) {
            FrostButton(
                onClick = { controller.handleKey(key) },
                modifier = modifier.fillMaxSize(),
                variant = FrostButtonVariant.LIGHT,
                shape = FrostButtonShape.RECTANGLE,
                lightToneLocalizedBorder = false,
                horizontalPadding = 0.dp,
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = key.secondary.orEmpty(),
                        color = imeSecondaryHintColor(),
                        fontSize = secondaryHintTextSize,
                        lineHeight = secondaryHintTextSize,
                        textAlign = TextAlign.Center,
                    )
                    Text(
                        text = displayPrimary,
                        color = imeDefaultTextColor(),
                        textAlign = TextAlign.Center,
                        fontSize = primaryTextSize,
                        lineHeight = primaryTextSize,
                    )
                }
            }
        } else {
            FrostButton(
                text = displayPrimary,
                onClick = { controller.handleKey(key) },
                modifier = modifier.fillMaxSize(),
                variant = FrostButtonVariant.LIGHT,
                shape = FrostButtonShape.RECTANGLE,
                lightToneLocalizedBorder = false,
                horizontalPadding = 0.dp,
                textColorOverride = imeDefaultTextColor(),
                textSize = primaryTextSize,
            )
        }
        return
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .graphicsLayer { clip = false },
    ) {
        FrostButton(
            onClick = null,
            modifier = Modifier
                .fillMaxSize()
                .onSizeChanged { keyWidthPx = it.width }
                .imeAlternateKeyGestures(
                    interactionSource = interactionSource,
                    keyWidthPx = keyWidthPx,
                    optionCount = popupOptions.size,
                    onShortTap = {
                        FrostUiClickSoundRegistry.playClick()
                        controller.handleKey(key)
                    },
                    onPopupShown = {
                        popupSelection = defaultPopupIndex(popupOptions.size)
                        popupVisible = true
                    },
                    onSelectionChange = { popupSelection = it },
                    onPopupCommit = { index ->
                        FrostUiClickSoundRegistry.playClick()
                        controller.commitPopupIndex(key, index)
                    },
                    onPopupDismiss = { popupVisible = false },
                ),
            variant = FrostButtonVariant.LIGHT,
            shape = FrostButtonShape.RECTANGLE,
            lightToneLocalizedBorder = false,
            interactionSource = interactionSource,
            playClickSound = false,
            horizontalPadding = 0.dp,
        ) {
            when {
                showSecondaryHint(key) -> {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Text(
                            text = key.secondary.orEmpty(),
                            color = imeSecondaryHintColor(),
                            fontSize = secondaryHintTextSize,
                            lineHeight = secondaryHintTextSize,
                            textAlign = TextAlign.Center,
                        )
                        Text(
                            text = displayPrimary,
                            color = imeDefaultTextColor(),
                            textAlign = TextAlign.Center,
                            fontSize = primaryTextSize,
                            lineHeight = primaryTextSize,
                        )
                    }
                }
                else -> {
                    Text(
                        text = displayPrimary,
                        color = imeDefaultTextColor(),
                        textAlign = TextAlign.Center,
                        fontSize = primaryTextSize,
                    )
                }
            }
        }

        if (popupVisible) {
            Popup(
                alignment = Alignment.TopCenter,
                offset = IntOffset(
                    x = 0,
                    y = with(density) { -AlternatePopupOffsetAboveKey.roundToPx() },
                ),
                onDismissRequest = { popupVisible = false },
                properties = PopupProperties(
                    focusable = false,
                    dismissOnBackPress = false,
                    dismissOnClickOutside = false,
                ),
            ) {
                ImeAlternatePopup(
                    options = popupOptions,
                    selectedIndex = popupSelection,
                )
            }
        }
    }
}

@Composable
internal fun imeDefaultTextColor() = FrostColors.textPrimary(LocalContext.current)

@Composable
internal fun imeSecondaryHintColor() = FrostColors.textSecondary(LocalContext.current)

@Composable
internal fun imeShiftActiveColor() = FrostColors.buttonPrimaryAccent(LocalContext.current)

private fun showSecondaryHint(key: KeyDef): Boolean =
    !key.secondary.isNullOrEmpty() && (key.isLetter || key.id == KeyId.CommaPeriod)
