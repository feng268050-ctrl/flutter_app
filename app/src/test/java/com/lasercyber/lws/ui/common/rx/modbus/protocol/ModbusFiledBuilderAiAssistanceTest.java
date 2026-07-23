package com.lasercyber.lws.ui.common.rx.modbus.protocol;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.bean.entity.AdvancedSettings;
import com.lasercyber.lws.ui.common.utils.DefaultValueUtils;

import org.junit.Test;

import java.util.List;

public class ModbusFiledBuilderAiAssistanceTest {

    @Test
    public void advancedSettingsWritePayload_omitsAiAssistanceFields() throws Exception {
        AdvancedSettings settings = DefaultValueUtils.createDefaultAdvancedSettings();
        settings.setLensContaminationDetectionEnabled(false);
        settings.setZeroPointOffsetDetectionEnabled(false);

        List<ModbusHexData> payload = ModbusFiledBuilder.doCreateWriteDeviceSetting(settings);
        String serialized = payload.toString().toLowerCase();

        assertFalse(serialized.contains("lenscontamination"));
        assertFalse(serialized.contains("zeropointoffsetdetection"));
        assertTrue(payload.size() > 0);
    }
}
