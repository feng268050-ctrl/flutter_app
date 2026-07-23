package com.lasercyber.lws.frostui.clock

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test
import java.util.Calendar

class FrostHomeClockMinuteKeyTest {

    @Test
    fun minuteKey_changesOnlyWhenMinuteChanges() {
        val calendar = Calendar.getInstance().apply {
            set(2026, Calendar.JUNE, 15, 10, 30, 5)
        }
        val keyAtSecond5 = minuteKey(calendar.timeInMillis)
        calendar.set(Calendar.SECOND, 59)
        val keyAtSecond59 = minuteKey(calendar.timeInMillis)
        assertEquals(keyAtSecond5, keyAtSecond59)

        calendar.add(Calendar.MINUTE, 1)
        val keyNextMinute = minuteKey(calendar.timeInMillis)
        assertNotEquals(keyAtSecond5, keyNextMinute)
    }

    private fun minuteKey(millis: Long): Int {
        val calendar = Calendar.getInstance().apply { timeInMillis = millis }
        return calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
    }
}
