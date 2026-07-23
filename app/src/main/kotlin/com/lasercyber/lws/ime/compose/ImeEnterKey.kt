package com.lasercyber.lws.ime.compose

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.lasercyber.lws.frostui.border.FrostColors
import com.lasercyber.lws.frostui.button.FrostButton
import com.lasercyber.lws.frostui.button.FrostButtonShape
import com.lasercyber.lws.frostui.button.FrostButtonVariant
import com.lasercyber.lws.ime.engine.ImeEnterKeyConfig
import com.lasercyber.lws.ime.engine.ImeEnterKeyDisplay

@Composable
fun ImeEnterKey(
    config: ImeEnterKeyConfig,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    FrostButton(
        onClick = onClick,
        modifier = modifier.fillMaxSize(),
        variant = FrostButtonVariant.PRIMARY,
        shape = FrostButtonShape.RECTANGLE,
        enabled = enabled,
        horizontalPadding = 0.dp,
    ) {
        when (val display = config.display) {
            is ImeEnterKeyDisplay.Text -> {
                Text(
                    text = display.label,
                    color = imePrimaryTextColor(),
                    fontSize = imeKeyEnterTextSize(),
                    fontWeight = FontWeight.SemiBold,
                )
            }
            is ImeEnterKeyDisplay.Icon -> {
                Icon(
                    painter = painterResource(display.iconRes),
                    contentDescription = display.contentDescription,
                    tint = imePrimaryTextColor(),
                    modifier = Modifier.size(imeKeyEnterIconSize()),
                )
            }
            is ImeEnterKeyDisplay.TextAndIcon -> {
                ImeEnterKeyLabelWithEndIcon(
                    label = display.label,
                    iconRes = display.iconRes,
                    contentDescription = display.contentDescription,
                )
            }
            ImeEnterKeyDisplay.Default -> {
                ImeEnterKeyIcon(
                    modifier = Modifier.size(imeKeyEnterIconSize()),
                )
            }
        }
    }
}

@Composable
private fun ImeEnterKeyLabelWithEndIcon(
    label: String,
    iconRes: Int,
    contentDescription: String?,
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            color = imePrimaryTextColor(),
            fontSize = imeKeyEnterTextSize(),
            fontWeight = FontWeight.SemiBold,
        )
        Icon(
            painter = painterResource(iconRes),
            contentDescription = contentDescription,
            tint = imePrimaryTextColor(),
            modifier = Modifier.size(imeKeyEnterIconSize()),
        )
    }
}

@Composable
internal fun imePrimaryTextColor() = FrostColors.textPrimary(LocalContext.current)
