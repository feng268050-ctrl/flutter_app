package com.lasercyber.lws.ui.common.upgrade;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;

import org.junit.Test;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;

public class ProcessLibXlsxMappingTest {

    @Test(expected = IllegalArgumentException.class)
    public void duplicateCanonicalHeader_fails() {
        LinkedHashMap<Integer, String> header = new LinkedHashMap<>();
        header.put(0, "参数名称");
        header.put(1, "参数名称");
        ProcessLibHeaderResolver.resolveHeaderRow(header, ProcessLibImportProfile.OTA_PROCESS_LIB);
    }

    @Test(expected = IllegalArgumentException.class)
    public void missingRequiredHeader_fails() {
        LinkedHashMap<Integer, String> header = new LinkedHashMap<>();
        header.put(0, "参数名称");
        header.put(1, "厚度");
        Map<String, Integer> m = ProcessLibHeaderResolver.resolveHeaderRow(header, ProcessLibImportProfile.OTA_PROCESS_LIB);
        ProcessLibImportProfile.OTA_PROCESS_LIB.validateRequiredHeaders(m);
    }

    @Test
    public void aliasMapsAlternateRawHeaderToCanonical() {
        ProcessLibImportProfile p = new ProcessLibImportProfile(
                Set.of("参数名称", "工艺类型", "数据类型"),
                Map.of("Material", "材料")
        );
        LinkedHashMap<Integer, String> header = new LinkedHashMap<>();
        header.put(0, "参数名称");
        header.put(1, "工艺类型");
        header.put(2, "数据类型");
        header.put(3, "Material");
        Map<String, Integer> m = ProcessLibHeaderResolver.resolveHeaderRow(header, p);
        assertTrue(m.containsKey("材料"));
        assertEquals(Integer.valueOf(3), m.get("材料"));
    }

    @Test
    public void otaAliases_mapToExpectedCanonicalHeaders() {
        ProcessLibImportProfile profile = ProcessLibImportProfile.OTA_PROCESS_LIB;
        LinkedHashMap<Integer, String> header = new LinkedHashMap<>();
        header.put(0, "参数名称");
        header.put(1, "工艺类型");
        header.put(2, "数据类型");
        header.put(3, "扫描频率");
        header.put(4, "摆动宽度/扫描宽度");
        header.put(5, "气体关闭延迟");
        header.put(6, "关光延时/激光关闭延迟");
        header.put(7, "缓升时长");
        header.put(8, "功率缓降/缓降时长");
        header.put(9, "送丝回抽长度");
        header.put(10, "补丝长度/送丝补偿长度");

        Map<String, Integer> m = ProcessLibHeaderResolver.resolveHeaderRow(header, profile);
        profile.validateRequiredHeaders(m);

        assertEquals(Integer.valueOf(3), m.get("摆动频率"));
        assertEquals(Integer.valueOf(4), m.get("摆动宽度"));
        assertEquals(Integer.valueOf(5), m.get("关气延时"));
        assertEquals(Integer.valueOf(6), m.get("关光延时"));
        assertEquals(Integer.valueOf(7), m.get("功率缓升"));
        assertEquals(Integer.valueOf(8), m.get("功率缓降"));
        assertEquals(Integer.valueOf(9), m.get("回抽长度"));
        assertEquals(Integer.valueOf(10), m.get("补丝长度"));
    }

    @Test
    public void fillDelayAliases_mapToCanonicalHeader() {
        ProcessLibImportProfile profile = ProcessLibImportProfile.OTA_PROCESS_LIB;
        for (String alias : new String[]{"补丝延迟", "补丝延时", "送丝补偿延迟", "补丝延迟/送丝补偿延迟"}) {
            LinkedHashMap<Integer, String> header = new LinkedHashMap<>();
            header.put(0, "参数名称");
            header.put(1, "工艺类型");
            header.put(2, "数据类型");
            header.put(3, alias);
            Map<String, Integer> m = ProcessLibHeaderResolver.resolveHeaderRow(header, profile);
            profile.validateRequiredHeaders(m);
            assertEquals(Integer.valueOf(3), m.get("补丝时延"));

            LinkedHashMap<Integer, Object> data = new LinkedHashMap<>();
            data.put(0, "P1");
            data.put(1, "Cut");
            data.put(2, "快速模式工艺数据");
            data.put(3, "250");
            ProcessParametersData row = ProcessLibRowMapper.mapDataRow(data, m);
            assertEquals(Integer.valueOf(250), row.getFillDelay());
        }
    }

    @Test
    public void columnReorder_producesSameFields() {
        ProcessLibImportProfile profile = ProcessLibImportProfile.OTA_PROCESS_LIB;

        LinkedHashMap<Integer, String> header1 = new LinkedHashMap<>();
        header1.put(0, "参数名称");
        header1.put(1, "工艺类型");
        header1.put(2, "数据类型");
        header1.put(3, "厚度");
        Map<String, Integer> idx1 = ProcessLibHeaderResolver.resolveHeaderRow(header1, profile);
        profile.validateRequiredHeaders(idx1);

        LinkedHashMap<Integer, Object> data1 = new LinkedHashMap<>();
        data1.put(0, "P1");
        data1.put(1, "Cut");
        data1.put(2, "快速模式工艺数据");
        data1.put(3, "2.5");
        ProcessParametersData e1 = ProcessLibRowMapper.mapDataRow(data1, idx1);

        LinkedHashMap<Integer, String> header2 = new LinkedHashMap<>();
        header2.put(0, "厚度");
        header2.put(1, "工艺类型");
        header2.put(2, "数据类型");
        header2.put(3, "参数名称");
        Map<String, Integer> idx2 = ProcessLibHeaderResolver.resolveHeaderRow(header2, profile);
        profile.validateRequiredHeaders(idx2);

        LinkedHashMap<Integer, Object> data2 = new LinkedHashMap<>();
        data2.put(0, "2.5");
        data2.put(1, "Cut");
        data2.put(2, "快速模式工艺数据");
        data2.put(3, "P1");
        ProcessParametersData e2 = ProcessLibRowMapper.mapDataRow(data2, idx2);

        assertEquals(e1.getName(), e2.getName());
        assertEquals(e1.getThickness(), e2.getThickness());
        assertEquals(e1.getProcessType(), e2.getProcessType());
        assertEquals(e1.getDataType(), e2.getDataType());
    }

    @Test
    public void emptyNumericCell_mapsToNull() {
        LinkedHashMap<Integer, String> header = new LinkedHashMap<>();
        header.put(0, "参数名称");
        header.put(1, "工艺类型");
        header.put(2, "数据类型");
        header.put(3, "厚度");
        Map<String, Integer> idx = ProcessLibHeaderResolver.resolveHeaderRow(header, ProcessLibImportProfile.OTA_PROCESS_LIB);
        ProcessLibImportProfile.OTA_PROCESS_LIB.validateRequiredHeaders(idx);

        LinkedHashMap<Integer, Object> data = new LinkedHashMap<>();
        data.put(0, "P1");
        data.put(1, "Cut");
        data.put(2, "快速模式工艺数据");
        data.put(3, "  ");
        ProcessParametersData e = ProcessLibRowMapper.mapDataRow(data, idx);
        assertNotNull(e.getName());
        assertEquals("P1", e.getName());
        assertTrue(e.getThickness() == null);
    }
}
