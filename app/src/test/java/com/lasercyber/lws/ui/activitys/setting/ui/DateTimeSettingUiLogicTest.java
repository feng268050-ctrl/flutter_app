package com.lasercyber.lws.ui.activitys.setting.ui;

import org.junit.Assert;
import org.junit.Test;

public class DateTimeSettingUiLogicTest {

    @Test
    public void manualDateTimeEnabled_whenAutoOff() {
        Assert.assertTrue(DateTimeSettingUiLogic.isManualDateTimeEnabled(false));
        Assert.assertFalse(DateTimeSettingUiLogic.isManualDateTimeEnabled(true));
    }

    @Test
    public void manualTimeZoneEnabled_whenAutoOff() {
        Assert.assertTrue(DateTimeSettingUiLogic.isManualTimeZoneEnabled(false));
        Assert.assertFalse(DateTimeSettingUiLogic.isManualTimeZoneEnabled(true));
    }
}
