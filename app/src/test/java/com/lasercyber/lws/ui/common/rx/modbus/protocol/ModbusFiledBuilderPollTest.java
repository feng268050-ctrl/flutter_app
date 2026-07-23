package com.lasercyber.lws.ui.common.rx.modbus.protocol;

import com.lasercyber.lws.ui.common.utils.modbus.DataConvert;

import org.junit.Assert;
import org.junit.Test;

import java.util.List;

public class ModbusFiledBuilderPollTest {

    @Test
    public void deviceStatusAndData_segmentsAreSmallContiguousBlocks() {
        List<ModbusReadFiled> status = ModbusFiledBuilder.createDeviceStatus();
        List<ModbusReadFiled> data = ModbusFiledBuilder.createDeviceData();

        Assert.assertEquals(23, status.size());
        Assert.assertEquals(19, data.size());
        Assert.assertTrue(status.size() + data.size() < 50);
    }

    @Test
    public void pollSegments_fullResponse_notTruncated() {
        assertSegmentComplete(ModbusFiledBuilder.createDeviceStatus());
        assertSegmentComplete(ModbusFiledBuilder.createDeviceData());
    }

    private static void assertSegmentComplete(List<ModbusReadFiled> fields) {
        byte[] payload = new byte[fields.size() * 2];
        DataConvert.convertAndFillValue(fields, payload);
        Assert.assertFalse(DataConvert.isTruncatedResponse(fields));
        long present = fields.stream().filter(ModbusReadFiled::isValuePresent).count();
        Assert.assertEquals(fields.size(), present);
    }
}
