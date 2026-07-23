package com.lasercyber.lws.ui.common.camera;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.bean.entity.WarnTable;
import com.lasercyber.lws.ui.common.constant.AlarmCodeConstants;
import com.lasercyber.lws.ui.common.constant.WarnLevelConstant;
import com.lasercyber.lws.ui.common.handler.CameraCommunicationWarnAlarm;
import com.lasercyber.lws.ui.common.handler.RgbLedDecision;
import com.lasercyber.lws.ui.common.handler.WarnDialogSeverity;
import com.lasercyber.lws.ui.common.settings.DangerousOperationsSettings;
import com.lasercyber.lws.ui.common.utils.WarnUtil;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.LaserEnableAlarmGuard;
import com.lasercyber.lws.ui.network.http.remote.CameraRemote;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;

import java.util.List;

public class CameraCommStatusTest {

    @Before
    @After
    public void reset() {
        DangerousOperationsSettings.resetForTest();
        CameraPingHealth.getInstance().resetForTest();
        CameraDeviceInfoCache.resetForTest();
    }

    @Test
    public void isFault_whenPingUnreachable_returnsTrue() {
        CameraPingHealth.getInstance().setReachableForTest(false);
        assertTrue(CameraCommStatus.isFault());
        assertFalse(CameraCommStatus.isHealthy());
    }

    @Test
    public void isFault_whenPingReachable_returnsFalse() {
        CameraPingHealth.getInstance().setReachableForTest(true);
        assertFalse(CameraCommStatus.isFault());
        assertTrue(CameraCommStatus.isHealthy());
    }

    @Test
    public void isFault_versionDashButPingHealthy_returnsFalse() {
        CameraDeviceInfoCache.applyDisplayForTest(CameraRemote.CAMERA_VERSION_UNAVAILABLE);
        CameraPingHealth.getInstance().setReachableForTest(true);
        assertFalse(CameraCommStatus.isFault());
        assertTrue(CameraCommStatus.isHealthy());
    }

    @Test
    public void buildActiveLogRows_fault_addsC002() {
        CameraPingHealth.getInstance().setReachableForTest(false);
        List<WarnTable> list = CameraCommunicationWarnAlarm.INSTANCE.buildActiveLogRows();
        assertEquals(1, list.size());
        assertEquals(AlarmCodeConstants.ALARM_C002, list.get(0).getCode());
        assertEquals(Integer.valueOf(WarnLevelConstant.SERIOUS), list.get(0).getLevel());
    }

    @Test
    public void buildActiveLogRows_healthy_empty() {
        CameraPingHealth.getInstance().setReachableForTest(true);
        assertTrue(CameraCommunicationWarnAlarm.INSTANCE.buildActiveLogRows().isEmpty());
    }

    @Test
    public void laserEnableGuard_blocksWhenFaultAndBypassOff() {
        CameraPingHealth.getInstance().setReachableForTest(false);
        assertTrue(LaserEnableAlarmGuard.isCameraBlocking(null));
    }

    @Test
    public void c002SeverityFollowsCameraBypassToggle() {
        assertEquals((int) WarnUtil.WARN_TYPE,
                WarnDialogSeverity.dialogTypeForCode(AlarmCodeConstants.ALARM_C002, null));
        DangerousOperationsSettings.setOverridesForTest(true, null, null);
        assertEquals((int) WarnUtil.INFO_TYPE,
                WarnDialogSeverity.dialogTypeForCode(AlarmCodeConstants.ALARM_C002, null));
    }

    @Test
    public void yellowBlinksWhenCameraFaultAndBypassOff() {
        CameraPingHealth.getInstance().setReachableForTest(false);
        assertEquals(RgbLedDecision.YellowMode.BLINK, RgbLedDecision.yellowMode(null, null));
    }

    @Test
    public void yellowOffWhenCameraFaultAndBypassOn() {
        CameraPingHealth.getInstance().setReachableForTest(false);
        DangerousOperationsSettings.setOverridesForTest(true, null, null);
        assertEquals(RgbLedDecision.YellowMode.OFF, RgbLedDecision.yellowMode(null, null));
    }

    @Test
    public void laserEnableGuard_passesWhenFaultAndBypassOn() {
        CameraPingHealth.getInstance().setReachableForTest(false);
        DangerousOperationsSettings.setOverridesForTest(true, null, null);
        assertFalse(LaserEnableAlarmGuard.isCameraBlocking(null));
    }
}
