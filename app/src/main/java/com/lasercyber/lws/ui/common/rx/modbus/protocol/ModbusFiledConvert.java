package com.lasercyber.lws.ui.common.rx.modbus.protocol;

import android.util.Log;

import androidx.annotation.NonNull;

import com.lasercyber.lws.ui.bean.entity.DeviceData;
import com.lasercyber.lws.ui.bean.entity.DeviceInfo;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.modbus.register.address.DeviceDataRegisterAddress;
import com.lasercyber.lws.ui.common.modbus.register.address.DeviceInfoRegisterAddress;
import com.lasercyber.lws.ui.common.modbus.register.address.DeviceStatusRegisterAddress;
import com.lasercyber.lws.ui.common.utils.ShortDataConvertUtils;
import com.lasercyber.lws.ui.common.utils.modbus.DataConvert;

import java.util.List;
import java.util.Map;
import java.util.function.IntConsumer;
import java.util.stream.Collectors;

/**
 * 协议字段转为实体类
 */
public class ModbusFiledConvert {
    private static final String TAG = LogTAGConstant.ModbusFiledConvert;

    private static @NonNull Map<Integer, List<ModbusReadFiled>> filedGroup(List<ModbusReadFiled> filedList) {
        Map<Integer, List<ModbusReadFiled>> map =
                filedList.stream().collect(Collectors.groupingBy(ModbusReadFiled::getAddress));
        return map;
    }

    private static void applyRegisterValue(
            Map<Integer, List<ModbusReadFiled>> map,
            int address,
            IntConsumer setter) {
        List<ModbusReadFiled> fields = map.get(address);
        if (fields == null || fields.isEmpty()) {
            return;
        }
        ModbusReadFiled field = fields.get(0);
        if (!field.isValuePresent()) {
            return;
        }
        setter.accept((int) field.getValue());
    }

    /**
     * 设备信息转换
     * @param filedList
     * @param deviceInfo
     * @return
     */
    public static DeviceInfo deviceInfoConvert(List<ModbusReadFiled> filedList, DeviceInfo deviceInfo){
        if (deviceInfo==null){
            deviceInfo = new DeviceInfo();
        }
        // 先转为map
        Map<Integer, List<ModbusReadFiled>> map = filedGroup(filedList);
        // 存储激光器软件版本信息
        List<ModbusReadFiled> laserCersionFieldHeight = map.get(DeviceInfoRegisterAddress.LASER_SOFTWARE_VERSION_HIGH);
        List<ModbusReadFiled> laserCersionFieldLow = map.get(DeviceInfoRegisterAddress.LASER_SOFTWARE_VERSION_LOW);
        StringBuilder laserCersionFBuilder = new StringBuilder();
        laserCersionFBuilder.append(Integer.toHexString((int) laserCersionFieldHeight.get(0).getValue()));
        laserCersionFBuilder.append(Integer.toHexString((int) laserCersionFieldLow.get(0).getValue()));
        deviceInfo.setLaserVersion(laserCersionFBuilder.toString());

        // 激光器硬件版本
        List<ModbusReadFiled> laserHardwareFieldHeight = map.get(DeviceInfoRegisterAddress.LASER_HARDWARE_VERSION_HIGH);
        List<ModbusReadFiled> laserHardwareFieldLow = map.get(DeviceInfoRegisterAddress.LASER_HARDWARE_VERSION_LOW);
        StringBuilder laserHardwareFBuilder = new StringBuilder();
        laserHardwareFBuilder.append(Integer.toHexString((int) laserHardwareFieldHeight.get(0).getValue()));
        laserHardwareFBuilder.append(Integer.toHexString((int) laserHardwareFieldLow.get(0).getValue()));
        deviceInfo.setLaserHardwareVersion(laserHardwareFBuilder.toString());
        // 送丝机硬件版本
        long feederHardwareVersion = map.get(DeviceInfoRegisterAddress.WIRE_FEEDER_HARDWARE_VERSION).get(0).getValue();
        deviceInfo.setWireFeederHardwareVersion(String.valueOf(feederHardwareVersion));
        // 送丝机软件版本
        long feederVersion = map.get(DeviceInfoRegisterAddress.WIRE_FEEDER_SOFTWARE_VERSION).get(0).getValue();
        deviceInfo.setWireFeederVersion(String.valueOf(feederVersion));
        // 枪头硬件版本
        long gunHardwareVersion = map.get(DeviceInfoRegisterAddress.GUN_HEAD_HARDWARE_VERSION).get(0).getValue();
        deviceInfo.setGunHeadHardwareVersion(String.valueOf(gunHardwareVersion));
        // 枪头软件版本
        long gunVersion = map.get(DeviceInfoRegisterAddress.GUN_HEAD_SOFTWARE_VERSION).get(0).getValue();
         deviceInfo.setGunHeadSoftwareVersion(String.valueOf(gunVersion));
        // 枪的sn
        StringBuilder snBuilder = new StringBuilder();
        long gunSnHigh = map.get(DeviceInfoRegisterAddress.GUN_HEAD_SN_HIGH).get(0).getValue();
        Log.d(TAG, "gunSnHigh: "+Integer.toHexString((int) gunSnHigh));
        long gunSnLow = map.get(DeviceInfoRegisterAddress.GUN_HEAD_SN_LOW).get(0).getValue();
        Log.d(TAG, "gunSnLow: "+Integer.toHexString((int) gunSnLow));
        snBuilder.append(Integer.toHexString((int) gunSnHigh));
        snBuilder.append(Integer.toHexString((int) gunSnLow));
        deviceInfo.setGunSn(snBuilder.toString());
        Log.d(TAG, "deviceInfoConvert: 枪头SN:"+deviceInfo.getGunSn()+",gunSnHigh:"+gunSnHigh+",gunSnLow:"+gunSnLow);
        return deviceInfo;
    }

    /**
     * 设备状态转换
     * @param filedList
     * @param deviceStatus
     * @return
     */
    public static DeviceStatus deviceStatusConvert(List<ModbusReadFiled> filedList, DeviceStatus deviceStatus){
        if (deviceStatus==null){
            deviceStatus = new DeviceStatus();
        }
        Map<Integer, List<ModbusReadFiled>> map = filedGroup(filedList);
        applyRegisterValue(map, DeviceStatusRegisterAddress.DEVICE_TYPE, deviceStatus::setDeviceType);
        applyRegisterValue(map, DeviceStatusRegisterAddress.DEVICE_HARDWARE_VERSION, deviceStatus::setHardwareVersion);
        applyRegisterValue(map, DeviceStatusRegisterAddress.DEVICE_SOFTWARE_VERSION, deviceStatus::setSoftwareVersion);
        applyRegisterValue(map, DeviceStatusRegisterAddress.OTA_UPGRADE_COMMAND, deviceStatus::setOtaUpgradeCmd);
        applyRegisterValue(map, DeviceStatusRegisterAddress.REQUEST_FIRMWARE_HARDWARE_VERSION, deviceStatus::setReqHardFirmwareVersion);
        applyRegisterValue(map, DeviceStatusRegisterAddress.REQUEST_FIRMWARE_SOFTWARE_VERSION, deviceStatus::setReqSoftwareVersion);
        applyRegisterValue(map, DeviceStatusRegisterAddress.REQUEST_FIRMWARE_OFFSET_ADDRESS_HIGH, deviceStatus::setReqFirmwareOffsetHigh);
        applyRegisterValue(map, DeviceStatusRegisterAddress.REQUEST_FIRMWARE_OFFSET_ADDRESS_LOW, deviceStatus::setReqFirmwareOffsetLow);
        applyRegisterValue(map, DeviceStatusRegisterAddress.REQUEST_FIRMWARE_DATA_LENGTH, deviceStatus::setReqFirmwareDataLength);
        applyRegisterValue(map, DeviceStatusRegisterAddress.GUN_ALARM_STATUS_FIELD_1, deviceStatus::setGunAlarmSeg1);
        applyRegisterValue(map, DeviceStatusRegisterAddress.GUN_ALARM_STATUS_FIELD_2, deviceStatus::setGunAlarmSeg2);
        applyRegisterValue(map, DeviceStatusRegisterAddress.GUN_ALARM_STATUS_FIELD_3, deviceStatus::setGunAlarmSeg3);
        applyRegisterValue(map, DeviceStatusRegisterAddress.GUN_ALARM_STATUS_FIELD_4, deviceStatus::setGunAlarmSeg4);
        applyRegisterValue(map, DeviceStatusRegisterAddress.LASER_ALARM_STATUS_FIELD_1, deviceStatus::setLaserAlarmSeg1);
        applyRegisterValue(map, DeviceStatusRegisterAddress.LASER_ALARM_STATUS_FIELD_2, deviceStatus::setLaserAlarmSeg2);
        applyRegisterValue(map, DeviceStatusRegisterAddress.LASER_ALARM_STATUS_FIELD_3, deviceStatus::setLaserAlarmSeg3);
        applyRegisterValue(map, DeviceStatusRegisterAddress.LASER_ALARM_STATUS_FIELD_4, deviceStatus::setLaserAlarmSeg4);
        applyRegisterValue(map, DeviceStatusRegisterAddress.WIRE_FEEDER_ALARM_STATUS_FIELD_1, deviceStatus::setWireFeederAlarmSeg1);
        applyRegisterValue(map, DeviceStatusRegisterAddress.WIRE_FEEDER_ALARM_STATUS_FIELD_2, deviceStatus::setWireFeederAlarmSeg2);
        applyRegisterValue(map, DeviceStatusRegisterAddress.CONTROL_CARD_ALARM_STATUS_FIELD_1, deviceStatus::setControlCardAlarmSeg1);
        applyRegisterValue(map, DeviceStatusRegisterAddress.CONTROL_CARD_ALARM_STATUS_FIELD_2, deviceStatus::setControlCardAlarmSeg2);
        applyRegisterValue(map, DeviceStatusRegisterAddress.MACHINE_STATUS_FIELD_1, deviceStatus::setMachineStatusSeg1);
        applyRegisterValue(map, DeviceStatusRegisterAddress.MACHINE_STATUS_FIELD_2, deviceStatus::setMachineStatusSeg2);
        applyEmergencyStopCommAlarmReset(deviceStatus);
        return deviceStatus;
    }

    /**
     * When the machine e-stop is pressed, treat laser and wire feeder comm alarms as cleared.
     * Hardware may still report bit0 while subsystems are de-energized; UI and guards read the
     * normalized {@link DeviceStatus} snapshot instead of raw Modbus values.
     */
    static void applyEmergencyStopCommAlarmReset(@NonNull DeviceStatus deviceStatus) {
        if (!deviceStatus.isEmergencyStopTriggered()) {
            return;
        }
        Integer laserAlarmSeg1 = deviceStatus.getLaserAlarmSeg1();
        if (laserAlarmSeg1 != null) {
            deviceStatus.setLaserAlarmSeg1(laserAlarmSeg1 & ~0x1);
        }
        Integer wireFeederAlarmSeg1 = deviceStatus.getWireFeederAlarmSeg1();
        if (wireFeederAlarmSeg1 != null) {
            deviceStatus.setWireFeederAlarmSeg1(wireFeederAlarmSeg1 & ~0x1);
        }
    }

    /**
     * 合并一次完整的设备状态轮询结果；字段不齐时丢弃本次读取并返回 {@code null}。
     */
    public static DeviceStatus mergeDeviceStatusFromPoll(List<ModbusReadFiled> filedList, DeviceStatus deviceStatus) {
        if (DataConvert.isTruncatedResponse(filedList)) {
            return null;
        }
        return deviceStatusConvert(filedList, deviceStatus);
    }

    /**
     * 设备数据转换
     * @param filedList
     * @param deviceData
     * @return
     */
    public static DeviceData deviceDataConvert(List<ModbusReadFiled> filedList, DeviceData deviceData){
        if (deviceData==null){
            deviceData = new DeviceData();
        }
        // 先转为map
        Map<Integer, List<ModbusReadFiled>> map = filedGroup(filedList);
        // 吹气气压
        deviceData.setBlowAirPressure((int) map.get(DeviceDataRegisterAddress.BLOWING_PRESSURE).get(0).getValue());
        // 枪头电机温度
        short gunMotorTempRaw = ShortDataConvertUtils.convertWithBitOperation(map.get(DeviceDataRegisterAddress.GUN_MOTOR_CURRENT).get(0).getValue());
        deviceData.setGunMotorTempRaw((int) gunMotorTempRaw);
        // 枪头电机驱动温度
        short gunDriverBoardTempRaw = ShortDataConvertUtils.convertWithBitOperation(map.get(DeviceDataRegisterAddress.GUN_MOTOR_DRIVE_TEMPERATURE).get(0).getValue());
        deviceData.setGunDriverBoardTempRaw((int) gunDriverBoardTempRaw);
        // 保护镜温度
        short protectionBoardTempRaw = ShortDataConvertUtils.convertWithBitOperation(map.get(DeviceDataRegisterAddress.PROTECTIVE_COVER_TEMPERATURE).get(0).getValue());
        deviceData.setProtectionBoardTempRaw((int) protectionBoardTempRaw);
        // 聚焦镜温度
        short collimatorTempRaw = ShortDataConvertUtils.convertWithBitOperation(map.get(DeviceDataRegisterAddress.COLLIMATOR_TEMPERATURE).get(0).getValue());
        deviceData.setCollimatorTempRaw((int) collimatorTempRaw);
        // 枪头24V电压
        deviceData.setGun24vVoltage((int) map.get(DeviceDataRegisterAddress.GUN_HEAD_24V_VOLTAGE).get(0).getValue());
        // 枪头24V电流
        deviceData.setGun24vCurrent((int) map.get(DeviceDataRegisterAddress.GUN_HEAD_24V_CURRENT).get(0).getValue());
        // 激光反馈功率
        deviceData.setLaserFeedbackPower((int) map.get(DeviceDataRegisterAddress.LASER_FEEDBACK_POWER).get(0).getValue());
        // 泵源板温度
        deviceData.setPumpSourceBoardTemperature((int) map.get(DeviceDataRegisterAddress.PUMP_SOURCE_BOARD_TEMPERATURE).get(0).getValue());
        // 泵源温度
        deviceData.setPumpSourceTemperature((int) map.get(DeviceDataRegisterAddress.PUMP_SOURCE_TEMPERATURE).get(0).getValue());
        // 激光电流
        deviceData.setLaserCurrent((int) map.get(DeviceDataRegisterAddress.LASER_CURRENT).get(0).getValue());
        // 激光红光电流
        deviceData.setLaserRedCurrent((int) map.get(DeviceDataRegisterAddress.LASER_RED_LIGHT_CURRENT).get(0).getValue());
        // 泵源电流（0x0071，已废弃字段，仍写入 DeviceData 以兼容旧序列化）
        deviceData.setPumpSourceCurrent((int) map.get(DeviceDataRegisterAddress.PUMP_SOURCE_CURRENT).get(0).getValue());
        // 环境温度
        deviceData.setEnvironmentTemperature((int) map.get(DeviceDataRegisterAddress.AMBIENT_TEMPERATURE).get(0).getValue());
        return deviceData;
    }

    /**
     * 合并一次完整的设备数据轮询结果；字段不齐时丢弃本次读取并返回 {@code null}。
     */
    public static DeviceData mergeDeviceDataFromPoll(List<ModbusReadFiled> filedList, DeviceData deviceData) {
        if (DataConvert.isTruncatedResponse(filedList)) {
            return null;
        }
        return deviceDataConvert(filedList, deviceData);
    }
}
