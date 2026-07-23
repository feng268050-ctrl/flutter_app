package com.lasercyber.lws.ui.common.rx.modbus;

import org.junit.After;
import org.junit.Assert;
import org.junit.Test;

public class ModbusOtaExclusiveSessionTest {

    @After
    public void tearDown() {
        ModbusOtaExclusiveSession.resetForTest();
    }

    @Test
    public void transferPhase_allowsOtaWriteOnly() {
        ModbusOtaExclusiveSession.beginTransfer();
        Assert.assertNull(ModbusOtaExclusiveSession.checkBlocked(ModbusTraffic.OTA_WRITE));
        Assert.assertNotNull(ModbusOtaExclusiveSession.checkBlocked(ModbusTraffic.READ));
        Assert.assertNotNull(ModbusOtaExclusiveSession.checkBlocked(ModbusTraffic.OTA_STATUS_READ));
    }

    @Test
    public void awaitConfirmPhase_allowsOtaStatusReadOnly() {
        ModbusOtaExclusiveSession.beginAwaitConfirm();
        Assert.assertNull(ModbusOtaExclusiveSession.checkBlocked(ModbusTraffic.OTA_STATUS_READ));
        Assert.assertNotNull(ModbusOtaExclusiveSession.checkBlocked(ModbusTraffic.OTA_WRITE));
        Assert.assertNotNull(ModbusOtaExclusiveSession.checkBlocked(ModbusTraffic.READ));
    }

    @Test
    public void inactive_allowsAllTraffic() {
        Assert.assertNull(ModbusOtaExclusiveSession.checkBlocked(ModbusTraffic.READ));
        Assert.assertNull(ModbusOtaExclusiveSession.checkBlocked(ModbusTraffic.OTA_WRITE));
        Assert.assertNull(ModbusOtaExclusiveSession.checkBlocked(ModbusTraffic.OTA_STATUS_READ));
    }
}
