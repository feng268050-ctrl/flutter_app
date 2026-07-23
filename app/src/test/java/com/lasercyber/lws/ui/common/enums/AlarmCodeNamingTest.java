package com.lasercyber.lws.ui.common.enums;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;

import org.junit.Test;

public class AlarmCodeNamingTest {

    @Test
    public void findByCode_resolvesThreeDigitHCode() {
        AlarmCodeEnums resolved = AlarmCodeEnums.findByCode("H022");
        assertNotNull(resolved);
        assertEquals(AlarmCodeEnums.H022, resolved);
        assertEquals("H022", resolved.errorCode);
    }

    @Test
    public void findByCode_rejectsLegacyFourDigitHCode() {
        assertNull(AlarmCodeEnums.findByCode("H0022"));
    }
}
