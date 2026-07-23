package com.lasercyber.lws.ime.engine.pinyin

import android.content.Context
import java.util.Locale

object PinyinDictionary {
    private val EMPTY_LOOKUP = PinyinLookup(emptyMap(), emptyMap())

    @Volatile
    private var lookup: PinyinLookup = EMPTY_LOOKUP

    @Volatile
    private var loaded = false

    fun ensureLoaded(context: Context) {
        if (loaded) {
            return
        }
        synchronized(this) {
            if (loaded) {
                return
            }
            lookup = loadFromAssets(context.applicationContext)
            loaded = true
        }
    }

    fun lookup(raw: String): List<String> = lookup.lookup(raw)

    internal fun installForTests(
        phrases: Map<String, List<String>> = emptyMap(),
        syllables: Map<String, List<String>> = emptyMap(),
    ) {
        lookup = PinyinLookup(phrases, syllables)
        loaded = true
    }

    internal fun resetForTests() {
        lookup = EMPTY_LOOKUP
        loaded = false
    }

    private fun loadFromAssets(context: Context): PinyinLookup {
        val phrases = loadTable(context, "ime/pinyin_phrases.tsv")
        val syllables = loadTable(context, "ime/pinyin_syllables.tsv")
        return PinyinLookup(phrases, syllables)
    }

    private fun loadTable(context: Context, assetPath: String): Map<String, List<String>> {
        val entries = linkedMapOf<String, MutableList<String>>()
        context.assets.open(assetPath).bufferedReader().useLines { lines ->
            lines.forEach { line ->
                val trimmed = line.trim()
                if (trimmed.isEmpty() || trimmed.startsWith("#")) {
                    return@forEach
                }
                val parts = trimmed.split('\t')
                if (parts.size < 2) {
                    return@forEach
                }
                val key = parts[0].lowercase(Locale.ROOT).replace("'", "")
                val values = parts.drop(1).filter { it.isNotEmpty() }
                if (key.isEmpty() || values.isEmpty()) {
                    return@forEach
                }
                entries.getOrPut(key) { mutableListOf() }.addAll(values)
            }
        }
        return entries
    }
}
