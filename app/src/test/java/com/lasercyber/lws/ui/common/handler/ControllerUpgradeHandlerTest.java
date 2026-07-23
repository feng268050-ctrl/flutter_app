package com.lasercyber.lws.ui.common.handler;

import com.lasercyber.lws.ui.bean.entity.DeviceStatus;

import org.junit.Assert;
import org.junit.Test;

public class ControllerUpgradeHandlerTest {

    @Test
    public void isFirmwareAlreadyCurrent_requiresNonNullVersions() {
        DeviceStatus status = new DeviceStatus();
        status.setHardwareVersion(1000);
        status.setSoftwareVersion(1014);

        Assert.assertFalse(ControllerUpgradeHandler.isFirmwareAlreadyCurrent(status, null, 1014));
        Assert.assertFalse(ControllerUpgradeHandler.isFirmwareAlreadyCurrent(status, 1000, null));
        Assert.assertFalse(ControllerUpgradeHandler.isFirmwareAlreadyCurrent(null, 1000, 1014));

        DeviceStatus missing = new DeviceStatus();
        Assert.assertFalse(ControllerUpgradeHandler.isFirmwareAlreadyCurrent(missing, 1000, 1014));
    }

    @Test
    public void isFirmwareAlreadyCurrent_matchesOnlyWhenEqual() {
        DeviceStatus status = new DeviceStatus();
        status.setHardwareVersion(1000);
        status.setSoftwareVersion(1014);

        Assert.assertTrue(ControllerUpgradeHandler.isFirmwareAlreadyCurrent(status, 1000, 1014));
        Assert.assertFalse(ControllerUpgradeHandler.isFirmwareAlreadyCurrent(status, 1000, 1015));
    }
}
