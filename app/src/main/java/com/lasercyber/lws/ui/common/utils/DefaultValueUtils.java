package com.lasercyber.lws.ui.common.utils;

import com.lasercyber.lws.ui.bean.entity.AdvancedSettings;
import com.lasercyber.lws.ui.bean.entity.CommonSettings;
import com.lasercyber.lws.ui.bean.entity.ParameterSettings;
import com.lasercyber.lws.ui.common.constant.CommonSettingsLanguage;
import com.lasercyber.lws.ui.common.enums.UnitSystem;
import com.lasercyber.lws.ui.bean.entity.MachineStatus;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.entity.WarnInfo;

/**
 * 默认值工具类
 */
public final class DefaultValueUtils {
    /**
     * 创建默认的机台状态
     *
     * @return
     */
    public static MachineStatus createDefaultMachineStatus() {
        MachineStatus machineStatus = new MachineStatus();
        machineStatus.setPumpCurrent(0d);
        machineStatus.setBlowingAirPressure(0d);
        machineStatus.setBlowStatus(0);
        machineStatus.setGunHeadStatus(0);
        machineStatus.setLaserStatus(0);
        machineStatus.setRedLightStatus(0);
        machineStatus.setSafetyLockStatus(0);
        machineStatus.setWireFeedingStatus(0);
        return machineStatus;
    }

    /**
     * 创建默认的告警信息
     *
     * @return
     */
    public static WarnInfo createDefaultWarnInfo() {
        WarnInfo warnInfo = new WarnInfo();
        warnInfo.setPumpBoardTemperature(0d);
        warnInfo.setPumpTemperature(0d);
        warnInfo.setRedLightCurrent(0d);
        warnInfo.setPumpCurrent(0d);
        warnInfo.setForwardLightPDVoltage(0d);
        warnInfo.setMotorDriveTemperature(0d);
        warnInfo.setEnvironmentTemperature(0d);
        warnInfo.setPumpBoardTemperatureStatus(0);
        warnInfo.setCurrentAlarm(0);
        warnInfo.setRedLightCurrentStatus(0);
        warnInfo.setPumpCurrentStatus(0);
        warnInfo.setForwardLightPDVoltageStatus(0);
        warnInfo.setGunHeadCommunication(0);
        warnInfo.setMotorDriveTemperatureStatus(0);
        warnInfo.setEnvironmentTemperatureStatus(0);
        warnInfo.setWireFeedingCommunication(0);
        warnInfo.setPumpTemperatureStatus(0);
        return warnInfo;
    }

    public static CommonSettings createDefaultCommonSettings() {
        CommonSettings settings = new CommonSettings();
        settings.setLanguage(CommonSettingsLanguage.EN_US);
        settings.setUnit(UnitSystem.METRIC.getWireValue());
        settings.setSoundEffect(0);
        settings.setShowBootSelfCheck(true);
        settings.setShowSafetyGroundLockAlarm(false);
        return settings;
    }

    public static ParameterSettings createDefaultParameterSettings() {
        ParameterSettings settings = new ParameterSettings();
        settings.setZeroPointCorrection(0d);
        settings.setProperSwingWidth(0d);
        settings.setLaserStartPower(10d);
        settings.setLaserEndPower(10d);
        settings.setBlowPressureThreshold(0d);
        settings.setRedLightOffset(0);
        settings.setSwingSpeedUpperLimit(0);
        settings.setSwingSpeedLowerLimit(0);
        settings.setManualDrawStringSpeed(15);
        settings.setManualWireFeedSpeed(80);
        settings.setInletGasPressureThreshold(0);
        settings.setDriverTemperatureAlarmThreshold(70d);
        settings.setProtectiveLensTemperatureAlarmThreshold(70d);
        settings.setCollimatingLensTemperatureAlarmThreshold(65d);
        settings.setMotorTemperatureAlarmThreshold(70d);
        settings.setTemperatureAlarmRecoveryInterval(5d);
        return settings;
    }

    public static AdvancedSettings createDefaultAdvancedSettings() {
        AdvancedSettings settings = new AdvancedSettings();
        settings.setZeroPointCorrection(0d);
        settings.setProperSwingWidth(0d);
        settings.setLaserStartPower(10d);
        settings.setLaserEndPower(10d);
        settings.setBlowPressureThreshold(0d);
        settings.setRedLightOffset(0);
        settings.setSwingSpeedUpperLimit(0);
        settings.setSwingSpeedLowerLimit(0);
        settings.setManualDrawStringSpeed(15);
        settings.setManualWireFeedSpeed(80);
        settings.setInletGasPressureThreshold(0);
        settings.setDriverTemperatureAlarmThreshold(70d);
        settings.setProtectiveLensTemperatureAlarmThreshold(70d);
        settings.setCollimatingLensTemperatureAlarmThreshold(65d);
        settings.setMotorTemperatureAlarmThreshold(70d);
        settings.setTemperatureAlarmRecoveryInterval(5d);
        settings.setLensContaminationDetectionEnabled(true);
        settings.setZeroPointOffsetDetectionEnabled(true);
        settings.setKeepLaserOnWhileAlarmed(false);
        settings.setAllowWorkAfterCameraAlarm(false);
        settings.setAllowWorkAfterGasAlarm(false);
        settings.setAllowWorkAfterLensContamination(false);
        settings.setAllowWorkAfterFeederAlarm(false);
        return settings;
    }

    /**
     * 创建默认的工艺参数
     *
     * @return
     */
    public static ProcessParametersData createDefaultProcessParametersData() {
        ProcessParametersData params = new ProcessParametersData();




        // --- 频率相关字段 ---
        params.setSwingFrequency(0);    // 摆动频率（清洗：20~200Hz；焊接：0~220Hz）
        params.setLaserFrequency(0);    // 激光频率（1~5000Hz）
        params.setPerforationFrequency(0); // 穿孔频率（0~2000Hz）

        // --- 宽度相关字段 ---
        params.setSwingWidth(0d);        // 摆动宽度（0~6mm）

        // --- 延时相关字段 ---
        params.setBlowDelay(0);         // 吹气延时（0~10000ms）
        params.setCloseAirDelay(0);     // 关气延时（0~10000ms）
        params.setCloseLightDelay(0);   // 关光延时（0~1000ms）
        params.setFillDelay(0);         // 补丝时延（0~1000ms）
        params.setWireFeedingDelay(0);   // 送丝时延（0~2000ms）

        // --- 时长相关字段 ---
        params.setPerforationDuration(0.0); // 穿孔时长(0.1~2.0s)
        params.setPointWeldingInterval(0); // 点焊间隔（0~10000ms）
        params.setPointWeldingDuration(0); // 点焊持续（0~10000ms）

        // --- 功率缓升缓降相关字段 ---
        params.setPowerRampUp(0);       // 功率缓升（0~1000ms）
        params.setPowerRampDown(0);     // 功率缓降（0~1000ms）

        // --- 送丝/回抽相关字段 ---
        params.setWireFeedSpeed(0d);     // 送丝速度（0~50mm/s）
        params.setRetractLength(0d);     // 回抽长度（0~15mm）
        params.setRetractSpeed(0d);      // 回抽速度（0~300mm/s）
        params.setFillLength(0d);        // 补丝长度（0~15mm）

        // --- 占空比字段 ---
        params.setLaserDutyCycle(0);    // 激光占空比（0~100%）
        params.setPerforationDutyCycle(0); // 穿孔占空比 0~100%

        // --- 激光功率相关字段 ---
        params.setLaserPower(50);        // 激光功率（0~100%）
        params.setLaserFrequency(3000);
        params.setLaserDutyCycle(100);
        params.setCloseAirDelay(200);
        params.setPowerRampUp(150);
        params.setPowerRampDown(150);
        params.setSwingWidth(2.5);
        params.setSwingFrequency(50);
        params.setWireFeedSpeed(10d);
        params.setWireFeedingDelay(0);
        params.setFillDelay(100);
        params.setFillLength(4d);
        params.setRetractLength(3d);
        params.setBlowDelay(150);
        params.setCloseAirDelay(150);
        return params;
    }

    /**
     * 创建连续焊接模式的默认工艺参数
     */
    public static ProcessParametersData createContinuousWeldingProcessParametersData() {
        ProcessParametersData parameters = new ProcessParametersData();
        parameters.setId(1L);
        parameters.setLaserPower(60);
        parameters.setPerforationPower(0);
        parameters.setSwingFrequency(100);
        parameters.setLaserFrequency(1000);
        parameters.setPerforationFrequency(0);
        parameters.setSwingWidth(5d);
        parameters.setBlowDelay(2000);
        parameters.setCloseAirDelay(2000);
        parameters.setCloseLightDelay(2000);
        parameters.setFillDelay(1000);
        parameters.setWireFeedingDelay(1000);
        parameters.setPerforationDuration(0.0);
        parameters.setPointWeldingInterval(0);
        parameters.setPointWeldingDuration(0);
        parameters.setPowerRampUp(2000);
        parameters.setPowerRampDown(2000);
        parameters.setWireFeedSpeed(20d); // 较之前值从19变为20
        parameters.setRetractLength(13d);
        parameters.setRetractSpeed(14d);
        parameters.setFillLength(16d);
        parameters.setLaserDutyCycle(10000);
        parameters.setPerforationDutyCycle(0);
        return parameters;
    }

    /**
     * 创建点焊接默认参数
     */
    public static ProcessParametersData createPointWeldingProcessParametersData() {
        ProcessParametersData parameters = new ProcessParametersData();
        parameters.setLaserPower(60); // 较之前值从6000变为60
        parameters.setPerforationPower(0);
        parameters.setSwingFrequency(100);
        parameters.setLaserFrequency(1000);
        parameters.setPerforationFrequency(0);
        parameters.setSwingWidth(5d);
        parameters.setBlowDelay(2000);
        parameters.setCloseAirDelay(2000);
        parameters.setCloseLightDelay(2000);
        parameters.setFillDelay(1000);
        parameters.setWireFeedingDelay(1000);
        parameters.setPerforationDuration(0.0);
        parameters.setPointWeldingInterval(2000); // 较之前值从0变为2000
        parameters.setPointWeldingDuration(2000); // 较之前值从0变为2000
        parameters.setPowerRampUp(2000);
        parameters.setPowerRampDown(2000);
        parameters.setWireFeedSpeed(20d);
        parameters.setRetractLength(13d);
        parameters.setRetractSpeed(14d);
        parameters.setFillLength(16d); // 注意：类中注释该字段范围为0~15mm，当前值16可能超出范围
        parameters.setLaserDutyCycle(10000); // 注意：类中注释该字段范围为0~100%，当前值10000可能超出范围
        parameters.setPerforationDutyCycle(0);
        return parameters;
    }

    /**
     * 创建焊接模式的默认工艺参数
     *
     * @return
     */
    public static ProcessParametersData createWeldingModelProcessParametersData() {
        ProcessParametersData params = createDefaultProcessParametersData();
        // 表格列名: "扫描频率" -> JavaBean字段: swingFrequency
        params.setSwingFrequency(50);    // 扫描频率 = 50Hz

        // 表格列名: "扫描宽度" -> JavaBean字段: swingWidth
        // 注意：表格单位是mm，JavaBean字段是Integer类型，这里做了取整处理
        params.setSwingWidth(2d);         // 扫描宽度 = 2.5mm (取整为2)

        // 表格列名: "吹气延迟" -> JavaBean字段: blowDelay
        params.setBlowDelay(150);        // 吹气延迟 = 150ms

        // 表格列名: "气体关闭延迟" -> JavaBean字段: closeAirDelay
        params.setCloseAirDelay(150);    // 气体关闭延迟 = 150ms

        // 表格列名: "送丝补偿延迟" -> JavaBean字段: fillDelay
        params.setFillDelay(100);        // 送丝补偿延迟 = 100ms

        // 表格列名: "缓降时长" -> JavaBean字段: slowDescentDuration

        // 表格列名: "送丝速度" -> JavaBean字段: wireFeedSpeed
        params.setWireFeedSpeed(10d);     // 送丝速度 = 10mm/s

        // 表格列名: "丝回抽长度" -> JavaBean字段: retractLength
        params.setRetractLength(3d);      // 丝回抽长度 = 3mm

        // 表格列名: "送丝补偿长度" -> JavaBean字段: fillLength
        params.setFillLength(4d);         // 送丝补偿长度 = 4mm
        return params;
    }

    /**
     * 创建切割的默认参数
     *
     * @return
     */
    public static ProcessParametersData createCuttingProcessParametersData() {
        ProcessParametersData parameters = new ProcessParametersData();

        // 基础字段
        parameters.setId(1L);

//

        // 激光功率相关字段
        parameters.setLaserPower(80); // 激光功率（0~100%），80在合理范围
        parameters.setPerforationPower(40); // 穿孔功率（0~100%），40在合理范围

        // 频率相关字段
        parameters.setSwingFrequency(100); // 摆动频率（清洗：20~200Hz；焊接：0~220Hz），100在合理范围
        parameters.setLaserFrequency(1000); // 激光频率（1~5000Hz），1000在合理范围
        parameters.setPerforationFrequency(50); // 穿孔频率（0~2000Hz），50在合理范围

        // 宽度相关字段
        parameters.setSwingWidth(5d); // 摆动宽度（0~6mm），5在合理范围

        // 延时相关字段
        parameters.setBlowDelay(2000); // 吹气延时（0~10000ms），2000在合理范围
        parameters.setCloseAirDelay(2000); // 关气延时（0~10000ms），2000在合理范围
        parameters.setCloseLightDelay(2000); // 关光延时（0~1000ms），2000超出范围
        parameters.setFillDelay(1000); // 补丝时延（0~1000ms），1000在合理范围
        parameters.setWireFeedingDelay(1000); // 送丝时延（0~2000ms），1000在合理范围

        // 时长相关字段
        parameters.setPerforationDuration(1.5); // 穿孔时长(0.1~2.0s)，1.5在合理范围
        parameters.setPointWeldingInterval(2000); // 点焊间隔（0~10000ms），2000在合理范围
        parameters.setPointWeldingDuration(2000); // 点焊持续（0~10000ms），2000在合理范围

        // 功率缓升缓降相关字段
        parameters.setPowerRampUp(2000); // 功率缓升（0~1000ms），2000超出范围
        parameters.setPowerRampDown(2000); // 功率缓降（0~1000ms），2000超出范围

        // 送丝/回抽相关字段
        parameters.setWireFeedSpeed(20d); // 送丝速度（0~50mm/s），20在合理范围
        parameters.setRetractLength(13d); // 回抽长度（0~15mm），13在合理范围
        parameters.setRetractSpeed(14d); // 回抽速度（0~300mm/s），14在合理范围
        parameters.setFillLength(16d); // 补丝长度（0~15mm），16超出范围

        // 占空比字段
        parameters.setLaserDutyCycle(10000); // 激光占空比（0~100%），10000超出范围
        parameters.setPerforationDutyCycle(500); // 穿孔占空比（0~100%），500超出范围
        return parameters;
    }

    /**
     * 创建焊道清洗的默认参数
     *
     * @return
     */
    public static ProcessParametersData createWeldCleaningProcessParametersData() {
        ProcessParametersData parameters = new ProcessParametersData();
        parameters.setLaserPower(60); // 激光功率（0~100%），当前值60在合理范围内
        parameters.setPerforationPower(0); // 穿孔功率（0~100%），当前值0在合理范围内
        parameters.setSwingFrequency(100); // 摆动频率（清洗：20~200Hz；焊接：0~220Hz），当前值100在合理范围内
        parameters.setLaserFrequency(1000); // 激光频率（1~5000Hz），当前值1000在合理范围内
        parameters.setPerforationFrequency(0); // 穿孔频率（0~2000Hz），当前值0在合理范围内
        parameters.setSwingWidth(5d); // 摆动宽度（0~6mm），当前值5在合理范围内
        parameters.setBlowDelay(2000); // 吹气延时（0~10000ms），当前值2000在合理范围内
        parameters.setCloseAirDelay(2000); // 关气延时（0~10000ms），当前值2000在合理范围内
        parameters.setCloseLightDelay(2000); // 关光延时（0~1000ms），当前值2000超出合理范围
        parameters.setFillDelay(1000); // 补丝时延（0~1000ms），当前值1000在合理范围内
        parameters.setWireFeedingDelay(1000); // 送丝时延（0~2000ms），当前值1000在合理范围内
        parameters.setPerforationDuration(0.0); // 穿孔时长(0.1~2.0s)，当前值0.0超出合理范围
        parameters.setPointWeldingInterval(2000); // 点焊间隔（0~10000ms），当前值2000在合理范围内
        parameters.setPointWeldingDuration(2000); // 点焊持续（0~10000ms），当前值2000在合理范围内
        parameters.setPowerRampUp(2000); // 功率缓升（0~1000ms），当前值2000超出合理范围
        parameters.setPowerRampDown(2000); // 功率缓降（0~1000ms），当前值2000超出合理范围
        parameters.setWireFeedSpeed(20d); // 送丝速度（0~50mm/s），当前值20在合理范围内
        parameters.setRetractLength(13d); // 回抽长度（0~15mm），当前值13在合理范围内
        parameters.setRetractSpeed(14d); // 回抽速度（0~300mm/s），当前值14在合理范围内
        parameters.setFillLength(16d); // 补丝长度（0~15mm），当前值16超出合理范围
        parameters.setLaserDutyCycle(10000); // 激光占空比（0~100%），当前值10000超出合理范围
        parameters.setPerforationDutyCycle(0); // 穿孔占空比（0~100%），当前值0在合理范围内
        return parameters;
    }

    /**
     * 创建宽焊缝清洗的默认参数
     *
     * @return
     */
    public static ProcessParametersData createWideWeldSeamCleaningProcessParametersData() {
        ProcessParametersData parameters = new ProcessParametersData();

        // 基础字段
        parameters.setId(1L);

//

        // 激光功率相关字段
        parameters.setLaserPower(41); // 激光功率（0~100%），41在合理范围
        parameters.setPerforationPower(0); // 穿孔功率（0~100%），0在合理范围

        // 频率相关字段
        parameters.setSwingFrequency(100); // 摆动频率（清洗：20~200Hz；焊接：0~220Hz），100在合理范围
        parameters.setLaserFrequency(1000); // 激光频率（1~5000Hz），1000在合理范围
        parameters.setPerforationFrequency(50); // 穿孔频率（0~2000Hz），50在合理范围

        // 宽度相关字段
        parameters.setSwingWidth(5d); // 摆动宽度（0~6mm），5在合理范围

        // 延时相关字段
        parameters.setBlowDelay(2000); // 吹气延时（0~10000ms），2000在合理范围
        parameters.setCloseAirDelay(2000); // 关气延时（0~10000ms），2000在合理范围
        parameters.setCloseLightDelay(2000); // 关光延时（0~1000ms），2000超出范围
        parameters.setFillDelay(1000); // 补丝时延（0~1000ms），1000在合理范围
        parameters.setWireFeedingDelay(1000); // 送丝时延（0~2000ms），1000在合理范围

        // 时长相关字段
        parameters.setPerforationDuration(1.5); // 穿孔时长(0.1~2.0s)，1.5在合理范围
        parameters.setPointWeldingInterval(2000); // 点焊间隔（0~10000ms），2000在合理范围
        parameters.setPointWeldingDuration(2000); // 点焊持续（0~10000ms），2000在合理范围

        // 功率缓升缓降相关字段
        parameters.setPowerRampUp(2000); // 功率缓升（0~1000ms），2000超出范围
        parameters.setPowerRampDown(2000); // 功率缓降（0~1000ms），2000超出范围

        // 送丝/回抽相关字段
        parameters.setWireFeedSpeed(20d); // 送丝速度（0~50mm/s），20在合理范围
        parameters.setRetractLength(13d); // 回抽长度（0~15mm），13在合理范围
        parameters.setRetractSpeed(14d); // 回抽速度（0~300mm/s），14在合理范围
        parameters.setFillLength(16d); // 补丝长度（0~15mm），16超出范围

        // 占空比字段
        parameters.setLaserDutyCycle(10000); // 激光占空比（0~100%），10000超出范围
        parameters.setPerforationDutyCycle(0); // 穿孔占空比（0~100%），0在合理范围
        return parameters;
    }
}
