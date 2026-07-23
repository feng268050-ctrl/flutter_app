package com.lasercyber.lws.ui.common.rx.modbus.protocol;

import com.lasercyber.lws.ui.bean.entity.AdvancedSettings;
import com.lasercyber.lws.ui.bean.entity.DeviceControlData;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.modbus.register.address.DeviceControllerRegisterAddress;
import com.lasercyber.lws.ui.common.modbus.register.address.DeviceSettingRegisterAddress;

import org.junit.Assert;
import org.junit.Test;

import java.util.List;

public class ModbusFiledBuilderAdvancedSettingTest {

    @Test
    public void createDeviceControlData_writesGunDriveAndSwingRangeInRegisterOrder() {
        DeviceControlData control = new DeviceControlData();
        control.setModel(ModelConstant.CONTINUOUS_WELDING);
        control.setGunDeviceType(0);

        List<ModbusHexData> payload = ModbusFiledBuilder.createDeviceControlData(control);

        Assert.assertEquals(DeviceControllerRegisterAddress.GUN_DRIVE_TYPE, payload.get(2).getAddress());
        Assert.assertEquals(1, payload.get(2).getValue());
        Assert.assertEquals(DeviceControllerRegisterAddress.GUN_SWING_RANGE_MODE, payload.get(3).getAddress());
        Assert.assertEquals(7, payload.get(3).getValue());
    }

    @Test
    public void doCreateWriteDeviceSetting_includesAdvancedRegistersInOrder() {
        AdvancedSettings setting = new AdvancedSettings();
        setting.setInletGasPressureThreshold(101);
        setting.setDriverTemperatureAlarmThreshold(72.5);
        setting.setProtectiveLensTemperatureAlarmThreshold(73.5);
        setting.setCollimatingLensTemperatureAlarmThreshold(66.5);
        setting.setMotorTemperatureAlarmThreshold(74.5);
        setting.setTemperatureAlarmRecoveryInterval(6.5);

        List<ModbusHexData> payload = ModbusFiledBuilder.doCreateWriteDeviceSetting(setting);

        Assert.assertEquals(DeviceSettingRegisterAddress.INLET_GAS_PRESSURE_THRESHOLD, payload.get(10).getAddress());
        Assert.assertEquals(DeviceSettingRegisterAddress.DRIVER_TEMPERATURE_ALARM_THRESHOLD, payload.get(11).getAddress());
        Assert.assertEquals(DeviceSettingRegisterAddress.PROTECTIVE_LENS_TEMPERATURE_ALARM_THRESHOLD, payload.get(12).getAddress());
        Assert.assertEquals(DeviceSettingRegisterAddress.COLLIMATING_LENS_TEMPERATURE_ALARM_THRESHOLD, payload.get(13).getAddress());
        Assert.assertEquals(DeviceSettingRegisterAddress.MOTOR_TEMPERATURE_ALARM_THRESHOLD, payload.get(14).getAddress());
        Assert.assertEquals(DeviceSettingRegisterAddress.TEMPERATURE_ALARM_RECOVERY_INTERVAL, payload.get(15).getAddress());
        Assert.assertEquals(101, payload.get(10).getValue());
        Assert.assertEquals(725, payload.get(11).getValue());
        Assert.assertEquals(735, payload.get(12).getValue());
        Assert.assertEquals(665, payload.get(13).getValue());
        Assert.assertEquals(745, payload.get(14).getValue());
        Assert.assertEquals(65, payload.get(15).getValue());
    }

    @Test
    public void doCreateWriteDeviceSetting_usesDefaultsForMissingAdvancedRegisters() {
        List<ModbusHexData> payload = ModbusFiledBuilder.doCreateWriteDeviceSetting(new AdvancedSettings());

        Assert.assertEquals(0, payload.get(10).getValue());
        Assert.assertEquals(700, payload.get(11).getValue());
        Assert.assertEquals(700, payload.get(12).getValue());
        Assert.assertEquals(650, payload.get(13).getValue());
        Assert.assertEquals(700, payload.get(14).getValue());
        Assert.assertEquals(50, payload.get(15).getValue());
    }
}
