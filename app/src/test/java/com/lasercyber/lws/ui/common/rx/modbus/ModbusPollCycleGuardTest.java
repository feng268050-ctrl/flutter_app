package com.lasercyber.lws.ui.common.rx.modbus;

import org.junit.Assert;
import org.junit.Test;

public class ModbusPollCycleGuardTest {

    @Test
    public void tryBegin_allowsOnlyOneCycleUntilEnd() {
        ModbusPollCycleGuard.end();
        Assert.assertTrue(ModbusPollCycleGuard.tryBegin());
        Assert.assertFalse(ModbusPollCycleGuard.tryBegin());
        ModbusPollCycleGuard.end();
        Assert.assertTrue(ModbusPollCycleGuard.tryBegin());
        ModbusPollCycleGuard.end();
    }
}
