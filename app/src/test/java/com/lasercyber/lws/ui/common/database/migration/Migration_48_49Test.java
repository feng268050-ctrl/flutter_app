package com.lasercyber.lws.ui.common.database.migration;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;

import com.lasercyber.lws.ui.bean.entity.AdvancedSettings;
import com.lasercyber.lws.ui.common.utils.DefaultValueUtils;

import org.junit.Test;

public class Migration_48_49Test {

    @Test
    public void migration_class_existsFor48To49() {
        assertNotNull(new Migration_48_49());
    }

    @Test
    public void defaultAdvancedSettings_disableKeepLaserOnWhileAlarmed() {
        AdvancedSettings settings = DefaultValueUtils.createDefaultAdvancedSettings();
        assertFalse(settings.getKeepLaserOnWhileAlarmed());
    }
}
