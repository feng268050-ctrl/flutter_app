package com.lasercyber.lws.ime.compose

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.lasercyber.lws.frostui.border.BorderGradientCenter
import com.lasercyber.lws.frostui.border.frostPanelBorder
import com.lasercyber.lws.frostui.border.frostPanelFill
import com.lasercyber.lws.frostui.button.FrostButton
import com.lasercyber.lws.frostui.button.FrostButtonShape
import com.lasercyber.lws.frostui.button.FrostButtonVariant

private val PopupShape = RoundedCornerShape(12.dp)
private val PopupCornerRadius = 12.dp

@Composable
fun ImeAlternatePopup(
    options: List<String>,
    selectedIndex: Int,
    modifier: Modifier = Modifier,
) {
    if (options.isEmpty()) {
        return
    }
    val keyGap = imeKeyGap()
    val keyMinHeight = imeKeyMinHeight()
    val textSize = imeKeyAlternatePopupTextSize()
    val lightTextColor = imeDefaultTextColor()
    Row(
        horizontalArrangement = Arrangement.spacedBy(keyGap),
        modifier = modifier
            .clip(PopupShape)
            .frostPanelFill(solid = true, cornerRadius = PopupCornerRadius)
            .frostPanelBorder(
                gradientCenter = BorderGradientCenter.LEFT_RIGHT,
                cornerRadius = PopupCornerRadius,
            )
            .padding(horizontal = 10.dp, vertical = 8.dp),
    ) {
        options.forEachIndexed { index, label ->
            val selected = index == selectedIndex
            FrostButton(
                onClick = null,
                modifier = Modifier.defaultMinSize(minWidth = keyMinHeight, minHeight = keyMinHeight),
                variant = if (selected) {
                    FrostButtonVariant.PRIMARY
                } else {
                    FrostButtonVariant.LIGHT
                },
                shape = FrostButtonShape.RECTANGLE,
                lightToneLocalizedBorder = false,
                horizontalPadding = 0.dp,
                playClickSound = false,
            ) {
                Text(
                    text = label,
                    color = if (selected) Color.White else lightTextColor,
                    fontSize = textSize,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                )
            }
        }
    }
}
