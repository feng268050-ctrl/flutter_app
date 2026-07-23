package com.lasercyber.lws.ui.common.handler;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.constant.AlarmCodeConstants;
import com.lasercyber.lws.ui.common.settings.DangerousOperationsSettings;
import com.lasercyber.lws.ui.common.utils.WarnUtil;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;

public class WarnDialogSeverityTest {

    @Before
    @After
    public void reset() {
        DangerousOperationsSettings.resetForTest();
    }

    @Test
    public void bypassableCodesDefaultToWarnSeverity() {
        assertEquals((int) WarnUtil.WARN_TYPE, WarnDialogSeverity.dialogTypeForCode(AlarmCodeConstants.ALARM_A001, null));
        assertEquals((int) WarnUtil.WARN_TYPE, WarnDialogSeverity.dialogTypeForCode(AlarmCodeConstants.ALARM_C002, null));
        assertEquals((int) WarnUtil.WARN_TYPE, WarnDialogSeverity.dialogTypeForCode(AlarmCodeConstants.ALARM_L001, null));
        assertEquals((int) WarnUtil.WARN_TYPE, WarnDialogSeverity.dialogTypeForCode(AlarmCodeConstants.ALARM_W001, null));
        assertEquals((int) WarnUtil.WARN_TYPE, WarnDialogSeverity.dialogTypeForCode(AlarmCodeConstants.ALARM_W002, null));
    }

    @Test
    public void bypassOnDowngradesToInfoSeverity() {
        DangerousOperationsSettings.setOverridesForTest(true, true, true, true, null);
        assertEquals((int) WarnUtil.INFO_TYPE, WarnDialogSeverity.dialogTypeForCode(AlarmCodeConstants.ALARM_A001, null));
        assertEquals((int) WarnUtil.INFO_TYPE, WarnDialogSeverity.dialogTypeForCode(AlarmCodeConstants.ALARM_C002, null));
        assertEquals((int) WarnUtil.INFO_TYPE, WarnDialogSeverity.dialogTypeForCode(AlarmCodeConstants.ALARM_L001, null));
        assertEquals((int) WarnUtil.INFO_TYPE, WarnDialogSeverity.dialogTypeForCode(AlarmCodeConstants.ALARM_W001, null));
        assertEquals((int) WarnUtil.INFO_TYPE, WarnDialogSeverity.dialogTypeForCode(AlarmCodeConstants.ALARM_W002, null));
    }

    @Test
    public void nonBypassableCodeAlwaysWarnSeverity() {
        DangerousOperationsSettings.setOverridesForTest(true, true, true, true, null);
        assertEquals((int) WarnUtil.WARN_TYPE, WarnDialogSeverity.dialogTypeForCode(AlarmCodeConstants.ALARM_E006, null));
        assertTrue(WarnDialogSeverity.isWarnSeverity(AlarmCodeConstants.ALARM_E006, null));
    }

    @Test
    public void feederBypassOnlyAffectsFeederCodes() {
        DangerousOperationsSettings.setOverridesForTest(null, null, null, true, null);
        assertEquals((int) WarnUtil.INFO_TYPE, WarnDialogSeverity.dialogTypeForCode(AlarmCodeConstants.ALARM_W001, null));
        assertEquals((int) WarnUtil.WARN_TYPE, WarnDialogSeverity.dialogTypeForCode(AlarmCodeConstants.ALARM_C002, null));
    }

    @Test
    public void hasActiveWarnSeverityAlarmForModbusSegment() {
        DeviceStatus status = new DeviceStatus();
        status.setGunAlarmSeg1(1);
        assertTrue(WarnDialogSeverity.hasAnyActiveWarnSeverityAlarm(status, null));
    }

    @Test
    public void feederAlarmOffWhenBypassOn() {
        DeviceStatus status = new DeviceStatus();
        status.setWireFeederAlarmSeg1(1);
        DangerousOperationsSettings.setOverridesForTest(null, null, null, true, null);
        assertFalse(WarnDialogSeverity.hasAnyActiveWarnSeverityAlarm(status, null));
    }
}
