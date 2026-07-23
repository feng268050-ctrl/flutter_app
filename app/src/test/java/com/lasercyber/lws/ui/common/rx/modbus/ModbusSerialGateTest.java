package com.lasercyber.lws.ui.common.rx.modbus;

import com.lasercyber.lws.ui.common.config.ModbusConfig;

import org.junit.After;
import org.junit.Assert;
import org.junit.Before;
import org.junit.Test;

import java.util.concurrent.atomic.AtomicLong;

public class ModbusSerialGateTest {

    private final AtomicLong nowMs = new AtomicLong(0L);
    private final AtomicLong sleptMs = new AtomicLong(0L);

    @Before
    public void setUp() {
        ModbusConfig.setMockOverrideForTest(false);
        ModbusSerialGate.resetForTest();
        ModbusSerialGate.setClockForTest(
                () -> nowMs.get(),
                ms -> sleptMs.addAndGet(ms));
    }

    @After
    public void tearDown() {
        ModbusConfig.resetForTest();
        ModbusSerialGate.resetForTest();
    }

    @Test
    public void awaitBeforeCommand_waitsWhenElapsedLessThanInterval() {
        ModbusSerialGate gate = ModbusSerialGate.getInstance();
        gate.markCommandEnd();
        nowMs.set(20L);
        long waited = gate.awaitBeforeCommand();
        Assert.assertEquals(30L, waited);
        Assert.assertEquals(30L, sleptMs.get());
    }

    @Test
    public void awaitBeforeCommand_noWaitWhenIntervalSatisfied() {
        ModbusSerialGate gate = ModbusSerialGate.getInstance();
        gate.markCommandEnd();
        nowMs.set(50L);
        long waited = gate.awaitBeforeCommand();
        Assert.assertEquals(0L, waited);
        Assert.assertEquals(0L, sleptMs.get());
    }

    @Test
    public void awaitBeforeCommand_skipsSleepInMockMode() {
        ModbusConfig.setMockOverrideForTest(true);
        ModbusSerialGate gate = ModbusSerialGate.getInstance();
        gate.markCommandEnd();
        nowMs.set(10L);
        Assert.assertEquals(0L, gate.awaitBeforeCommand());
        Assert.assertEquals(0L, sleptMs.get());
    }
}
