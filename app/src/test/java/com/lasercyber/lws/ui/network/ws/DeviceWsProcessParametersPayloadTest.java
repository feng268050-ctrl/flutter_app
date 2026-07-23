package com.lasercyber.lws.ui.network.ws;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import com.google.gson.JsonObject;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersNameData;
import com.lasercyber.lws.ui.common.constant.ProcessDataType;
import com.lasercyber.lws.ui.common.utils.json.GsonInitUtils;

import org.junit.Before;
import org.junit.Test;

import java.util.Map;

public class DeviceWsProcessParametersPayloadTest {

    @Before
    public void setUp() {
        GsonInitUtils.initGson();
    }

    @Test
    public void nameToMap_stringId() {
        ProcessParametersNameData row = new ProcessParametersNameData();
        row.setId(99L);
        row.setName("preset-a");
        row.setProcessType(1);
        row.setDataType(ProcessDataType.ENGINEER_MODE_DATA);
        Map<String, Object> map = DeviceWsProcessParametersPayload.nameToMap(row, true);
        assertEquals("99", map.get("id"));
        assertEquals("preset-a", map.get("name"));
    }

    @Test
    public void entityToMap_stringIds() {
        ProcessParametersData row = new ProcessParametersData();
        row.setId(42L);
        row.setOriginId(7L);
        row.setLaserPower(50);
        Map<String, Object> map = DeviceWsProcessParametersPayload.entityToMap(row, true);
        assertEquals("42", map.get("id"));
        assertEquals("7", map.get("originId"));
        assertEquals(50, ((Number) map.get("laserPower")).intValue());
    }

    @Test
    public void fromPayload_wsSnakeCase() {
        JsonObject payload = new JsonObject();
        payload.addProperty("process_type", 2);
        payload.addProperty("material_type", 3);
        payload.addProperty("material_name", "steel");
        payload.addProperty("laserPower", 80);
        ProcessParametersData data = DeviceWsProcessParametersPayload.fromPayload(payload, true);
        assertEquals(Integer.valueOf(2), data.getProcessType());
        assertEquals(Integer.valueOf(3), data.getMaterialType());
        assertEquals("steel", data.getMaterialName());
        assertEquals(Integer.valueOf(80), data.getLaserPower());
    }

    @Test
    public void parseProcessType_fromSnakeCase() {
        JsonObject payload = new JsonObject();
        payload.addProperty("process_type", 3);
        assertEquals(Integer.valueOf(3), DeviceWsProcessParametersPayload.parseProcessType(payload));
    }

    @Test
    public void process_library_response_data_is_array_shape() {
        ProcessParametersNameData row = new ProcessParametersNameData();
        row.setId(1L);
        row.setProcessType(1);
        row.setDataType(ProcessDataType.ENGINEER_MODE_DATA);
        var list = DeviceWsProcessParametersPayload.nameListToMaps(
                java.util.List.of(row), true);
        assertEquals(1, list.size());
        assertTrue(list.get(0).get("id") instanceof String);
    }
}
