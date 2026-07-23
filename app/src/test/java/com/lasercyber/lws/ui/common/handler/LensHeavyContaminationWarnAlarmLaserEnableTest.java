package com.lasercyber.lws.ui.common.handler;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.common.settings.DangerousOperationsSettings;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;

public class LensHeavyContaminationWarnAlarmLaserEnableTest {

    @Before
    @After
    public void reset() {
        LensHeavyContaminationWarnAlarm.INSTANCE.resetForStop();
        DangerousOperationsSettings.resetForTest();
    }

    @Test
    public void unresolvedEpisodeBlocksLaserEnable() {
        LensHeavyContaminationWarnAlarm.INSTANCE.armPendingForTest();
        assertTrue(LensHeavyContaminationWarnAlarm.INSTANCE.isLaserEnableBlocked());
    }

    @Test
    public void dismissClearsEpisodeAndUnblocksLaserEnable() {
        LensHeavyContaminationWarnAlarm.INSTANCE.armPendingForTest();
        LensHeavyContaminationWarnAlarm.INSTANCE.onFaultCleared();
        assertFalse(LensHeavyContaminationWarnAlarm.INSTANCE.isLaserEnableBlocked());
    }

    @Test
    public void bypassToggleAllowsGuardToPass() {
        LensHeavyContaminationWarnAlarm.INSTANCE.armPendingForTest();
        DangerousOperationsSettings.setOverridesForTest(null, null, true);
        assertFalse(com.lasercyber.lws.ui.activitys.engineer.mode.ui.LaserEnableAlarmGuard.isLensBlocking(null));
    }

    @Test
    public void debugCleanClearsAcknowledgedEpisodeAndAllowsNextDialogCycle() {
        LensHeavyContaminationWarnAlarm.INSTANCE.armPendingForTest();
        LensHeavyContaminationWarnAlarm.INSTANCE.acknowledgeDialogForTest();
        assertTrue(LensHeavyContaminationWarnAlarm.INSTANCE.isLaserEnableBlocked());

        LensHeavyContaminationWarnAlarm.INSTANCE.clearUnresolvedEpisodeForDebug();

        assertFalse(LensHeavyContaminationWarnAlarm.INSTANCE.isLaserEnableBlocked());
        LensHeavyContaminationWarnAlarm.INSTANCE.armPendingForTest();
        assertTrue(LensHeavyContaminationWarnAlarm.INSTANCE.isLaserEnableBlocked());
    }
}
