package com.lasercyber.lws.ui.common.handler;

import static org.junit.Assert.assertSame;

import com.lasercyber.lws.ui.common.enums.AlarmCodeEnums;

import org.junit.After;
import org.junit.Test;

public class ExternalWarnAlarmRegistryTest {

    @After
    public void reset() {
        ExternalWarnAlarmRegistry.resetForTest();
    }

    @Test
    public void forCode_resolvesC002() {
        assertSame(
                CameraCommunicationWarnAlarm.INSTANCE,
                ExternalWarnAlarmRegistry.forCode(AlarmCodeEnums.C002.errorCode));
    }
}
