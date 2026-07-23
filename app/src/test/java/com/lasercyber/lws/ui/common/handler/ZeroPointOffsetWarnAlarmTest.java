package com.lasercyber.lws.ui.common.handler;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.common.constant.AlarmCodeConstants;
import com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodeController;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;

public class ZeroPointOffsetWarnAlarmTest {

    @Before
    @After
    public void reset() {
        ZeroPointOffsetWarnAlarm.INSTANCE.resetForStop();
        WarnEpisodeController.resetForTest();
    }

    @Test
    public void pendingEpisodeBlocksLaserViaEpisodeController() {
        ZeroPointOffsetWarnAlarm.INSTANCE.armPendingForTest();
        WarnEpisodeController.notifyFaultActive(
                AlarmCodeConstants.ALARM_H034,
                com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodePolicy.productionPassive());
        assertTrue(WarnEpisodeController.isBlockingLaser(AlarmCodeConstants.ALARM_H034));
    }

    @Test
    public void dismissClearsEpisodeAndUnblocksLaser() {
        ZeroPointOffsetWarnAlarm.INSTANCE.armPendingForTest();
        WarnEpisodeController.notifyFaultActive(
                AlarmCodeConstants.ALARM_H034,
                com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodePolicy.productionPassive());
        ZeroPointOffsetWarnAlarm.INSTANCE.onFaultCleared();
        assertFalse(ZeroPointOffsetWarnAlarm.INSTANCE.isPendingReminderForTest());
        assertFalse(WarnEpisodeController.isBlockingLaser(AlarmCodeConstants.ALARM_H034));
    }
}
