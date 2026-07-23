package com.lasercyber.lws.ime.engine.pinyin

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

class PinyinComposition {
    var raw by mutableStateOf("")
        private set

    var selectedIndex by mutableIntStateOf(0)
        private set

    val isComposing: Boolean
        get() = raw.isNotEmpty()

    val candidates: List<String>
        get() = if (raw.isEmpty()) emptyList() else PinyinDictionary.lookup(raw)

    fun appendLetter(letter: Char) {
        raw += letter.lowercaseChar()
        selectedIndex = 0
    }

    fun appendApostrophe() {
        if (raw.isNotEmpty() && !raw.endsWith("'")) {
            raw += "'"
            selectedIndex = 0
        }
    }

    fun deleteLast() {
        if (raw.isEmpty()) {
            return
        }
        raw = raw.dropLast(1)
        selectedIndex = 0
    }

    fun selectCandidate(index: Int) {
        if (candidates.isEmpty()) {
            return
        }
        selectedIndex = index.coerceIn(0, candidates.lastIndex)
    }

    fun clear() {
        raw = ""
        selectedIndex = 0
    }
}
