package com.lasercyber.lws.ui.common.database.migration;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;

import com.lasercyber.lws.ui.bean.entity.AdvancedSettings;
import com.lasercyber.lws.ui.common.utils.DefaultValueUtils;

import org.junit.Test;

public class Migration_51_52Test {

    @Test
    public void migration_class_existsFor51To52() {
        assertNotNull(new Migration_51_52());
    }

    @Test
    public void defaultAdvancedSettings_disableAllowWorkAfterFeederAlarm() {
        AdvancedSettings settings = DefaultValueUtils.createDefaultAdvancedSettings();
        assertFalse(settings.getAllowWorkAfterFeederAlarm());
    }
}
