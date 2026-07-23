package com.lasercyber.lws.ime.compose

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.platform.LocalContext
import com.lasercyber.lws.ime.engine.pinyin.PinyinDictionary
import com.lasercyber.lws.ime.keyboard.KeyboardController
import com.lasercyber.lws.ime.keyboard.KeyboardLanguageSelector
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive

/** Polls app language so Chinese/English global keyboards hot-switch while IME is open. */
@Composable
internal fun ObserveImeLanguageKind(controller: KeyboardController) {
    val context = LocalContext.current
    LaunchedEffect(controller) {
        if (KeyboardLanguageSelector.isChineseGlobalEnabled()) {
            PinyinDictionary.ensureLoaded(context)
        }
        while (isActive) {
            controller.syncGlobalKindFromLanguage()
            delay(250)
        }
    }
}
