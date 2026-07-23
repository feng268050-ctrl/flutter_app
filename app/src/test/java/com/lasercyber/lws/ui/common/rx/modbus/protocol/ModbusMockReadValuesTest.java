package com.lasercyber.lws.ui.common.rx.modbus.protocol;

import com.lasercyber.lws.ui.bean.entity.DeviceData;
import com.lasercyber.lws.ui.bean.entity.DeviceInfo;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.modbus.register.address.DeviceDataRegisterAddress;
import com.lasercyber.lws.ui.common.modbus.register.address.DeviceStatusRegisterAddress;

import org.junit.Assert;
import org.junit.Test;

import java.util.List;

public class ModbusMockReadValuesTest {

    @Test
    public void apply_setsDeviceTypeToLsw01() {
        List<ModbusReadFiled> fields = ModbusFiledBuilder.createDeviceStatus();
        ModbusMockReadValues.apply(fields);

        DeviceStatus status = ModbusFiledConvert.deviceStatusConvert(fields, null);
        Assert.assertEquals(Integer.valueOf(1), status.getDeviceType());
    }

    @Test
    public void apply_setsBlowAirPressureToStandardAtmosphericPressure() {
        List<ModbusReadFiled> fields = ModbusFiledBuilder.createDeviceData();
        ModbusMockReadValues.apply(fields);

        DeviceData data = ModbusFiledConvert.deviceDataConvert(fields, null);
        Assert.assertEquals(
                Integer.valueOf((int) ModbusMockReadValues.STANDARD_ATMOSPHERIC_PRESSURE_KPA),
                data.getBlowAirPressure());
    }

    @Test
    public void apply_setsPumpGaugeCurrentToPointTwoAmps() {
        List<ModbusReadFiled> fields = ModbusFiledBuilder.createDeviceData();
        ModbusMockReadValues.apply(fields);

        DeviceData data = ModbusFiledConvert.deviceDataConvert(fields, null);
        Assert.assertEquals(Integer.valueOf((int) ModbusMockReadValues.LASER_CURRENT_RAW), data.getLaserCurrent());
        Assert.assertEquals(ModbusMockReadValues.PUMP_GAUGE_CURRENT_AMPS, data.getPumpGaugeCurrentAmps(), 0.0001);
    }

    @Test
    public void apply_setsRedLightOn() {
        List<ModbusReadFiled> fields = ModbusFiledBuilder.createDeviceStatus();
        ModbusMockReadValues.apply(fields);

        DeviceStatus status = ModbusFiledConvert.deviceStatusConvert(fields, null);
        Assert.assertTrue(status.isRedLightOn());
    }

    @Test
    public void apply_setsWeldingGunTemperatures() {
        List<ModbusReadFiled> fields = ModbusFiledBuilder.createDeviceData();
        ModbusMockReadValues.apply(fields);

        DeviceData data = ModbusFiledConvert.deviceDataConvert(fields, null);
        Assert.assertEquals(Integer.valueOf((int) ModbusMockReadValues.GUN_MOTOR_TEMPERATURE_RAW), data.getGunMotorTempRaw());
        Assert.assertEquals(
                Integer.valueOf((int) ModbusMockReadValues.GUN_DRIVER_BOARD_TEMPERATURE_RAW),
                data.getGunDriverBoardTempRaw());
        Assert.assertEquals(
                Integer.valueOf((int) ModbusMockReadValues.PROTECTIVE_COVER_TEMPERATURE_RAW),
                data.getProtectionBoardTempRaw());
        Assert.assertEquals(
                Integer.valueOf((int) ModbusMockReadValues.COLLIMATOR_TEMPERATURE_RAW),
                data.getCollimatorTempRaw());
    }

    @Test
    public void apply_setsDeviceInformationFields() {
        List<ModbusReadFiled> infoFields = ModbusFiledBuilder.createDeviceInfo();
        ModbusMockReadValues.apply(infoFields);
        DeviceInfo info = ModbusFiledConvert.deviceInfoConvert(infoFields, null);
        Assert.assertEquals(ModbusMockReadValues.MOCK_GUNHEAD_SN, info.getGunSn());
        Assert.assertEquals(ModbusMockReadValues.MOCK_LASER_VERSION, info.getLaserVersion());
        Assert.assertEquals(String.valueOf(ModbusMockReadValues.MOCK_WIRE_FEEDER_VERSION), info.getWireFeederVersion());

        List<ModbusReadFiled> statusFields = ModbusFiledBuilder.createDeviceStatus();
        ModbusMockReadValues.apply(statusFields);
        DeviceStatus status = ModbusFiledConvert.deviceStatusConvert(statusFields, null);
        Assert.assertEquals(
                Integer.valueOf((int) ModbusMockReadValues.MOCK_FIRMWARE_VERSION),
                status.getSoftwareVersion());
    }

    @Test
    public void apply_leavesUnrelatedRegistersAtZero() {
        List<ModbusReadFiled> fields = ModbusFiledBuilder.createDeviceStatus();
        ModbusMockReadValues.apply(fields);

        long hardwareVersion = fields.stream()
                .filter(f -> f.getAddress() == DeviceStatusRegisterAddress.DEVICE_HARDWARE_VERSION)
                .findFirst()
                .orElseThrow()
                .getValue();
        Assert.assertEquals(0L, hardwareVersion);
    }
}
