package com.lasercyber.lws.ui.common.utils.convert;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;

import com.lasercyber.lws.ui.common.constant.ProcessDataType;

import org.junit.Test;

public class ProcessDataExcelConvertTest {

    @Test
    public void convertProcessDataType_canonicalLabels() {
        assertEquals(Integer.valueOf(0), ProcessDataExcelConvert.convertProcessDataType("快速模式参数"));
        assertEquals(Integer.valueOf(1), ProcessDataExcelConvert.convertProcessDataType("工程师模式内置参数"));
        assertEquals(Integer.valueOf(2), ProcessDataExcelConvert.convertProcessDataType("工程师模式自定义参数"));
        assertEquals(Integer.valueOf(3), ProcessDataExcelConvert.convertProcessDataType("视频工艺参数"));
    }

    @Test
    public void convertProcessDataType_legacyExcelLabels() {
        assertEquals(Integer.valueOf(0), ProcessDataExcelConvert.convertProcessDataType("快速模式工艺数据"));
        assertEquals(Integer.valueOf(1), ProcessDataExcelConvert.convertProcessDataType("工程师模式默认数据"));
        assertEquals(Integer.valueOf(2), ProcessDataExcelConvert.convertProcessDataType("工程师模式自定义数据"));
        assertEquals(Integer.valueOf(3), ProcessDataExcelConvert.convertProcessDataType("视频中的工艺库数据"));
    }

    @Test
    public void convertProcessDataType_unknown() {
        assertNull(ProcessDataExcelConvert.convertProcessDataType("unknown"));
        assertNull(ProcessDataExcelConvert.convertProcessDataType(null));
    }
}
