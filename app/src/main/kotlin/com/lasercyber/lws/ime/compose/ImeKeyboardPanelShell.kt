package com.lasercyber.lws.ime.compose

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import com.lasercyber.lws.frostui.border.BorderGradientCenter
import com.lasercyber.lws.frostui.border.PanelBorderPainter
import com.lasercyber.lws.ui.R

@Composable
internal fun imeKeyboardPanelHeight(): Dp {
    val context = LocalContext.current
    return with(LocalDensity.current) {
        context.resources.getDimension(R.dimen.ime_keyboard_height).toDp()
    }
}

@Composable
internal fun imeKeyGap(): Dp {
    val context = LocalContext.current
    return with(LocalDensity.current) {
        context.resources.getDimension(R.dimen.ime_key_gap).toDp()
    }
}

@Composable
internal fun imeKeyPrimaryTextSize(): TextUnit {
    val context = LocalContext.current
    return with(LocalDensity.current) {
        context.resources.getDimension(R.dimen.ime_key_primary_text_size).toSp()
    }
}

@Composable
internal fun imeKeySecondaryHintTextSize(): TextUnit {
    val context = LocalContext.current
    return with(LocalDensity.current) {
        context.resources.getDimension(R.dimen.ime_key_secondary_hint_text_size).toSp()
    }
}

@Composable
internal fun imeKeyShiftIconWidth(): Dp {
    val context = LocalContext.current
    return with(LocalDensity.current) {
        context.resources.getDimension(R.dimen.ime_key_shift_icon_width).toDp()
    }
}

@Composable
internal fun imeKeyShiftIconHeight(): Dp {
    val context = LocalContext.current
    return with(LocalDensity.current) {
        context.resources.getDimension(R.dimen.ime_key_shift_icon_height).toDp()
    }
}

@Composable
internal fun imeKeyShiftCapsIndicatorSize(): Dp {
    val context = LocalContext.current
    return with(LocalDensity.current) {
        context.resources.getDimension(R.dimen.ime_key_shift_caps_indicator_size).toDp()
    }
}

@Composable
internal fun imeKeyShiftCapsLabelTextSize(): TextUnit {
    val context = LocalContext.current
    return with(LocalDensity.current) {
        context.resources.getDimension(R.dimen.ime_key_shift_caps_label_text_size).toSp()
    }
}

@Composable
internal fun imeKeyEnterTextSize(): TextUnit {
    val context = LocalContext.current
    return with(LocalDensity.current) {
        context.resources.getDimension(R.dimen.ime_key_enter_text_size).toSp()
    }
}

@Composable
internal fun imeKeyEnterIconSize(): Dp {
    val context = LocalContext.current
    return with(LocalDensity.current) {
        context.resources.getDimension(R.dimen.ime_key_enter_icon_size).toDp()
    }
}

@Composable
internal fun imeKeyAlternatePopupTextSize(): TextUnit {
    val context = LocalContext.current
    return with(LocalDensity.current) {
        context.resources.getDimension(R.dimen.ime_key_alternate_popup_text_size).toSp()
    }
}

@Composable
internal fun imeKeyMinHeight(): Dp {
    val context = LocalContext.current
    return with(LocalDensity.current) {
        context.resources.getDimension(R.dimen.ime_key_min_height).toDp()
    }
}

/** Shared chrome: transparent panel over [ImeKeyboardBackdropHost]; unified [imeKeyGap] spacing. */
@Composable
internal fun ImeKeyboardPanelShell(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    val context = LocalContext.current
    val topBorderSpec = remember(context) {
        PanelBorderPainter.cardBorderSpec(
            context = context,
            gradientCenter = BorderGradientCenter.TOP_BOTTOM,
            cornerRadiusPx = 0f,
        )
    }
    val keyGap = imeKeyGap()
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(imeKeyboardPanelHeight())
            .graphicsLayer { clip = false }
            .drawBehind {
                with(PanelBorderPainter) {
                    drawPanelTopEdgeBorder(topBorderSpec)
                }
            },
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(keyGap),
            verticalArrangement = Arrangement.spacedBy(keyGap),
            content = content,
        )
    }
}

@Composable
internal fun ImeKeyboardKeyRow(
    controller: com.lasercyber.lws.ime.keyboard.KeyboardController,
    row: com.lasercyber.lws.ime.keyboard.KeyboardRow,
    modifier: Modifier = Modifier,
) {
    val keyGap = imeKeyGap()
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(keyGap),
    ) {
        if (row.leadingInsetWeight > 0f) {
            Spacer(modifier = Modifier.weight(row.leadingInsetWeight))
        }
        row.keys.forEach { key ->
            ImeKeyCap(
                key = key,
                controller = controller,
                modifier = Modifier
                    .weight(key.widthWeight)
                    .fillMaxHeight(),
            )
        }
        if (row.trailingInsetWeight > 0f) {
            Spacer(modifier = Modifier.weight(row.trailingInsetWeight))
        }
    }
}
