package com.lasercyber.lws.ui.bean.entity;

import org.junit.Assert;
import org.junit.Test;

public class DeviceDataPumpGaugeTest {

    @Test
    @SuppressWarnings("deprecation")
    public void pumpGaugeCurrentUsesLaserCurrentRegisterRaw() {
        DeviceData data = new DeviceData();
        data.setLaserCurrent(450);
        data.setPumpSourceCurrent(999);

        Assert.assertEquals(Integer.valueOf(450), data.getPumpGaugeCurrentRaw());
        Assert.assertEquals(45d, data.getPumpGaugeCurrentAmps(), 0.0001);
        Assert.assertEquals(Integer.valueOf(999), data.getPumpSourceCurrent());
    }
}
