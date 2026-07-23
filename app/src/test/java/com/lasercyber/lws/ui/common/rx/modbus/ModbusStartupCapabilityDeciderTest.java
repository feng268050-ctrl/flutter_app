package com.lasercyber.lws.ui.common.rx.modbus;

import org.junit.Assert;
import org.junit.Test;

public class ModbusStartupCapabilityDeciderTest {

    @Test
    public void shouldSkip_onEmulatorWithoutSerialDevice() {
        ModbusStartupCapabilityDecider.Decision decision =
                ModbusStartupCapabilityDecider.decide("generic/sdk/generic", "Android SDK built for x86", false);

        Assert.assertTrue(decision.shouldSkip());
        Assert.assertEquals(ModbusStartupState.REASON_EMULATOR_UNSUPPORTED, decision.reasonCode());
    }

    @Test
    public void shouldSkip_onPhysicalRuntimeWithoutSerialDevice() {
        ModbusStartupCapabilityDecider.Decision decision =
                ModbusStartupCapabilityDecider.decide("brand/device/release", "EmbeddedBoard-01", false);

        Assert.assertTrue(decision.shouldSkip());
        Assert.assertEquals(ModbusStartupState.REASON_SERIAL_PORT_MISSING, decision.reasonCode());
    }

    @Test
    public void shouldNotSkip_whenSerialDeviceExists() {
        ModbusStartupCapabilityDecider.Decision decision =
                ModbusStartupCapabilityDecider.decide("brand/device/release", "EmbeddedBoard-01", true);

        Assert.assertFalse(decision.shouldSkip());
        Assert.assertEquals(ModbusStartupState.REASON_NONE, decision.reasonCode());
    }
}
