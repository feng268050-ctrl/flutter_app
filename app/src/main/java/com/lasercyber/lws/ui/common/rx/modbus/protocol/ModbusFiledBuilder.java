package com.lasercyber.lws.ui.common.rx.modbus.protocol;

import android.util.Log;

import androidx.annotation.NonNull;

import com.blankj.utilcode.util.FileUtils;
import com.blankj.utilcode.util.GsonUtils;
import com.lasercyber.lws.ui.bean.entity.AdvancedSettings;
import com.lasercyber.lws.ui.bean.entity.BaseDeviceControlData;
import com.lasercyber.lws.ui.bean.entity.ControllerUpgradeDataCache;
import com.lasercyber.lws.ui.bean.entity.ControllerUpgradePackage;
import com.lasercyber.lws.ui.bean.entity.DeviceControlData;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.entity.vo.AdvancedSettingVo;
import com.lasercyber.lws.ui.common.constant.DeviceUpgradeConstant;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.constant.ModbusProcessType;
import com.lasercyber.lws.ui.common.enums.SwingRangeMode;
import com.lasercyber.lws.ui.common.modbus.register.address.DeviceControllerRegisterAddress;
import com.lasercyber.lws.ui.common.modbus.register.address.DeviceDataRegisterAddress;
import com.lasercyber.lws.ui.common.modbus.register.address.DeviceInfoRegisterAddress;
import com.lasercyber.lws.ui.common.modbus.register.address.DeviceSettingRegisterAddress;
import com.lasercyber.lws.ui.common.modbus.register.address.DeviceStatusRegisterAddress;
import com.lasercyber.lws.ui.common.modbus.register.address.DeviceUpgradeRegisterAddress;
import com.lasercyber.lws.ui.common.modbus.register.address.DeviceWorkmanshipRegisterAddress;
import com.lasercyber.lws.ui.common.utils.BitSequenceCombineUtils;
import com.lasercyber.lws.ui.common.utils.ByteCombineUtils;
import com.lasercyber.lws.ui.common.utils.DefaultValueUtils;
import com.lasercyber.lws.ui.common.utils.UpgradeFileReaderUtils;
import com.lasercyber.lws.ui.common.utils.convert.AdvancedSettingConvertUtil;

import java.io.File;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Objects;

import cn.hutool.core.convert.Convert;
import cn.hutool.core.io.FileUtil;

/**
 * modbus字段建造者
 */
public class ModbusFiledBuilder {
    private static final String TAG = LogTAGConstant.ModbusFiledBuilder;

    /**
     * 创建设备状态的字段
     *
     * @return
     */
    public static List<ModbusReadFiled> createDeviceStatus() {
        return List.of(
                ModbusReadFiled.create(DeviceStatusRegisterAddress.DEVICE_TYPE),
                ModbusReadFiled.create(DeviceStatusRegisterAddress.DEVICE_HARDWARE_VERSION),
                ModbusReadFiled.create(DeviceStatusRegisterAddress.DEVICE_SOFTWARE_VERSION),
                ModbusReadFiled.create(DeviceStatusRegisterAddress.OTA_UPGRADE_COMMAND),
                ModbusReadFiled.create(DeviceStatusRegisterAddress.REQUEST_FIRMWARE_HARDWARE_VERSION),
                ModbusReadFiled.create(DeviceStatusRegisterAddress.REQUEST_FIRMWARE_SOFTWARE_VERSION),
                ModbusReadFiled.create(DeviceStatusRegisterAddress.REQUEST_FIRMWARE_OFFSET_ADDRESS_HIGH),
                ModbusReadFiled.create(DeviceStatusRegisterAddress.REQUEST_FIRMWARE_OFFSET_ADDRESS_LOW),
                ModbusReadFiled.create(DeviceStatusRegisterAddress.REQUEST_FIRMWARE_DATA_LENGTH),
                ModbusReadFiled.create(DeviceStatusRegisterAddress.GUN_ALARM_STATUS_FIELD_1),
                ModbusReadFiled.create(DeviceStatusRegisterAddress.GUN_ALARM_STATUS_FIELD_2),
                ModbusReadFiled.create(DeviceStatusRegisterAddress.GUN_ALARM_STATUS_FIELD_3),
                ModbusReadFiled.create(DeviceStatusRegisterAddress.GUN_ALARM_STATUS_FIELD_4),
                ModbusReadFiled.create(DeviceStatusRegisterAddress.LASER_ALARM_STATUS_FIELD_1),
                ModbusReadFiled.create(DeviceStatusRegisterAddress.LASER_ALARM_STATUS_FIELD_2),
                ModbusReadFiled.create(DeviceStatusRegisterAddress.LASER_ALARM_STATUS_FIELD_3),
                ModbusReadFiled.create(DeviceStatusRegisterAddress.LASER_ALARM_STATUS_FIELD_4),
                ModbusReadFiled.create(DeviceStatusRegisterAddress.WIRE_FEEDER_ALARM_STATUS_FIELD_1),
                ModbusReadFiled.create(DeviceStatusRegisterAddress.WIRE_FEEDER_ALARM_STATUS_FIELD_2),
                ModbusReadFiled.create(DeviceStatusRegisterAddress.CONTROL_CARD_ALARM_STATUS_FIELD_1),
                ModbusReadFiled.create(DeviceStatusRegisterAddress.CONTROL_CARD_ALARM_STATUS_FIELD_2),
                ModbusReadFiled.create(DeviceStatusRegisterAddress.MACHINE_STATUS_FIELD_1),
                ModbusReadFiled.create(DeviceStatusRegisterAddress.MACHINE_STATUS_FIELD_2)
        );
    }

    /** Minimal status read for post-transfer OTA device confirm ({@code otaUpgradeCmd}). */
    public static List<ModbusReadFiled> createOtaUpgradeCommandRead() {
        return List.of(ModbusReadFiled.create(DeviceStatusRegisterAddress.OTA_UPGRADE_COMMAND));
    }

    /**
     * 创建设备信息的字段
     *
     * @return
     */
    public static List<ModbusReadFiled> createDeviceInfo() {
        ArrayList<ModbusReadFiled> list = new ArrayList<>();
        list.add(ModbusReadFiled.create(DeviceInfoRegisterAddress.LASER_HARDWARE_VERSION_HIGH));
        list.add(ModbusReadFiled.create(DeviceInfoRegisterAddress.LASER_HARDWARE_VERSION_LOW));
        list.add(ModbusReadFiled.create(DeviceInfoRegisterAddress.LASER_SOFTWARE_VERSION_HIGH));
        list.add(ModbusReadFiled.create(DeviceInfoRegisterAddress.LASER_SOFTWARE_VERSION_LOW));
        list.add(ModbusReadFiled.create(DeviceInfoRegisterAddress.WIRE_FEEDER_HARDWARE_VERSION));
        list.add(ModbusReadFiled.create(DeviceInfoRegisterAddress.WIRE_FEEDER_SOFTWARE_VERSION));
        list.add(ModbusReadFiled.create(DeviceInfoRegisterAddress.GUN_HEAD_HARDWARE_VERSION));
        list.add(ModbusReadFiled.create(DeviceInfoRegisterAddress.GUN_HEAD_SOFTWARE_VERSION));
        list.add(ModbusReadFiled.create(DeviceInfoRegisterAddress.GUN_HEAD_SN_HIGH));
        list.add(ModbusReadFiled.create(DeviceInfoRegisterAddress.GUN_HEAD_SN_LOW));
        return list;
    }

    /**
     * 创建设备数据字段
     *
     * @return
     */
    public static List<ModbusReadFiled> createDeviceData() {
        ArrayList<ModbusReadFiled> list = new ArrayList<>();
        list.add(ModbusReadFiled.create(DeviceDataRegisterAddress.BLOWING_PRESSURE));
        list.add(ModbusReadFiled.create(DeviceDataRegisterAddress.GUN_MOTOR_CURRENT));
        list.add(ModbusReadFiled.create(DeviceDataRegisterAddress.GUN_MOTOR_DRIVE_TEMPERATURE));
        list.add(ModbusReadFiled.create(DeviceDataRegisterAddress.PROTECTIVE_COVER_TEMPERATURE));
        list.add(ModbusReadFiled.create(DeviceDataRegisterAddress.COLLIMATOR_TEMPERATURE));
        list.add(ModbusReadFiled.create(DeviceDataRegisterAddress.GUN_HEAD_24V_VOLTAGE));
        list.add(ModbusReadFiled.create(DeviceDataRegisterAddress.GUN_HEAD_24V_CURRENT));
        for (int i = DeviceDataRegisterAddress.RESERVED_START; i <= DeviceDataRegisterAddress.RESERVED_END; i++) {
            list.add(ModbusReadFiled.create(i));
        }
        list.add(ModbusReadFiled.create(DeviceDataRegisterAddress.LASER_FEEDBACK_POWER));
        list.add(ModbusReadFiled.create(DeviceDataRegisterAddress.PUMP_SOURCE_BOARD_TEMPERATURE));
        list.add(ModbusReadFiled.create(DeviceDataRegisterAddress.PUMP_SOURCE_TEMPERATURE));
        list.add(ModbusReadFiled.create(DeviceDataRegisterAddress.LASER_CURRENT));
        list.add(ModbusReadFiled.create(DeviceDataRegisterAddress.LASER_RED_LIGHT_CURRENT));
        list.add(ModbusReadFiled.create(DeviceDataRegisterAddress.PUMP_SOURCE_CURRENT));
        list.add(ModbusReadFiled.create(DeviceDataRegisterAddress.AMBIENT_TEMPERATURE));
        return list;
    }

    /**
     * 创建设备设置字段
     *
     * @param advancedSettingVo
     * @return
     */
    public static List<ModbusHexData> createWriteDeviceSetting(AdvancedSettingVo advancedSettingVo) {
        AdvancedSettings parameterSettings = AdvancedSettingConvertUtil.convertToAdvancedSettings(advancedSettingVo);
        return doCreateWriteDeviceSetting(parameterSettings);
    }

    public static @NonNull List<ModbusHexData> doCreateWriteDeviceSetting(AdvancedSettings advancedSetting) {
        AdvancedSettings defaultData = DefaultValueUtils.createDefaultAdvancedSettings();
        if (advancedSetting == null) {
            advancedSetting = defaultData;
        }
        int SwingWidth = Convert.toInt(advancedSetting.getProperSwingWidth() == null ? defaultData.getProperSwingWidth() : advancedSetting.getProperSwingWidth());
        SwingWidth+=75;
        return List.of(
                ModbusWriteIntFiled.create(
                        DeviceSettingRegisterAddress.ZERO_POINT_CORRECTION,
                        Convert.toInt(advancedSetting.getZeroPointCorrection() == null ? defaultData.getZeroPointCorrection() * 10 : advancedSetting.getZeroPointCorrection() * 10)
                ),
                ModbusWriteIntFiled.create(
                        DeviceSettingRegisterAddress.SWING_WIDTH_CORRECTION,
                        SwingWidth != 0 ? SwingWidth : 1
                ),
                ModbusWriteIntFiled.create(
                        DeviceSettingRegisterAddress.LASER_START_POWER,
                        advancedSetting.getLaserStartPower() == null ? defaultData.getLaserStartPower().intValue() * 100 : advancedSetting.getLaserStartPower().intValue() * 100
                ),
                ModbusWriteIntFiled.create(
                        DeviceSettingRegisterAddress.LASER_END_POWER,
                        advancedSetting.getLaserEndPower() == null ? defaultData.getLaserEndPower().intValue() * 100 : advancedSetting.getLaserEndPower().intValue() * 100
                ),
                ModbusWriteIntFiled.create(
                        DeviceSettingRegisterAddress.BLOWING_PRESSURE_THRESHOLD,
                        advancedSetting.getBlowPressureThreshold() == null ? defaultData.getBlowPressureThreshold().intValue() : advancedSetting.getBlowPressureThreshold().intValue()
                ),
                ModbusWriteIntFiled.create(
                        DeviceSettingRegisterAddress.RED_LIGHT_OFFSET,
                        advancedSetting.getRedLightOffset() == null ? defaultData.getRedLightOffset().intValue() : advancedSetting.getRedLightOffset().intValue()
                ),
                ModbusWriteIntFiled.create(
                        DeviceSettingRegisterAddress.SWING_SPEED_UPPER_LIMIT,
                        advancedSetting.getSwingSpeedUpperLimit() == null ? defaultData.getSwingSpeedUpperLimit().intValue() : advancedSetting.getSwingSpeedUpperLimit().intValue()
                ),
                ModbusWriteIntFiled.create(
                        DeviceSettingRegisterAddress.SWING_SPEED_LOWER_LIMIT,
                        advancedSetting.getSwingSpeedLowerLimit() == null ? defaultData.getSwingSpeedLowerLimit().intValue() : advancedSetting.getSwingSpeedLowerLimit().intValue()
                ),
                ModbusWriteIntFiled.create(
                        DeviceSettingRegisterAddress.MANUAL_WIRE_FEED_SPEED,
                        advancedSetting.getManualWireFeedSpeed() == null ? defaultData.getManualWireFeedSpeed().intValue() : advancedSetting.getManualWireFeedSpeed().intValue()
                ),
                ModbusWriteIntFiled.create(
                        DeviceSettingRegisterAddress.MANUAL_DRAW_STRING_SPEED,
                        advancedSetting.getManualDrawStringSpeed() == null ? defaultData.getManualDrawStringSpeed().intValue() : advancedSetting.getManualDrawStringSpeed().intValue()
                ),
                ModbusWriteIntFiled.create(
                        DeviceSettingRegisterAddress.INLET_GAS_PRESSURE_THRESHOLD,
                        advancedSetting.getInletGasPressureThreshold() == null ? defaultData.getInletGasPressureThreshold().intValue() : advancedSetting.getInletGasPressureThreshold().intValue()
                ),
                ModbusWriteIntFiled.create(
                        DeviceSettingRegisterAddress.DRIVER_TEMPERATURE_ALARM_THRESHOLD,
                        toTenths(advancedSetting.getDriverTemperatureAlarmThreshold(), defaultData.getDriverTemperatureAlarmThreshold())
                ),
                ModbusWriteIntFiled.create(
                        DeviceSettingRegisterAddress.PROTECTIVE_LENS_TEMPERATURE_ALARM_THRESHOLD,
                        toTenths(advancedSetting.getProtectiveLensTemperatureAlarmThreshold(), defaultData.getProtectiveLensTemperatureAlarmThreshold())
                ),
                ModbusWriteIntFiled.create(
                        DeviceSettingRegisterAddress.COLLIMATING_LENS_TEMPERATURE_ALARM_THRESHOLD,
                        toTenths(advancedSetting.getCollimatingLensTemperatureAlarmThreshold(), defaultData.getCollimatingLensTemperatureAlarmThreshold())
                ),
                ModbusWriteIntFiled.create(
                        DeviceSettingRegisterAddress.MOTOR_TEMPERATURE_ALARM_THRESHOLD,
                        toTenths(advancedSetting.getMotorTemperatureAlarmThreshold(), defaultData.getMotorTemperatureAlarmThreshold())
                ),
                ModbusWriteIntFiled.create(
                        DeviceSettingRegisterAddress.TEMPERATURE_ALARM_RECOVERY_INTERVAL,
                        toTenths(advancedSetting.getTemperatureAlarmRecoveryInterval(), defaultData.getTemperatureAlarmRecoveryInterval())
                )
        );
    }

    private static int toTenths(Double value, Double defaultValue) {
        Double source = value == null ? defaultValue : value;
        return Convert.toInt(source * 10);
    }

    /**
     * 创建设备控制字段
     *
     * @param deviceControlData
     * @return
     */
    public static List<ModbusHexData> createDeviceControlData(BaseDeviceControlData deviceControlData) {
        Log.d(TAG, "转换工艺模式切换配置:"+GsonUtils.toJson(deviceControlData));
        ArrayList<ModbusHexData> list = new ArrayList<>();

        list.add(ModbusWriteIntFiled.create(
                DeviceControllerRegisterAddress.ACCESSORY_MODEL_FIELD_1,
                ByteCombineUtils.combineToShort(deviceControlData.getLaserDeviceType(), deviceControlData.getGunDeviceType())
        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceControllerRegisterAddress.ACCESSORY_MODEL_FIELD_2,
                ByteCombineUtils.combineToShort(0, deviceControlData.getWireFeedDeviceType())
        ));

        SwingRangeMode swingRangeMode = SwingRangeMode.find(deviceControlData.getModel(), deviceControlData.getGunDeviceType());
        Log.d(TAG, "匹配到的枚举"+swingRangeMode);
        list.add(ModbusWriteIntFiled.create(
                DeviceControllerRegisterAddress.GUN_DRIVE_TYPE,
                swingRangeMode!=null?swingRangeMode.getDriveType():0
        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceControllerRegisterAddress.GUN_SWING_RANGE_MODE,
                swingRangeMode!=null? swingRangeMode.getSwingMode():0
        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceControllerRegisterAddress.PROCESS_TYPE,
                ModbusProcessType.convertToModbusType(deviceControlData.getModel())
        ));
        return list;
    }

    /**
     * 创建设备控制开关字段
     *
     * @param deviceControlData
     * @return
     */
    public static List<ModbusHexData> createDeviceControlSwitchData(DeviceControlData deviceControlData) {
        // 控制状态
        int[] controlStatusArr = new int[]{
                deviceControlData.getLaserStatus(), // 激光状态
                deviceControlData.getManualGas(), // 手动送气
                deviceControlData.getWireFeedEnable(), // 手动送丝工作
                deviceControlData.getWireFeedDirection(), // 送丝机方向
                deviceControlData.getAutoWireFeedEnable() // 自动送丝使能
        };
        Log.d(TAG, "生成控制状态切换的配置："+ GsonUtils.toJson(deviceControlData));
        Number controlStatus = BitSequenceCombineUtils.combineIntsWithBitCount(1, controlStatusArr);
        return List.of(ModbusWriteIntFiled.create(DeviceControllerRegisterAddress.CONTROL_FIELD_1, controlStatus.intValue()));
    }

    /**
     * 摆动宽度寄存器值：UI 毫米值放大 10 倍；宽幅清洗再先除以 5。
     */
    static int encodeSwingWidthRegister(ProcessParametersData processParametersData) {
        if (processParametersData == null || processParametersData.getSwingWidth() == null) {
            return 0;
        }
        double swingWidthMm = processParametersData.getSwingWidth();
        if (Objects.equals(processParametersData.getProcessType(), ModelConstant.WIDTH_CLEAN)) {
            swingWidthMm = swingWidthMm / 5d;
        }
        return BigDecimal.valueOf(swingWidthMm).multiply(BigDecimal.TEN).intValue();
    }

    /**
     * 创建工艺参数字段
     *
     * @param processParametersData
     * @return
     */
    public static List<ModbusHexData> createProcessParametersData(ProcessParametersData processParametersData) {
        Log.d(TAG, "转换工艺参数:"+ GsonUtils.toJson(processParametersData));
        if (processParametersData.getLaserPower() == null || processParametersData.getLaserPower() <= 0) {
            Log.e(TAG, "========================下发工艺参数异常，当前激光功率为0===================");
            Log.e(TAG, Arrays.toString(Thread.currentThread().getStackTrace()));
        }
        ArrayList<ModbusHexData> list = new ArrayList<>();
        int swingFrequency = processParametersData.getSwingFrequency() == null ? 0 : processParametersData.getSwingFrequency();
        int swingWidth = encodeSwingWidthRegister(processParametersData);
        int wireFeedSpeed = processParametersData.getWireFeedSpeed() == null ? 0 : processParametersData.getWireFeedSpeed().intValue();
        int retractLength = processParametersData.getRetractLength() == null ? 0 : processParametersData.getRetractLength().intValue();
        int retractSpeed = processParametersData.getRetractSpeed() == null ? 0 : processParametersData.getRetractSpeed().intValue();
        int fillLength = processParametersData.getFillLength() == null ? 0 : processParametersData.getFillLength().intValue();
        int fillDelay = processParametersData.getFillDelay() == null ? 0 : processParametersData.getFillDelay();
        int blowDelay = processParametersData.getBlowDelay() == null ? 0 : processParametersData.getBlowDelay();
        int closeAirDelay = processParametersData.getCloseAirDelay() == null ? 0 : processParametersData.getCloseAirDelay();
        int closeLightDelay = processParametersData.getCloseLightDelay() == null ? 0 : processParametersData.getCloseLightDelay();
        int powerRampUp = processParametersData.getPowerRampUp() == null ? 0 : processParametersData.getPowerRampUp();
        int powerRampDown = processParametersData.getPowerRampDown() == null ? 0 : processParametersData.getPowerRampDown();
        int pointWeldingDuration = processParametersData.getPointWeldingDuration() == null ? 0 : processParametersData.getPointWeldingDuration();
        int pointWeldingInterval = processParametersData.getPointWeldingInterval() == null ? 0 : processParametersData.getPointWeldingInterval();
        int laserPower = processParametersData.getLaserPower() != null ? processParametersData.getLaserPower() * 100 : 0;
        list.add(ModbusWriteIntFiled.create(
                DeviceWorkmanshipRegisterAddress.LASER_POWER,
                laserPower
        ));
//        Integer laserDutyCycle = processParametersData.getLaserDutyCycle();
//        if (laserDutyCycle==null){
//            laserDutyCycle=0;
//        }
//        // 需要放大一百倍
//        laserDutyCycle=laserDutyCycle*100;
//        if (laserDutyCycle>10000){
//            laserDutyCycle=10000;
//            Log.w(TAG, "激光占空比过大:"+laserDutyCycle);
//        }

        list.add(ModbusWriteIntFiled.create(
                DeviceWorkmanshipRegisterAddress.LASER_DUTY_CYCLE,
                10000
        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceWorkmanshipRegisterAddress.LASER_FREQUENCY,
                5000
        ));
//        list.add(ModbusWriteIntFiled.create(
//                DeviceWorkmanshipRegisterAddress.PIERCING_POWER,
//                processParametersData.getPerforationPower()
//        ));
        // 穿孔功率和激光功率一样，暂时
        list.add(ModbusWriteIntFiled.create(
                DeviceWorkmanshipRegisterAddress.PIERCING_POWER,
                laserPower
        ));
//        list.add(ModbusWriteIntFiled.create(
//                DeviceWorkmanshipRegisterAddress.PIERCING_POWER,
//                processParametersData.getPerforationPower()!=null?processParametersData.getPerforationPower()*100:0
//        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceWorkmanshipRegisterAddress.PIERCING_FREQUENCY,
                0
        ));
        // 界面上已经去掉，但是协议保留了
//        int perforationDutyCycle = processParametersData.getPerforationDutyCycle() == null ? 0 : processParametersData.getPerforationDutyCycle();
        list.add(ModbusWriteIntFiled.create(
                DeviceWorkmanshipRegisterAddress.PIERCING_DUTY_CYCLE,
                10000
        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceWorkmanshipRegisterAddress.SWING_FREQUENCY,
                swingFrequency
        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceWorkmanshipRegisterAddress.SWING_WIDTH,
                swingWidth
        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceWorkmanshipRegisterAddress.WIRE_FEEDING_SPEED,
                wireFeedSpeed
        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceWorkmanshipRegisterAddress.BACK_DRAW_LENGTH,
                retractLength
        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceWorkmanshipRegisterAddress.BACK_DRAW_SPEED,
                retractSpeed
        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceWorkmanshipRegisterAddress.WIRE_FILLING_LENGTH,
                fillLength
        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceWorkmanshipRegisterAddress.WIRE_FILLING_DELAY,
                fillDelay
        ));
//        int wireFeedingDelay = processParametersData.getWireFeedingDelay() == null ? 200 : processParametersData.getWireFeedingDelay();
        list.add(ModbusWriteIntFiled.create(
                DeviceWorkmanshipRegisterAddress.WIRE_FEEDING_DELAY,
                0
        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceWorkmanshipRegisterAddress.BLOWING_DELAY,
                blowDelay
        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceWorkmanshipRegisterAddress.GAS_OFF_DELAY,
                closeAirDelay
        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceWorkmanshipRegisterAddress.LIGHT_OFF_DELAY,
                closeLightDelay
        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceWorkmanshipRegisterAddress.POWER_RAMP_UP_DURATION,
                powerRampUp
        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceWorkmanshipRegisterAddress.POWER_RAMP_DOWN_DURATION,
                powerRampDown
        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceWorkmanshipRegisterAddress.SPOT_WELDING_DURATION,
                pointWeldingDuration
        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceWorkmanshipRegisterAddress.SPOT_WELDING_INTERVAL,
                pointWeldingInterval
        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceWorkmanshipRegisterAddress.PIERCING_DURATION,
                0
        ));
//        // 加速度(临时)
//        list.add(ModbusWriteIntFiled.create(
//                DeviceWorkmanshipRegisterAddress.ACCELERATION,
//                100
//        ));
        // 预留字段
//        list.add(ModbusWriteIntFiled.create(
//                DeviceWorkmanshipRegisterAddress.RESERVED_SEGMENT_START,
//                0
//        ));
//        list.add(ModbusWriteIntFiled.create(
//                DeviceWorkmanshipRegisterAddress.RESERVED_SEGMENT_END,
//                0
//        ));
        return list;
    }
    /**
     * 创建控制器升级的文件信息数据
     */
    public static List<ModbusHexData> createControllerUpgradeFileInfoData(File file){
        // 创建文件的基础信息
        LinkedList<ModbusHexData> list = createControllerUpgradeFileBaseInfo(file);
        // 固件偏移地址
        list.add(ModbusWriteIntFiled.create(
                DeviceUpgradeRegisterAddress.OTA_FIRMWARE_OFFSET_ADDRESS_HEIGHT,
                0
        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceUpgradeRegisterAddress.OTA_FIRMWARE_OFFSET_ADDRESS_LOW,
                0
        ));
        // OTA固件字节数
        list.add(ModbusWriteIntFiled.create(
                DeviceUpgradeRegisterAddress.OTA_FIRMWARE_BYTE_COUNT,
                0
        ));
        // OTA固件命令
        list.add(ModbusWriteIntFiled.create(
                DeviceUpgradeRegisterAddress.OTA_FIRMWARE_COMMAND,
                DeviceUpgradeConstant.FIRMWARE_INFO
        ));
        return list;
    }

    /**
     * 创建控制器升级的文件数据（分包）
     * <p>控制在100ms~200ms发送一包数据，并且，发送的分包的数据和心跳的速度要相同</p>
     * @param file
     * @return 分包数据
     * key=>偏移地址
     * value=>分包数据
     */
    public static HashMap<Integer, List<ModbusHexData>> createControllerUpgradeFileData(File file) {
        byte[] bytes = FileUtil.readBytes(file);

        int shortLength = (bytes.length%2==0?bytes.length:bytes.length+1) / 2;
        // 每包数据的大小
        int maxPackSize=DeviceUpgradeRegisterAddress.OTA_FIRMWARE_DATA_END-DeviceUpgradeRegisterAddress.OTA_FIRMWARE_DATA_START+1;
        // 分包后的数据
        HashMap<Integer, ControllerUpgradePackage> map = new HashMap<>();
        for (int j = 0; j < shortLength; j++) {
            // 大端序：第2i个byte是高字节，第2i+1个byte是低字节
            // & 0xFF 是为了将byte（有符号）转为无符号的int，避免符号位扩展导致错误
            int highIndex=2 * j;
            int high = bytes[highIndex] & 0xFF;
            int lowIndex=highIndex + 1;
            // 当前包的最大字节数
            int packMaxSize=lowIndex%maxPackSize;
            // 超出了，补零
            int low =0;
            if (lowIndex<=bytes.length-1){
                low=bytes[lowIndex] & 0xFF;
            }else {
                packMaxSize=highIndex%maxPackSize;
            }
            packMaxSize++;
            // 数据
            // 小端模式：先将byte转为无符号int，再移位组合
            short data = (short) (((low & 0xFF) << 8) | (high & 0xFF));
            // 当前包的索引
            int packIndex=j/maxPackSize;
            ControllerUpgradePackage controllerUpgradePackage = map.computeIfAbsent(packIndex, k -> new ControllerUpgradePackage());
            // 当前数据的内存地址
            int address=DeviceUpgradeRegisterAddress.OTA_FIRMWARE_DATA_START+j%maxPackSize;
            ModbusWriteIntFiled modbusWriteIntFiled = ModbusWriteIntFiled.create(
                    address,
                    data
            );
            controllerUpgradePackage.push(packMaxSize,high+low,modbusWriteIntFiled);

        }
        // 分包后的数据
//        List<List<ModbusHexData>> list = new ArrayList<>();
        HashMap<Integer, List<ModbusHexData>> dataMap = new HashMap<>();
        // 创建文件的基础信息
        LinkedList<ModbusHexData> fileBaseInfoModbus = createControllerUpgradeFileBaseInfo(file);
        // 创建升级的预留字段
        List<ModbusHexData> upgradeEmptyFiled = createUpgradeEmptyFiled();
        // 组装每一包的协议数据
        for (int i = 0; i < shortLength/maxPackSize+1; i++) {
            ControllerUpgradePackage controllerUpgradePackage = map.get(i);
            LinkedList<ModbusHexData> modbusHexDataList = controllerUpgradePackage.getList();
            int filedSize = modbusHexDataList.size();
            // 添加升级的预留字段
            modbusHexDataList.addAll(0,upgradeEmptyFiled);
            // 每包固件数据CRC
            int[] crcCodeArr = ByteCombineUtils.splitLongToHighLowInt(controllerUpgradePackage.getPackCheckCode());
            modbusHexDataList.addFirst(ModbusWriteIntFiled.create(
                    DeviceUpgradeRegisterAddress.FIRMWARE_PACKET_CRC_END,
                    crcCodeArr[1]
            ));
            modbusHexDataList.addFirst(ModbusWriteIntFiled.create(
                    DeviceUpgradeRegisterAddress.FIRMWARE_PACKET_CRC_START,
                    crcCodeArr[0]
            ));
            // OTA固件命令
            modbusHexDataList.addFirst(ModbusWriteIntFiled.create(
                    DeviceUpgradeRegisterAddress.OTA_FIRMWARE_COMMAND,
                    DeviceUpgradeConstant.FIRMWARE_DATA
            ));
            // OTA固件字节数
            modbusHexDataList.addFirst(ModbusWriteIntFiled.create(
                    DeviceUpgradeRegisterAddress.OTA_FIRMWARE_BYTE_COUNT,
                    filedSize*2
            ));
            int offsetAddress=i*maxPackSize*2;
            // 固件偏移地址
            int[] offsetAddressArr = ByteCombineUtils.splitLongToHighLowInt(offsetAddress);
            modbusHexDataList.addFirst(ModbusWriteIntFiled.create(
                    DeviceUpgradeRegisterAddress.OTA_FIRMWARE_OFFSET_ADDRESS_LOW,
                    // 上一包的长度
                    offsetAddressArr[1]
            ));
            modbusHexDataList.addFirst(ModbusWriteIntFiled.create(
                    DeviceUpgradeRegisterAddress.OTA_FIRMWARE_OFFSET_ADDRESS_HEIGHT,
                    // 上一包的长度
                    offsetAddressArr[0]
            ));
            // 固件硬件版本、软件版本、固件大小
            modbusHexDataList.addAll(0,fileBaseInfoModbus);
            dataMap.put(offsetAddress, modbusHexDataList);
//            list.add(modbusHexDataList);
        }
        return dataMap;
    }

    private static List<ModbusHexData> createUpgradeEmptyFiled() {
        LinkedList<ModbusHexData> emptyList = new LinkedList<>();
        for (int k = DeviceUpgradeRegisterAddress.RESERVED_SEGMENT_1_START; k <= DeviceUpgradeRegisterAddress.RESERVED_SEGMENT_1_END; k++) {
            emptyList.addLast(ModbusWriteIntFiled.create(
                    k,
                    0
            ));
        }
        return emptyList;
    }

    /**
     * 创建控制器升级的文件基础信息数据
     * @param file
     * @return
     */
    public static @NonNull LinkedList<ModbusHexData> createControllerUpgradeFileBaseInfo(File file) {
        String fileName = file.getName();
        LinkedList<ModbusHexData> list = new LinkedList<>();
        list.add(ModbusWriteIntFiled.create(
                DeviceUpgradeRegisterAddress.OTA_FIRMWARE_HARDWARE_VERSION,
                UpgradeFileReaderUtils.getFileHardwareVersion(fileName)
        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceUpgradeRegisterAddress.OTA_FIRMWARE_SOFTWARE_VERSION,
                UpgradeFileReaderUtils.getFileSoftwareVersion(fileName)
        ));
        // 文件大小
        long fileLength = FileUtils.getLength(file);
        int[] sizeArr = ByteCombineUtils.splitLongToHighLowInt(fileLength);
        list.add(ModbusWriteIntFiled.create(
                DeviceUpgradeRegisterAddress.OTA_FIRMWARE_SIZE_HEIGHT,
                sizeArr[0]
        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceUpgradeRegisterAddress.OTA_FIRMWARE_SIZE_LOW,
                sizeArr[1]
        ));
        // 校验码
        long checkCode=0;
        byte[] bytes = FileUtil.readBytes(file);
        for (byte b : bytes) {
            checkCode += b & 0xFF;
        }
        int[] checkCodeArr = ByteCombineUtils.splitLongToHighLowInt(checkCode);
        list.add(ModbusWriteIntFiled.create(
                DeviceUpgradeRegisterAddress.OTA_FIRMWARE_CHECK_CODE_HEIGHT,
                checkCodeArr[0]
        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceUpgradeRegisterAddress.OTA_FIRMWARE_CHECK_CODE_LOW,
                checkCodeArr[1]
        ));
        return list;
    }

    /**
     * 仅创建当前包的升级文件数据
     * @param deviceStatus
     * @param controllerUpgradeDataCache
     * @return
     */
    public static List<ModbusHexData> createControllerUpgradeFilePackageData(DeviceStatus deviceStatus,
                                                                             ControllerUpgradeDataCache controllerUpgradeDataCache) {
        if (deviceStatus == null || deviceStatus.getReqFirmwareDataLength() == null) {
            return null;
        }
        return createControllerUpgradeFilePackageDataAtOffset(
                controllerUpgradeDataCache,
                deviceStatus.getReqFirmwareOffset(),
                deviceStatus.getReqFirmwareDataLength());
    }

    /**
     * Build one OTA firmware data write frame at an app-controlled file offset (no status read).
     */
    public static List<ModbusHexData> createControllerUpgradeFilePackageDataAtOffset(
            ControllerUpgradeDataCache controllerUpgradeDataCache,
            int offset,
            int length) {
        if (controllerUpgradeDataCache == null || length <= 0) {
            return null;
        }
        byte[] fileDataBytes = controllerUpgradeDataCache.readFileData(offset, length);
        if (fileDataBytes == null) {
            return null;
        }
        LinkedList<ModbusHexData> hexDataList = new LinkedList<>(controllerUpgradeDataCache.getBaseFileDataFiled());
        int[] offsetAddressArr = ByteCombineUtils.splitLongToHighLowInt(offset);
        hexDataList.addLast(ModbusWriteIntFiled.create(
                DeviceUpgradeRegisterAddress.OTA_FIRMWARE_OFFSET_ADDRESS_HEIGHT,
                offsetAddressArr[0]
        ));
        hexDataList.addLast(ModbusWriteIntFiled.create(
                DeviceUpgradeRegisterAddress.OTA_FIRMWARE_OFFSET_ADDRESS_LOW,
                offsetAddressArr[1]
        ));
        hexDataList.addLast(ModbusWriteIntFiled.create(
                DeviceUpgradeRegisterAddress.OTA_FIRMWARE_BYTE_COUNT,
                length
        ));
        hexDataList.addLast(ModbusWriteIntFiled.create(
                DeviceUpgradeRegisterAddress.OTA_FIRMWARE_COMMAND,
                DeviceUpgradeConstant.FIRMWARE_DATA
        ));
        return appendFirmwarePayloadAndCrc(hexDataList, fileDataBytes);
    }

    private static List<ModbusHexData> appendFirmwarePayloadAndCrc(
            LinkedList<ModbusHexData> hexDataList,
            byte[] fileDataBytes) {
        int fileInfoIndex = hexDataList.size();
        int dataSize = (fileDataBytes.length % 2 == 0 ? fileDataBytes.length : fileDataBytes.length + 1) / 2;
        int checkCode = 0;
        for (int j = 0; j < dataSize; j++) {
            int highIndex = 2 * j;
            int lowIndex = highIndex + 1;
            int high = fileDataBytes[highIndex] & 0xFF;
            int low = 0;
            if (lowIndex <= fileDataBytes.length - 1) {
                low = fileDataBytes[lowIndex] & 0xFF;
            }
            checkCode += high + low;
            short data = (short) (((low & 0xFF) << 8) | (high & 0xFF));
            int address = DeviceUpgradeRegisterAddress.OTA_FIRMWARE_DATA_START + j;
            hexDataList.addLast(ModbusWriteIntFiled.create(address, data));
        }
        int[] crcCodeArr = ByteCombineUtils.splitLongToHighLowInt(checkCode);
        hexDataList.add(fileInfoIndex++, ModbusWriteIntFiled.create(
                DeviceUpgradeRegisterAddress.FIRMWARE_PACKET_CRC_START,
                crcCodeArr[0]
        ));
        hexDataList.add(fileInfoIndex++, ModbusWriteIntFiled.create(
                DeviceUpgradeRegisterAddress.FIRMWARE_PACKET_CRC_END,
                crcCodeArr[1]
        ));
        hexDataList.addAll(fileInfoIndex, createUpgradeEmptyFiled());
        return hexDataList;
    }

    /**
     * OTA end frame using file metadata (no device status read).
     */
    public static List<ModbusHexData> createUpgradeEndFromFileVersions(
            int hardwareVersion,
            int softwareVersion) {
        LinkedList<ModbusHexData> list = new LinkedList<>();
        list.add(ModbusWriteIntFiled.create(
                DeviceUpgradeRegisterAddress.OTA_FIRMWARE_HARDWARE_VERSION,
                hardwareVersion
        ));
        list.add(ModbusWriteIntFiled.create(
                DeviceUpgradeRegisterAddress.OTA_FIRMWARE_SOFTWARE_VERSION,
                softwareVersion
        ));
        list.add(ModbusWriteIntFiled.create(DeviceUpgradeRegisterAddress.OTA_FIRMWARE_SIZE_HEIGHT, 0));
        list.add(ModbusWriteIntFiled.create(DeviceUpgradeRegisterAddress.OTA_FIRMWARE_SIZE_LOW, 0));
        list.add(ModbusWriteIntFiled.create(DeviceUpgradeRegisterAddress.OTA_FIRMWARE_CHECK_CODE_HEIGHT, 0));
        list.add(ModbusWriteIntFiled.create(DeviceUpgradeRegisterAddress.OTA_FIRMWARE_CHECK_CODE_LOW, 0));
        list.add(ModbusWriteIntFiled.create(DeviceUpgradeRegisterAddress.OTA_FIRMWARE_OFFSET_ADDRESS_HEIGHT, 0));
        list.add(ModbusWriteIntFiled.create(DeviceUpgradeRegisterAddress.OTA_FIRMWARE_OFFSET_ADDRESS_LOW, 0));
        list.add(ModbusWriteIntFiled.create(DeviceUpgradeRegisterAddress.OTA_FIRMWARE_BYTE_COUNT, 0));
        list.add(ModbusWriteIntFiled.create(
                DeviceUpgradeRegisterAddress.OTA_FIRMWARE_COMMAND,
                DeviceUpgradeConstant.FIRMWARE_END
        ));
        list.addAll(createUpgradeEmptyFiled());
        return list;
    }

    /**
     * 创建升级结束
     *
     * @return
     */
    public static List<ModbusHexData> createUpgradeEnd(DeviceStatus deviceStatus) {
        if (deviceStatus == null || deviceStatus.getHardwareVersion() == null || deviceStatus.getSoftwareVersion() == null) {
            return List.of();
        }
        return createUpgradeEndFromFileVersions(
                deviceStatus.getHardwareVersion(),
                deviceStatus.getSoftwareVersion());
    }
}
