package com.lasercyber.lws.ui.common.rx.modbus;

import com.lasercyber.lws.ui.common.rx.modbus.task.RxModbusDeviceStatusAndDataPollTask;

import org.junit.After;
import org.junit.Assert;
import org.junit.Before;
import org.junit.Test;

public class ModbusPollDiscardTest {

    @Before
    public void setUp() {
        ModbusPollCycleGuard.end();
        ModbusSerialGate.resetForTest();
        ModbusPollDiagnostics.resetForTest();
        ModbusOtaExclusiveSession.resetForTest();
    }

    @After
    public void tearDown() {
        ModbusPollCycleGuard.end();
        ModbusSerialGate.resetForTest();
        ModbusOtaExclusiveSession.resetForTest();
    }

    @Test
    public void peekDiscardReason_cycleInFlight() {
        ModbusPollCycleGuard.tryBegin();
        Assert.assertEquals("cycle_in_flight", RxModbusDeviceStatusAndDataPollTask.peekDiscardReason());
        ModbusPollCycleGuard.end();
    }

    @Test
    public void peekDiscardReason_busBusy() {
        ModbusSerialGate.setCommandInFlightForTest(true);
        Assert.assertEquals("bus_busy", RxModbusDeviceStatusAndDataPollTask.peekDiscardReason());
    }

    @Test
    public void peekDiscardReason_otaActive() {
        ModbusOtaExclusiveSession.begin();
        Assert.assertEquals("ota_active", RxModbusDeviceStatusAndDataPollTask.peekDiscardReason());
    }

    @Test
    public void peekDiscardReason_idleAcquiresGuard() {
        Assert.assertNull(RxModbusDeviceStatusAndDataPollTask.peekDiscardReason());
        Assert.assertTrue(ModbusPollCycleGuard.isCycleInFlight());
        ModbusPollCycleGuard.end();
    }
}
