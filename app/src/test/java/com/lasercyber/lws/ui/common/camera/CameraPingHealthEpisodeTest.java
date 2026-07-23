package com.lasercyber.lws.ui.common.camera;

import static org.junit.Assert.assertFalse;

import com.lasercyber.lws.ui.common.enums.AlarmCodeEnums;
import com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodeController;
import com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodePolicy;

import org.junit.After;
import org.junit.Test;

public class CameraPingHealthEpisodeTest {

    @After
    public void reset() {
        CameraPingHealth.getInstance().resetForTest();
        WarnEpisodeController.resetForTest();
    }

    @Test
    public void isFaultActive_usesPingNotStaleEpisode() {
        WarnEpisodeController.armEpisode(
                AlarmCodeEnums.C002.errorCode,
                WarnEpisodePolicy.productionPassive());
        CameraPingHealth.getInstance().setReachableForTest(true);
        assertFalse(WarnEpisodeController.isFaultActive(AlarmCodeEnums.C002.errorCode));
        assertFalse(WarnEpisodeController.isReminderPending(AlarmCodeEnums.C002.errorCode));
    }
}
