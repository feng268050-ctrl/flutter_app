package com.lasercyber.lws.ime.compose

import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import com.lasercyber.lws.frostui.border.FrostColors
import com.lasercyber.lws.ime.keyboard.KeyboardController
import com.lasercyber.lws.ime.keyboard.KeyboardKind
import com.lasercyber.lws.ui.R

private val PinyinMutedColor = Color(0xFF8E8E93)
private val CandidateDefaultColor = Color(0xFFE5E5EA)

@Composable
internal fun imePinyinBarHeight() = with(LocalDensity.current) {
    LocalContext.current.resources.getDimension(R.dimen.ime_pinyin_bar_height).toDp()
}

@Composable
internal fun imePinyinCompositionTextSize(): TextUnit = with(LocalDensity.current) {
    LocalContext.current.resources.getDimension(R.dimen.ime_pinyin_composition_text_size).toSp()
}

@Composable
internal fun imePinyinCandidateTextSize(): TextUnit = with(LocalDensity.current) {
    LocalContext.current.resources.getDimension(R.dimen.ime_pinyin_candidate_text_size).toSp()
}

@Composable
fun ImePinyinCandidateBar(
    controller: KeyboardController,
    modifier: Modifier = Modifier,
) {
    if (controller.activeKind != KeyboardKind.ChineseGlobal) {
        return
    }

    val composition = controller.pinyinComposition
    val candidates = composition.candidates
    val selectedIndex = composition.selectedIndex
    val highlightColor = imeShiftActiveColor()
    val compositionTextSize = imePinyinCompositionTextSize()
    val candidateTextSize = imePinyinCandidateTextSize()
    val scrollState = rememberScrollState()

    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(imePinyinBarHeight())
            .padding(horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = composition.raw.ifEmpty { " " },
            color = if (composition.isComposing) {
                FrostColors.textPrimary(LocalContext.current)
            } else {
                PinyinMutedColor
            },
            fontSize = compositionTextSize,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(start = 4.dp),
        )

        Row(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight()
                .horizontalScroll(scrollState),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            candidates.forEachIndexed { index, candidate ->
                val selected = index == selectedIndex
                Text(
                    text = candidate,
                    color = if (selected) highlightColor else CandidateDefaultColor,
                    fontSize = candidateTextSize,
                    fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                    maxLines = 1,
                    modifier = Modifier
                        .clickable {
                            composition.selectCandidate(index)
                            controller.commitCandidate(index)
                        }
                        .padding(vertical = 4.dp),
                )
            }
        }
    }
}
