package com.lasercyber.lws.ui.activitys.engineer.mode.ui;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.enums.AlarmCodeEnums;
import com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodeController;
import com.lasercyber.lws.ui.common.handler.LensHeavyContaminationWarnAlarm;
import com.lasercyber.lws.ui.common.settings.DangerousOperationsSettings;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;

public class LaserEnableAlarmGuardTest {

    @Before
    @After
    public void reset() {
        DangerousOperationsSettings.resetForTest();
        LensHeavyContaminationWarnAlarm.INSTANCE.resetForStop();
        WarnEpisodeController.resetForTest();
    }

    @Test
    public void gasBlocksByDefault() {
        DeviceStatus status = new DeviceStatus();
        status.setControlCardAlarmSeg1(1);
        assertTrue(LaserEnableAlarmGuard.isGasBlocking(null, status));
    }

    @Test
    public void gasBypassWhenToggleOn() {
        DeviceStatus status = new DeviceStatus();
        status.setControlCardAlarmSeg1(1);
        DangerousOperationsSettings.setOverridesForTest(null, true, null);
        assertFalse(LaserEnableAlarmGuard.isGasBlocking(null, status));
    }

    @Test
    public void lensBlocksByDefault() {
        LensHeavyContaminationWarnAlarm.INSTANCE.armPendingForTest();
        assertTrue(LaserEnableAlarmGuard.isLensBlocking(null));
    }

    @Test
    public void workBlockedWhenAnyGuardActive() {
        DeviceStatus status = new DeviceStatus();
        status.setControlCardAlarmSeg1(1);
        assertTrue(LaserEnableAlarmGuard.isWorkBlocked(null, status));
    }

    @Test
    public void workNotBlockedWhenGasBypassOn() {
        DeviceStatus status = new DeviceStatus();
        status.setControlCardAlarmSeg1(1);
        DangerousOperationsSettings.setOverridesForTest(null, true, null);
        assertFalse(LaserEnableAlarmGuard.isWorkBlocked(null, status));
    }

    @Test
    public void findFirstBlockingOtherCodedWarnWhenDemoArmed() {
        WarnEpisodeController.armDemoEpisode(AlarmCodeEnums.E006.errorCode);
        assertTrue(LaserEnableAlarmGuard.isOtherCodedWarnBlocking());
        assertEquals(AlarmCodeEnums.E006, LaserEnableAlarmGuard.findFirstBlockingOtherCodedWarn());
    }

    @Test
    public void otherCodedAlarmBlocksWhenDemoArmed() {
        WarnEpisodeController.armDemoEpisode(AlarmCodeEnums.E006.errorCode);
        assertTrue(LaserEnableAlarmGuard.isOtherCodedWarnBlocking());
        assertTrue(LaserEnableAlarmGuard.isWorkBlocked(null, null));
    }

    @Test
    public void readyIndicatorBlockedWhenOtherCodedAlarmSticky() {
        WarnEpisodeController.armDemoEpisode(AlarmCodeEnums.E006.errorCode);
        assertTrue(LaserEnableAlarmGuard.isReadyIndicatorBlocked(null, null));
    }

    @Test
    public void readyIndicatorStillBlockedWhenKeepLaserOnWhileAlarmedOn() {
        WarnEpisodeController.armDemoEpisode(AlarmCodeEnums.E006.errorCode);
        DangerousOperationsSettings.setOverridesForTest(null, null, null, true);
        assertTrue(LaserEnableAlarmGuard.isReadyIndicatorBlocked(null, null));
        assertFalse(LaserEnableAlarmGuard.isWorkBlocked(null, null));
    }

    @Test
    public void otherCodedAlarmDoesNotBlockWhenKeepLaserOnWhileAlarmedOn() {
        WarnEpisodeController.armDemoEpisode(AlarmCodeEnums.E006.errorCode);
        DangerousOperationsSettings.setOverridesForTest(null, null, null, true);
        assertTrue(LaserEnableAlarmGuard.isOtherCodedWarnBlocking());
        assertFalse(LaserEnableAlarmGuard.isWorkBlocked(null, null));
    }

    @Test
    public void keepLaserOnWhileAlarmedDoesNotBypassPreflightGasBlock() {
        DeviceStatus status = new DeviceStatus();
        status.setControlCardAlarmSeg1(1);
        DangerousOperationsSettings.setOverridesForTest(null, null, null, true);
        assertTrue(LaserEnableAlarmGuard.isGasBlocking(null, status));
    }

    @Test
    public void cameraDemoStickyBlocksWhenBypassOff() {
        WarnEpisodeController.armDemoEpisode(AlarmCodeEnums.C002.errorCode);
        DangerousOperationsSettings.setOverridesForTest(false, null, null);
        assertTrue(LaserEnableAlarmGuard.isCameraBlocking(null));
        assertTrue(LaserEnableAlarmGuard.isWorkBlocked(null, null));
    }

    @Test
    public void cameraDemoStickyNotBlockedWhenBypassOn() {
        WarnEpisodeController.armDemoEpisode(AlarmCodeEnums.C002.errorCode);
        DangerousOperationsSettings.setOverridesForTest(true, null, null);
        assertFalse(LaserEnableAlarmGuard.isCameraBlocking(null));
        assertFalse(LaserEnableAlarmGuard.isWorkBlocked(null, null));
    }

    @Test
    public void shouldInterruptOnlyForKnownCodes() {
        assertTrue(LaserEnableAlarmGuard.shouldInterruptLaserForErrorCode("E006"));
        assertFalse(LaserEnableAlarmGuard.shouldInterruptLaserForErrorCode(null));
        assertFalse(LaserEnableAlarmGuard.shouldInterruptLaserForErrorCode(""));
        assertFalse(LaserEnableAlarmGuard.shouldInterruptLaserForErrorCode("UNKNOWN"));
    }

    @Test
    public void bypassableCodesIncludeFeederAlarms() {
        assertTrue(LaserEnableAlarmGuard.isBypassableAlarmCode(AlarmCodeEnums.A001.errorCode));
        assertTrue(LaserEnableAlarmGuard.isBypassableAlarmCode(AlarmCodeEnums.C002.errorCode));
        assertTrue(LaserEnableAlarmGuard.isBypassableAlarmCode(AlarmCodeEnums.L001.errorCode));
        assertTrue(LaserEnableAlarmGuard.isBypassableAlarmCode(AlarmCodeEnums.W001.errorCode));
        assertTrue(LaserEnableAlarmGuard.isBypassableAlarmCode(AlarmCodeEnums.W002.errorCode));
        assertFalse(LaserEnableAlarmGuard.isBypassableAlarmCode(AlarmCodeEnums.E006.errorCode));
    }

    @Test
    public void feederBlocksByDefault() {
        DeviceStatus status = new DeviceStatus();
        status.setWireFeederAlarmSeg1(1);
        assertTrue(LaserEnableAlarmGuard.isFeederBlocking(null, status));
    }

    @Test
    public void feederBypassWhenToggleOn() {
        DeviceStatus status = new DeviceStatus();
        status.setWireFeederAlarmSeg1(1);
        DangerousOperationsSettings.setOverridesForTest(null, null, null, true, null);
        assertFalse(LaserEnableAlarmGuard.isFeederBlocking(null, status));
        assertFalse(LaserEnableAlarmGuard.isWorkBlocked(null, status));
    }

    @Test
    public void feederDemoStickyBlocksWhenBypassOff() {
        WarnEpisodeController.armDemoEpisode(AlarmCodeEnums.W001.errorCode);
        DangerousOperationsSettings.setOverridesForTest(null, null, null, false, null);
        assertTrue(LaserEnableAlarmGuard.isFeederBlocking(null, null));
        assertTrue(LaserEnableAlarmGuard.isWorkBlocked(null, null));
    }

    @Test
    public void feederDemoStickyNotBlockedWhenBypassOn() {
        WarnEpisodeController.armDemoEpisode(AlarmCodeEnums.W001.errorCode);
        DangerousOperationsSettings.setOverridesForTest(null, null, null, true, null);
        assertFalse(LaserEnableAlarmGuard.isFeederBlocking(null, null));
        assertFalse(LaserEnableAlarmGuard.isWorkBlocked(null, null));
    }
}
