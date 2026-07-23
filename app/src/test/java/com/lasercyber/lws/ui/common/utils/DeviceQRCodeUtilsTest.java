package com.lasercyber.lws.ui.common.utils;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class DeviceQRCodeUtilsTest {

    @Test
    public void sanitizeQrField_replacesPipeWithUnderscore() {
        assertEquals("a_b_c", DeviceQRCodeUtils.sanitizeQrField("a|b|c"));
    }

    @Test
    public void sanitizeQrField_nullIsEmptyString() {
        assertEquals("", DeviceQRCodeUtils.sanitizeQrField(null));
    }

    @Test
    public void buildDeviceIdentityQrV2Text_fourSegments_andVersionTwo() {
        String payload = DeviceQRCodeUtils.buildDeviceIdentityQrV2Text("SN1", "ModelX", "1.2.3");
        assertEquals("SN1|2|ModelX|1.2.3", payload);
        String[] parts = payload.split("\\|", -1);
        assertEquals(4, parts.length);
        assertEquals("2", parts[1]);
    }

    @Test
    public void buildDeviceIdentityQrV2Text_sanitizesDelimitersInFields() {
        String payload = DeviceQRCodeUtils.buildDeviceIdentityQrV2Text("S|N", "M|d", "1.0");
        assertEquals("S_N|2|M_d|1.0", payload);
    }
}
