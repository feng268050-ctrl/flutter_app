package com.lasercyber.lws.ime.keyboard

import com.lasercyber.lws.ime.keyboard.layout.GlobalQwertyLayout
import org.junit.Assert.assertEquals
import org.junit.Test

class GlobalQwertyLayoutTest {

    @Test
    fun row2_hasHalfKeyWidthSideInsets() {
        val layout = GlobalQwertyLayout.layout(KeyboardKind.EnglishGlobal)
        val row2 = layout.rows[1]
        assertEquals(0.5f, row2.leadingInsetWeight, 0.001f)
        assertEquals(0.5f, row2.trailingInsetWeight, 0.001f)
        assertEquals(9, row2.keys.size)
    }

    @Test
    fun row1_andRow3_haveFlushEdges() {
        val layout = GlobalQwertyLayout.layout(KeyboardKind.EnglishGlobal)
        assertEquals(0f, layout.rows[0].leadingInsetWeight, 0.001f)
        assertEquals(0f, layout.rows[2].leadingInsetWeight, 0.001f)
    }
}
