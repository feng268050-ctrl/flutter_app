package com.lasercyber.lws.ui.common.utils.modbus;

import com.lasercyber.lws.ui.bean.entity.DeviceData;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.modbus.register.address.DeviceStatusRegisterAddress;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusFiledBuilder;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusFiledConvert;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusReadFiled;

import org.junit.Assert;
import org.junit.Test;

import java.util.List;

public class DataConvertTest {

    @Test
    public void convertAndFillValue_fullResponse_fillsAllFields() {
        List<ModbusReadFiled> fields = ModbusFiledBuilder.createDeviceStatus();
        byte[] data = new byte[fields.size() * 2];
        for (int i = 0; i < data.length; i++) {
            data[i] = (byte) (i + 1);
        }

        int filled = DataConvert.convertAndFillValue(fields, data);

        Assert.assertEquals(fields.size(), filled);
        Assert.assertFalse(DataConvert.isTruncatedResponse(fields));
    }

    @Test
    public void convertAndFillValue_truncatedResponse_marksMissingFields() {
        List<ModbusReadFiled> fields = ModbusFiledBuilder.createDeviceStatus();
        byte[] data = new byte[19 * 2];

        int filled = DataConvert.convertAndFillValue(fields, data);

        Assert.assertEquals(19, filled);
        Assert.assertTrue(DataConvert.isTruncatedResponse(fields));
        Assert.assertTrue(fields.get(0).isValuePresent());
        Assert.assertFalse(fields.get(19).isValuePresent());
    }

    @Test
    public void mergeDeviceStatusFromPoll_truncatedResponse_discardsRead() {
        List<ModbusReadFiled> fields = ModbusFiledBuilder.createDeviceStatus();
        byte[] data = new byte[19 * 2];
        DataConvert.convertAndFillValue(fields, data);

        DeviceStatus cached = new DeviceStatus();
        cached.setControlCardAlarmSeg1(7);
        cached.setMachineStatusSeg1(42);
        cached.setMachineStatusSeg2(99);

        DeviceStatus merged = ModbusFiledConvert.mergeDeviceStatusFromPoll(fields, cached);

        Assert.assertNull(merged);
    }

    @Test
    public void mergeDeviceStatusFromPoll_fullResponse_mergesFields() {
        List<ModbusReadFiled> fields = ModbusFiledBuilder.createDeviceStatus();
        byte[] data = new byte[fields.size() * 2];
        DataConvert.convertAndFillValue(fields, data);
        fields.get(0).setValue(3);
        fields.get(0).setValuePresent(true);

        DeviceStatus merged = ModbusFiledConvert.mergeDeviceStatusFromPoll(fields, new DeviceStatus());

        Assert.assertNotNull(merged);
        Assert.assertEquals(Integer.valueOf(3), merged.getDeviceType());
    }

    @Test
    public void mergeDeviceDataFromPoll_truncatedResponse_discardsRead() {
        List<ModbusReadFiled> fields = ModbusFiledBuilder.createDeviceData();
        byte[] data = new byte[10 * 2];
        DataConvert.convertAndFillValue(fields, data);

        DeviceData cached = new DeviceData();
        cached.setBlowAirPressure(101);
        cached.setLaserCurrent(42);

        DeviceData merged = ModbusFiledConvert.mergeDeviceDataFromPoll(fields, cached);

        Assert.assertNull(merged);
    }

    @Test
    public void mergeDeviceDataFromPoll_fullResponse_mergesFields() {
        List<ModbusReadFiled> fields = ModbusFiledBuilder.createDeviceData();
        byte[] data = new byte[fields.size() * 2];
        DataConvert.convertAndFillValue(fields, data);
        fields.get(0).setValue(88);
        fields.get(0).setValuePresent(true);

        DeviceData merged = ModbusFiledConvert.mergeDeviceDataFromPoll(fields, new DeviceData());

        Assert.assertNotNull(merged);
        Assert.assertEquals(Integer.valueOf(88), merged.getBlowAirPressure());
    }

    @Test
    public void deviceStatusConvert_emergencyStop_clearsLaserAndWireFeederCommAlarms() {
        List<ModbusReadFiled> fields = ModbusFiledBuilder.createDeviceStatus();
        byte[] data = new byte[fields.size() * 2];
        DataConvert.convertAndFillValue(fields, data);
        setFieldValue(fields, DeviceStatusRegisterAddress.LASER_ALARM_STATUS_FIELD_1, 1);
        setFieldValue(fields, DeviceStatusRegisterAddress.WIRE_FEEDER_ALARM_STATUS_FIELD_1, 1);
        setFieldValue(fields, DeviceStatusRegisterAddress.MACHINE_STATUS_FIELD_1, 1 << 7);

        DeviceStatus status = ModbusFiledConvert.deviceStatusConvert(fields, new DeviceStatus());

        Assert.assertFalse(status.isLaserCommunicationAlarm());
        Assert.assertFalse(status.isWireFeederCommunicationAlarm());
        Assert.assertEquals(Integer.valueOf(0), status.getLaserAlarmSeg1());
        Assert.assertEquals(Integer.valueOf(0), status.getWireFeederAlarmSeg1());
    }

    @Test
    public void deviceStatusConvert_emergencyStop_preservesOtherLaserAlarmBits() {
        List<ModbusReadFiled> fields = ModbusFiledBuilder.createDeviceStatus();
        byte[] data = new byte[fields.size() * 2];
        DataConvert.convertAndFillValue(fields, data);
        setFieldValue(fields, DeviceStatusRegisterAddress.LASER_ALARM_STATUS_FIELD_1, 3);
        setFieldValue(fields, DeviceStatusRegisterAddress.WIRE_FEEDER_ALARM_STATUS_FIELD_1, 5);
        setFieldValue(fields, DeviceStatusRegisterAddress.MACHINE_STATUS_FIELD_1, 1 << 7);

        DeviceStatus status = ModbusFiledConvert.deviceStatusConvert(fields, new DeviceStatus());

        Assert.assertFalse(status.isLaserCommunicationAlarm());
        Assert.assertFalse(status.isWireFeederCommunicationAlarm());
        Assert.assertEquals(Integer.valueOf(2), status.getLaserAlarmSeg1());
        Assert.assertEquals(Integer.valueOf(4), status.getWireFeederAlarmSeg1());
    }

    @Test
    public void deviceStatusConvert_withoutEmergencyStop_keepsCommAlarms() {
        List<ModbusReadFiled> fields = ModbusFiledBuilder.createDeviceStatus();
        byte[] data = new byte[fields.size() * 2];
        DataConvert.convertAndFillValue(fields, data);
        setFieldValue(fields, DeviceStatusRegisterAddress.LASER_ALARM_STATUS_FIELD_1, 1);
        setFieldValue(fields, DeviceStatusRegisterAddress.WIRE_FEEDER_ALARM_STATUS_FIELD_1, 1);
        setFieldValue(fields, DeviceStatusRegisterAddress.MACHINE_STATUS_FIELD_1, 0);

        DeviceStatus status = ModbusFiledConvert.deviceStatusConvert(fields, new DeviceStatus());

        Assert.assertTrue(status.isLaserCommunicationAlarm());
        Assert.assertTrue(status.isWireFeederCommunicationAlarm());
    }

    private static void setFieldValue(List<ModbusReadFiled> fields, int address, long value) {
        for (ModbusReadFiled field : fields) {
            if (field.getAddress() == address) {
                field.setValue(value);
                field.setValuePresent(true);
                return;
            }
        }
        Assert.fail("Missing field for address 0x" + Integer.toHexString(address));
    }
}
