package com.lasercyber.lws.ui.common.database.migration;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;

import com.lasercyber.lws.ui.bean.entity.AdvancedSettings;
import com.lasercyber.lws.ui.common.utils.DefaultValueUtils;

import org.junit.Test;

public class Migration_47_48Test {

    @Test
    public void migration_class_existsFor47To48() {
        assertNotNull(new Migration_47_48());
    }

    @Test
    public void defaultAdvancedSettings_disableDangerousOperationsToggles() {
        AdvancedSettings settings = DefaultValueUtils.createDefaultAdvancedSettings();
        assertFalse(settings.getAllowWorkAfterCameraAlarm());
        assertFalse(settings.getAllowWorkAfterGasAlarm());
        assertFalse(settings.getAllowWorkAfterLensContamination());
    }
}
