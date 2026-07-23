package com.lasercyber.lws.ime.engine.pinyin

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PinyinLookupTest {

    @After
    fun tearDown() {
        PinyinDictionary.resetForTests()
    }

    @Test
    fun lookup_exactPhraseMatch() {
        val lookup = PinyinLookup(
            phrases = mapOf("zhongwen" to listOf("中文")),
            syllables = mapOf("zhong" to listOf("中"), "wen" to listOf("文")),
        )
        assertEquals(listOf("中文"), lookup.lookup("zhongwen"))
    }

    @Test
    fun lookup_phrasePrefixMatch() {
        val lookup = PinyinLookup(
            phrases = mapOf("buxiugang" to listOf("不锈钢")),
            syllables = mapOf(
                "bu" to listOf("不"),
                "xiu" to listOf("锈"),
                "gang" to listOf("钢"),
            ),
        )
        assertTrue(lookup.lookup("buxiug").contains("不锈钢"))
    }

    @Test
    fun lookup_ignoresApostropheInRawInput() {
        val lookup = PinyinLookup(
            phrases = mapOf("zhongwen" to listOf("中文")),
            syllables = emptyMap(),
        )
        assertEquals(listOf("中文"), lookup.lookup("zhong'wen"))
    }

    @Test
    fun lookup_combinesSegmentedSyllables() {
        val lookup = PinyinLookup(
            phrases = emptyMap(),
            syllables = mapOf(
                "zhong" to listOf("中"),
                "wen" to listOf("文"),
            ),
        )
        assertEquals(listOf("中文"), lookup.lookup("zhongwen"))
    }

    @Test
    fun dictionary_installForTests_isUsedByCompositionLookup() {
        PinyinDictionary.installForTests(
            phrases = mapOf("buxiugang" to listOf("不锈钢")),
            syllables = mapOf("bu" to listOf("不"), "xiu" to listOf("锈"), "gang" to listOf("钢")),
        )
        assertTrue(PinyinDictionary.lookup("buxiugang").contains("不锈钢"))
    }
}
