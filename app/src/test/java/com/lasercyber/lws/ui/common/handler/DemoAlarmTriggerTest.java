package com.lasercyber.lws.ui.common.handler;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodeController;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;

public class DemoAlarmTriggerTest {

    @Before
    @After
    public void reset() {
        WarnEpisodeController.resetForTest();
        DemoAlarmTrigger.setReleaseChannelOverrideForTest(null);
    }

    @Test
    public void releaseChannelIgnored() {
        DemoAlarmTrigger.setReleaseChannelOverrideForTest(true);
        DemoAlarmTrigger.handle(null, "C002");
        assertFalse(WarnEpisodeController.isDemoFaultActive("C002"));
    }

    @Test
    public void unknownCodeIgnored() {
        DemoAlarmTrigger.setReleaseChannelOverrideForTest(false);
        DemoAlarmTrigger.handle(null, "ZZ999");
        assertFalse(WarnEpisodeController.isDemoFaultActive("ZZ999"));
    }

    @Test
    public void emptyCodeIgnored() {
        DemoAlarmTrigger.setReleaseChannelOverrideForTest(false);
        DemoAlarmTrigger.handle(null, "");
        assertFalse(WarnEpisodeController.isDemoFaultActive(""));
    }

    @Test
    public void cleanClearsDemoEpisode() {
        DemoAlarmTrigger.setReleaseChannelOverrideForTest(false);
        WarnEpisodeController.armDemoEpisode("C002");
        assertTrue(WarnEpisodeController.isDemoFaultActive("C002"));

        WarnEpisodeController.clearAllForDebug();

        assertFalse(WarnEpisodeController.isDemoFaultActive("C002"));
    }

    @Test
    public void cleanIgnoredOnReleaseChannel() {
        DemoAlarmTrigger.setReleaseChannelOverrideForTest(true);
        WarnEpisodeController.armDemoEpisode("C002");

        DemoAlarmTrigger.clean(null);

        assertTrue(WarnEpisodeController.isDemoFaultActive("C002"));
    }
}
