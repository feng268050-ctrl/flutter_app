package com.lasercyber.lws.ui.common.handler;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.camera.CameraPingHealth;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.enums.AlarmCodeEnums;
import com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodeController;
import com.lasercyber.lws.ui.common.handler.LensHeavyContaminationWarnAlarm;
import com.lasercyber.lws.ui.common.settings.DangerousOperationsSettings;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;

public class RgbLedDecisionTest {

    private static final int BIT_LASER = 1;
    private static final int BIT_SAFETY_LOCK = 1 << 5;
    private static final int BIT_KEY_SWITCH = 1 << 6;
    private static final int BIT_CNC_CONNECTED = 1 << 10;
    private static final int ARMED_INTERLOCKS = BIT_SAFETY_LOCK | BIT_KEY_SWITCH;

    @Before
    @After
    public void resetAlarmGuardState() {
        DangerousOperationsSettings.resetForTest();
        LensHeavyContaminationWarnAlarm.INSTANCE.resetForStop();
        WarnEpisodeController.resetForTest();
    }

    @Test
    public void redSteadyOnWhenLaserEmitting() {
        DeviceStatus status = statusWithMachine(BIT_LASER);
        assertEquals(RgbLedDecision.RedMode.STEADY_ON, RgbLedDecision.redMode(status));
    }

    @Test
    public void redBlinksWhenLaserStandbyOnline() {
        DeviceStatus status = new DeviceStatus();
        assertEquals(RgbLedDecision.RedMode.BLINK, RgbLedDecision.redMode(status));
    }

    @Test
    public void redOffWhenLaserCommunicationAlarm() {
        DeviceStatus status = new DeviceStatus();
        status.setLaserAlarmSeg1(1);
        assertEquals(RgbLedDecision.RedMode.OFF, RgbLedDecision.redMode(status));
    }

    @Test
    public void redOffWhenDeviceStatusMissing() {
        assertEquals(RgbLedDecision.RedMode.OFF, RgbLedDecision.redMode(null));
    }

    @Test
    public void yellowBlinksWhenHardwareAlarmPresent() {
        DeviceStatus status = new DeviceStatus();
        status.setGunAlarmSeg1(1);
        assertEquals(RgbLedDecision.YellowMode.BLINK, RgbLedDecision.yellowMode(status, null));
    }

    @Test
    public void yellowOffWhenNoHardwareAlarm() {
        DeviceStatus status = new DeviceStatus();
        assertEquals(RgbLedDecision.YellowMode.OFF, RgbLedDecision.yellowMode(status, null));
    }

    @Test
    public void yellowBlinksForOtherCodedAlarm() {
        WarnEpisodeController.armDemoEpisode(AlarmCodeEnums.E006.errorCode);
        assertEquals(RgbLedDecision.YellowMode.BLINK, RgbLedDecision.yellowMode(null, null));
    }

    @Test
    public void yellowOffWhenOnlyFeederAlarmAndBypassOn() {
        DeviceStatus status = new DeviceStatus();
        status.setWireFeederAlarmSeg1(1);
        DangerousOperationsSettings.setOverridesForTest(null, null, null, true, null);
        assertEquals(RgbLedDecision.YellowMode.OFF, RgbLedDecision.yellowMode(status, null));
    }

    @Test
    public void greenOnWhenAllInterlocksAndLaserEnableWithoutLaserOutput() {
        DeviceStatus status = statusWithMachine(ARMED_INTERLOCKS);
        assertEquals(RgbLedDecision.GreenMode.STEADY_ON, RgbLedDecision.greenMode(status, true));
    }

    @Test
    public void greenOffWhenLaserEnableInactive() {
        DeviceStatus status = statusWithMachine(ARMED_INTERLOCKS);
        assertEquals(RgbLedDecision.GreenMode.OFF, RgbLedDecision.greenMode(status, false));
    }

    @Test
    public void greenOffWhenLaserEmitting() {
        DeviceStatus status = statusWithMachine(ARMED_INTERLOCKS | BIT_LASER);
        assertEquals(RgbLedDecision.GreenMode.OFF, RgbLedDecision.greenMode(status, true));
    }

    @Test
    public void greenOffWhenWorkBlockedByGasAlarm() {
        DeviceStatus status = statusWithMachine(ARMED_INTERLOCKS);
        status.setControlCardAlarmSeg1(1);
        assertEquals(RgbLedDecision.GreenMode.OFF, RgbLedDecision.greenMode(status, true, null));
    }

    @Test
    public void greenOnWhenGasAlarmBypassEnabled() {
        DeviceStatus status = statusWithMachine(ARMED_INTERLOCKS);
        status.setControlCardAlarmSeg1(1);
        DangerousOperationsSettings.setOverridesForTest(null, true, null);
        assertEquals(RgbLedDecision.GreenMode.STEADY_ON, RgbLedDecision.greenMode(status, true, null));
    }

    @Test
    public void greenOnWhenRawLaserAlarmSegmentActiveButWorkNotBlocked() {
        DeviceStatus status = statusWithMachine(ARMED_INTERLOCKS);
        status.setLaserAlarmSeg2(1);
        assertEquals(RgbLedDecision.GreenMode.STEADY_ON, RgbLedDecision.greenMode(status, true, null));
    }

    @Test
    public void greenOffWhenOtherCodedAlarmBlocksWork() {
        DeviceStatus status = statusWithMachine(ARMED_INTERLOCKS);
        WarnEpisodeController.armDemoEpisode(AlarmCodeEnums.E006.errorCode);
        assertEquals(RgbLedDecision.GreenMode.OFF, RgbLedDecision.greenMode(status, true, null));
    }

    @Test
    public void greenOffWhenOtherCodedAlarmEvenWithKeepLaserOnWhileAlarmed() {
        DeviceStatus status = statusWithMachine(ARMED_INTERLOCKS);
        WarnEpisodeController.armDemoEpisode(AlarmCodeEnums.E006.errorCode);
        DangerousOperationsSettings.setOverridesForTest(null, null, null, true);
        assertEquals(RgbLedDecision.GreenMode.OFF, RgbLedDecision.greenMode(status, true, null));
    }

    @Test
    public void greenOffWhenAnyInterlockMissing() {
        DeviceStatus status = statusWithMachine(BIT_KEY_SWITCH);
        assertEquals(RgbLedDecision.GreenMode.OFF, RgbLedDecision.greenMode(status, true));
    }

    @Test
    public void greenOnInCncCutWhenConnectedWithKeySwitchOnly() {
        DeviceStatus status = statusWithMachine(BIT_KEY_SWITCH | BIT_CNC_CONNECTED);
        assertEquals(
                RgbLedDecision.GreenMode.STEADY_ON,
                RgbLedDecision.greenMode(status, false, null, ModelConstant.CNC_CUT));
    }

    @Test
    public void greenOffInCncCutWhenNotConnected() {
        DeviceStatus status = statusWithMachine(BIT_KEY_SWITCH);
        assertEquals(
                RgbLedDecision.GreenMode.OFF,
                RgbLedDecision.greenMode(status, false, null, ModelConstant.CNC_CUT));
    }

    @Test
    public void greenOffInCncCutWhenKeySwitchOff() {
        DeviceStatus status = statusWithMachine(BIT_CNC_CONNECTED);
        assertEquals(
                RgbLedDecision.GreenMode.OFF,
                RgbLedDecision.greenMode(status, false, null, ModelConstant.CNC_CUT));
    }

    @Test
    public void greenOnInCncCutIgnoresLaserEnableAndSafetyLock() {
        DeviceStatus status = statusWithMachine(BIT_KEY_SWITCH | BIT_CNC_CONNECTED);
        assertEquals(
                RgbLedDecision.GreenMode.STEADY_ON,
                RgbLedDecision.greenMode(status, false, null, ModelConstant.CNC_CUT));
    }

    @Test
    public void greenOffInWeldingWithoutSafetyGroundLock() {
        DeviceStatus status = statusWithMachine(BIT_KEY_SWITCH);
        assertEquals(
                RgbLedDecision.GreenMode.OFF,
                RgbLedDecision.greenMode(status, true, null, ModelConstant.CONTINUOUS_WELDING));
    }

    @Test
    public void greenOnWhenAirValveOff() {
        DeviceStatus status = statusWithMachine(ARMED_INTERLOCKS);
        assertEquals(RgbLedDecision.GreenMode.STEADY_ON, RgbLedDecision.greenMode(status, true));
    }

    @Test
    public void hasAnyHardwareAlarmDetectsSegments() {
        DeviceStatus status = new DeviceStatus();
        assertFalse(status.hasAnyHardwareAlarm());
        status.setControlCardAlarmSeg2(2);
        assertTrue(status.hasAnyHardwareAlarm());
    }

    private static DeviceStatus statusWithMachine(int machineStatusSeg1) {
        DeviceStatus status = new DeviceStatus();
        status.setMachineStatusSeg1(machineStatusSeg1);
        return status;
    }
}
