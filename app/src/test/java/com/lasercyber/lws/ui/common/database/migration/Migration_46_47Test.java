package com.lasercyber.lws.ui.common.database.migration;

import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.bean.entity.AdvancedSettings;
import com.lasercyber.lws.ui.common.utils.DefaultValueUtils;

import org.junit.Test;

public class Migration_46_47Test {

    @Test
    public void migration_class_existsFor46To47() {
        assertNotNull(new Migration_46_47());
    }

    @Test
    public void defaultAdvancedSettings_enableAiAssistanceToggles() {
        AdvancedSettings settings = DefaultValueUtils.createDefaultAdvancedSettings();
        assertTrue(settings.getLensContaminationDetectionEnabled());
        assertTrue(settings.getZeroPointOffsetDetectionEnabled());
    }
}
