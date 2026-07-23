package com.lasercyber.lws.ime.compose

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import com.lasercyber.lws.ime.keyboard.KeyboardController
import com.lasercyber.lws.ime.keyboard.KeyboardKind
import com.lasercyber.lws.ime.keyboard.KeyboardLanguageSelector
import com.lasercyber.lws.ime.keyboard.KeyboardRow

@Composable
fun ImeKeyboardPanel(
    controller: KeyboardController,
    modifier: Modifier = Modifier,
) {
    ObserveImeLanguageKind(controller)
    ImeKeyboardPanelShell(modifier = modifier) {
        if (KeyboardLanguageSelector.isChineseGlobalEnabled() &&
            controller.activeKind == KeyboardKind.ChineseGlobal
        ) {
            ImePinyinCandidateBar(controller = controller)
        }
        controller.layout.rows.forEach { row ->
            ImeKeyboardRow(
                controller = controller,
                row = row,
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(row.heightWeight)
                    .graphicsLayer { clip = false },
            )
        }
    }
}

@Composable
private fun ImeKeyboardRow(
    controller: KeyboardController,
    row: KeyboardRow,
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
