package com.lasercyber.lws.ime.engine.pinyin

import java.util.Locale

/** Prefix-based pinyin lookup over phrase and syllable tables. */
class PinyinLookup(
    phrases: Map<String, List<String>>,
    syllables: Map<String, List<String>>,
) {
    private val phrases = phrases.mapValues { it.value.distinct() }
    private val syllables = syllables.mapValues { it.value.distinct() }

    fun lookup(raw: String): List<String> {
        if (raw.isEmpty()) {
            return emptyList()
        }
        val normalized = raw.lowercase(Locale.ROOT).replace("'", "")
        if (normalized.isEmpty()) {
            return emptyList()
        }

        val results = LinkedHashSet<String>()

        phrases[normalized]?.let { results.addAll(it) }

        phrases.entries
            .asSequence()
            .filter { (key, _) -> key.startsWith(normalized) && key != normalized }
            .sortedBy { it.key.length }
            .forEach { results.addAll(it.value) }

        syllables[normalized]?.let { results.addAll(it) }

        segmentSyllables(normalized)?.let { segments ->
            if (segments.isNotEmpty()) {
                val combined = segments.mapNotNull { syllables[it]?.firstOrNull() }
                if (combined.size == segments.size) {
                    results.add(combined.joinToString(""))
                }
            }
        }

        val tailStart = incompleteSyllableStart(normalized)
        val tail = normalized.substring(tailStart)
        if (tail.isNotEmpty()) {
            syllables.entries
                .asSequence()
                .filter { (key, _) -> key.startsWith(tail) && key != tail }
                .sortedBy { it.key.length }
                .take(16)
                .flatMap { it.value.asSequence().take(2) }
                .forEach { results.add(it) }
        }

        return results.take(8).toList()
    }

    private fun segmentSyllables(input: String): List<String>? {
        val result = mutableListOf<String>()
        var index = 0
        while (index < input.length) {
            val matched = longestSyllableAt(input, index) ?: return null
            result.add(matched)
            index += matched.length
        }
        return result
    }

    private fun incompleteSyllableStart(input: String): Int {
        var index = 0
        while (index < input.length) {
            val matched = longestSyllableAt(input, index) ?: return index
            index += matched.length
        }
        return input.length
    }

    private fun longestSyllableAt(input: String, start: Int): String? {
        val maxLen = minOf(6, input.length - start)
        for (len in maxLen downTo 1) {
            val part = input.substring(start, start + len)
            if (syllables.containsKey(part)) {
                return part
            }
        }
        return null
    }
}
