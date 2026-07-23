package com.lasercyber.lws.ime.compose

import org.junit.Assert.assertEquals
import org.junit.Test

class ImeKeyGesturesTest {

    @Test
    fun selectionIndexForX_mapsThreeZonesAcrossKeyWidth() {
        assertEquals(0, selectionIndexForX(50f, keyWidthPx = 300, optionCount = 3))
        assertEquals(1, selectionIndexForX(150f, keyWidthPx = 300, optionCount = 3))
        assertEquals(2, selectionIndexForX(250f, keyWidthPx = 300, optionCount = 3))
    }

    @Test
    fun selectionIndexForX_mapsTwoZonesForCommaPopup() {
        assertEquals(0, selectionIndexForX(40f, keyWidthPx = 200, optionCount = 2))
        assertEquals(1, selectionIndexForX(160f, keyWidthPx = 200, optionCount = 2))
    }
}
