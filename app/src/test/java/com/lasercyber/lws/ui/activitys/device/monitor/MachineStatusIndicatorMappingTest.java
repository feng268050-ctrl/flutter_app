package com.lasercyber.lws.ui.activitys.device.monitor;

import com.lasercyber.lws.frostui.control.FrostStatusState;

import org.junit.Assert;
import org.junit.Test;

public class MachineStatusIndicatorMappingTest {

    @Test
    public void onOffMapsToSuccessAndIdleNotFailure() {
        Assert.assertEquals(FrostStatusState.Success, MachineStatusIndicatorMapping.fromOnOff(true));
        Assert.assertEquals(FrostStatusState.Idle, MachineStatusIndicatorMapping.fromOnOff(false));
    }
}
