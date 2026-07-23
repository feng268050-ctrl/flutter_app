package com.lasercyber.lws.ui.common.utils.convert;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.bean.entity.DeviceData;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.bean.entity.WarnTable;
import com.lasercyber.lws.ui.bean.entity.vo.WarnDialogVo;

import androidx.annotation.Nullable;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.handler.WarnLogEpisodeTracker;
import com.lasercyber.lws.ui.common.constant.WarnLevelConstant;
import com.lasercyber.lws.ui.common.enums.AlarmCodeEnums;
import com.lasercyber.lws.ui.common.handler.WarnDialogSeverity;
import com.lasercyber.lws.ui.common.utils.ShieldingGasAlarmMessageUtil;
import com.lasercyber.lws.ui.common.utils.WarnUtil;
import com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodeController;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;

import cn.hutool.core.date.DateUtil;

public class DeviceStatusConvert {
    private static final String TAG = LogTAGConstant.DeviceStatusConvert;
    private static final Handler MAIN_HANDLER = new Handler(Looper.getMainLooper());
    private static final boolean debugLog = true;

    /**
     * 设备状态转换成报警表
     *
     * @param deviceStatus
     * @return
     */
    public static List<WarnTable> convertToWarnTables(DeviceStatus deviceStatus) {
        ArrayList<WarnTable> list = new ArrayList<>();
        appendControllerTabletCommWarnTable(list, deviceStatus);
        // ===================枪头告警状态 gunAlarmSeg1=====================
        if (deviceStatus.isGunCommunicationAlarm()) {
            // 枪头通信告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 枪头通信告警");
            list.add(createSeriousWarnTable(AlarmCodeEnums.H001.errorCode));
        } else {
            // 当前为告警状态，解除告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H001.errorCode);
        }
        // =======================枪头告警状态段3=================================
        if (deviceStatus.isSensorChannelDiffAlarm()) {
            // 传感器通道差
            if (debugLog) Log.d(TAG, "convertToWarnTables: 传感器通道差");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H002.errorCode));
        } else {
            // 解除传感器通道差告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H002.errorCode);
        }

        if (deviceStatus.isStaticCurrentAbnormalAlarm()) {
            // 静态电流异常
            if (debugLog) Log.d(TAG, "convertToWarnTables: 静态电流异常");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H003.errorCode));
        } else {
            // 解除静态电流异常告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H003.errorCode);
        }

        if (deviceStatus.isMotorWireOpenAlarm()) {
            // 电机连接线开路告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 电机连接线开路告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H004.errorCode));
        } else {
            // 解除电机连接线开路告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H004.errorCode);
        }

        if (deviceStatus.isSensorAbnormalAlarm()) {
            // 传感器异常告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 传感器异常告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H005.errorCode));
        } else {
            // 解除传感器异常告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H005.errorCode);
        }

        if (deviceStatus.isFlashErrorAlarm()) {
            // FLASH出错告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: FLASH出错告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H006.errorCode));
        } else {
            // 解除FLASH出错告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H006.errorCode);
        }

        if (deviceStatus.isFlashUnencryptedAlarm()) {
            // FLASH未加密告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: FLASH未加密告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H007.errorCode));
        } else {
            // 解除FLASH未加密告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H007.errorCode);
        }
        // =====================枪头告警状态段2============================
        if (deviceStatus.isGunMotorOverTemperatureAlarm()) {
            // 枪头电机过温告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 枪头电机过温告警");
            list.add(createSeriousWarnTable(AlarmCodeEnums.H008.errorCode));
        } else {
            // 解除枪头电机过温告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H008.errorCode);
        }

        if (deviceStatus.isDriverTemperatureAlarm()) {
            // 驱动温度告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 驱动温度告警");
            list.add(createSeriousWarnTable(AlarmCodeEnums.H009.errorCode));
        } else {
            // 解除驱动温度告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H009.errorCode);
        }

        if (deviceStatus.isProtectionBoardTemperatureAlarm()) {
            // 保护镜温度告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 保护镜温度告警");
            list.add(createSeriousWarnTable(AlarmCodeEnums.H010.errorCode));
        } else {
            // 解除保护镜温度告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H010.errorCode);
        }

        if (deviceStatus.isStraightTrackTemperatureAlarm()) {
            // 聚焦镜温度报警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 聚焦镜温度报警");
            list.add(createSeriousWarnTable(AlarmCodeEnums.H011.errorCode));
        } else {
            // 聚焦镜温度报警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H011.errorCode);
        }

        if (deviceStatus.is24VUnderVoltageAlarm()) {
            // 24V欠压告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 24V欠压告警");
            list.add(createSeriousWarnTable(AlarmCodeEnums.H012.errorCode));
        } else {
            // 解除24V欠压告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H012.errorCode);
        }

        if (deviceStatus.isDriverOverCurrentAlarm()) {
            // 电机过流告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 电机过流告警");
            list.add(createSeriousWarnTable(AlarmCodeEnums.H013.errorCode));
        } else {
            // 解除电机过流告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H013.errorCode);
        }

        if (deviceStatus.isMotorTrackAbnormalAlarm()) {
            // 电机轨迹异常告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 电机轨迹异常告警");
            list.add(createSeriousWarnTable(AlarmCodeEnums.H014.errorCode));
        } else {
            // 解除电机轨迹异常告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H014.errorCode);
        }

        if (deviceStatus.isMotorStallAlarm()) {
            // 电机堵转告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 电机堵转告警");
            list.add(createSeriousWarnTable(AlarmCodeEnums.H015.errorCode));
        } else {
            // 解除电机堵转告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H015.errorCode);
        }
        // =======================枪头告警状态段4====================
        if (deviceStatus.isMmiOscillatorAbnormalAlarm()) {
            // MMI振荡器异常告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: MMI振荡器异常告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H016.errorCode));
        } else {
            // 解除MMI振荡器异常告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H016.errorCode);
        }

        if (deviceStatus.isHardwareBusErrorAlarm()) {
            // 硬件总线错误告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 硬件总线错误告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H017.errorCode));
        } else {
            // 解除硬件总线错误告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H017.errorCode);
        }

        if (deviceStatus.isMemoryManagementAbnormalAlarm()) {
            // 内存管理异常告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 内存管理异常告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H018.errorCode));
        } else {
            // 解除内存管理异常告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H018.errorCode);
        }

        if (deviceStatus.isMemoryAccessErrorAlarm()) {
            // 内存访问错误告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 内存访问错误告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H019.errorCode));
        } else {
            // 解除内存访问错误告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H019.errorCode);
        }

        if (deviceStatus.isIllegalInstructionAlarm()) {
            // 非法指令告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 非法指令告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H020.errorCode));
        } else {
            // 解除非法指令告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H020.errorCode);
        }

        if (deviceStatus.isWatchdogResetAlarm()) {
            //  看门狗重启告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 看门狗重启告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H021.errorCode));
        } else {
            // 解除看门狗重启告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H021.errorCode);
        }
        // =====================激光器告警状态段1=====================
        if (deviceStatus.isLaserCommunicationAlarm()) {
            // 激光器通信告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 激光器通信告警");
            list.add(createSeriousWarnTable(AlarmCodeEnums.H022.errorCode));
        } else {
            // 解除激光器通信告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H022.errorCode);
        }
//        Log.d(TAG, "convertToWarnTables: 泵板温度告警："+deviceStatus.isPumpBoardTemperatureAlarm());
//        if (deviceStatus.isPumpBoardTemperatureAlarm()) {
//            // 泵板温度告警
//            if (debugLog) Log.d(TAG, "convertToWarnTables: 泵板温度告警");
//            list.add(createSeriousWarnTable(AlarmCodeEnums.E006.errorCode));
//        } else {
//            // 解除泵板温度告警
//            if (WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.E006.errorCode)) {
//                // 记录解除告警
//                list.add(createRemoveWarnTable(AlarmCodeEnums.X006.errorCode));
//            }
//        }

        if (deviceStatus.isPumpHumidityAlarm()) {
            // 泵源温度告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 泵源温度告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.E014.errorCode));
        } else {
            // 解除泵源温度告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.E014.errorCode);
        }

        if (deviceStatus.isLaserCurrentAlarm()) {
            // 激光器电流告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 激光器电流告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H023.errorCode));
        } else {
            // 解除激光器电流告警（注：需确认对应的告警码常量）
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H023.errorCode);
        }

        if (deviceStatus.isRedLightCurrentAlarm()) {
            // 红光电流告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 红光电流告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H024.errorCode));
        } else {
            // 解除红光电流告警（注：需确认对应的告警码常量）
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H024.errorCode);
        }

        if (deviceStatus.isPumpVoltageAlarm()) {
            // 泵源电压告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 泵源电压告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H025.errorCode));
        } else {
            // 解除泵源电压告警（注：需确认对应的告警码常量）
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H025.errorCode);
        }

        // ====================激光器告警状态段2=====================
        if (deviceStatus.isDriver1CommunicationAlarm()) {
            // 激光器驱动1通信告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 激光器驱动1通信告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H026.errorCode));
        } else {
            // 解除激光器驱动1通信告警（注：需确认对应的告警码常量）
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H026.errorCode);
        }

        if (deviceStatus.isDriver2CommunicationAlarm()) {
            // 激光器驱动2通信告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 激光器驱动2通信告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H026.errorCode));
        } else {
            // 解除激光器驱动2通信告警（注：需确认对应的告警码常量）
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H026.errorCode);
        }

        if (deviceStatus.isDriver3CommunicationAlarm()) {
            // 激光器驱动3通信告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 激光器驱动3通信告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H026.errorCode));
        } else {
            // 解除激光器驱动3通信告警（注：需确认对应的告警码常量）
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H026.errorCode);
        }

        if (deviceStatus.isDriver4CommunicationAlarm()) {
            // 激光器驱动4通信告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 激光器驱动4通信告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H026.errorCode));
        } else {
            // 解除激光器驱动4通信告警（注：需确认对应的告警码常量）
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H026.errorCode);
        }

        if (deviceStatus.isAdFeedbackCommunicationAlarm()) {
            // AD反馈通讯告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: AD反馈通讯告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H027.errorCode));
        } else {
            // 解除AD反馈通讯告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H027.errorCode);
        }

        if (deviceStatus.isPumpModuleOverTemperatureAlarm() || deviceStatus.isPumpBoardTemperatureAlarm()) {
            // 泵模块超温告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 泵模块超温告警");
            list.add(createSeriousWarnTable(AlarmCodeEnums.E006.errorCode));
        } else {
            // 解除泵模块超温告警（注：需确认对应的告警码常量）
//            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.E006.errorCode);
            if (WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.E006.errorCode)) {
                // 记录解除告警
                list.add(createRemoveWarnTable(AlarmCodeEnums.X006.errorCode));
            }
        }

        if (deviceStatus.isDriverModuleOverTemperatureAlarm()) {
            // 驱动模块超温告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 驱动模块超温告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.E015.errorCode));
        } else {
            // 解除驱动模块超温告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.E015.errorCode);
        }

        if (deviceStatus.isWaterTemperatureOverLimitAlarm()) {
            // 水温超限告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 水温超限告警");
            list.add(createSeriousWarnTable(AlarmCodeEnums.E008.errorCode));
        } else {
            // 解除水温超限告警
            if (WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.E008.errorCode)) {
                list.add(createRemoveWarnTable(AlarmCodeEnums.X008.errorCode));
            }
        }

        if (deviceStatus.isFiberTemperatureOverLimitAlarm()) {
            // 光纤温度超上限告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 光纤温度超上限告警");
            list.add(createSeriousWarnTable(AlarmCodeEnums.E009.errorCode));
        } else {
            // 解除光纤温度超上限告警
            if (WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.E009.errorCode)) {
                list.add(createRemoveWarnTable(AlarmCodeEnums.X009.errorCode));
            }
        }

        if (deviceStatus.isLaserReflectionEnergyOverLimitAlarm()) {
            // 激光反射能量超上限告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 激光反射能量超上限告警");
            list.add(createSeriousWarnTable(AlarmCodeEnums.E010.errorCode));
        } else {
            // 解除激光反射能量超上限告警
            if (WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.E010.errorCode)) {
                list.add(createRemoveWarnTable(AlarmCodeEnums.X010.errorCode));
            }
        }

        if (deviceStatus.isLaserOutputEnergyUnderLimitAlarm()) {
            // 激光输出能量超下限告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 激光输出能量超下限告警");
            list.add(createSeriousWarnTable(AlarmCodeEnums.E011.errorCode));
        } else {
            // 解除激光输出能量超下限告警
            if (WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.E011.errorCode)) {
                list.add(createRemoveWarnTable(AlarmCodeEnums.X011.errorCode));
            }
        }

        if (deviceStatus.isDiodeShortCircuitAlarm()) {
            // 二极管短路故障告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 二极管短路故障告警");
            list.add(createSeriousWarnTable(AlarmCodeEnums.E012.errorCode));
        } else {
            // 解除二极管短路故障告警
            if (WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.E012.errorCode)) {
                list.add(createRemoveWarnTable(AlarmCodeEnums.X012.errorCode));
            }
        }

        if (deviceStatus.isFiberDisconnectedAlarm()) {
            // 光纤断开告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 光纤断开告警");
            list.add(createSeriousWarnTable(AlarmCodeEnums.E013.errorCode));
        } else {
            // 解除光纤断开告警
            if (WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.E013.errorCode)) {
                list.add(createRemoveWarnTable(AlarmCodeEnums.X013.errorCode));
            }
        }

        if (deviceStatus.isInternalHumidityOverLimitAlarm()) {
            // 内部湿度超上限告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 内部湿度超上限告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.E016.errorCode));
        } else {
            // 解除内部湿度超上限告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.E016.errorCode);
        }

        if (deviceStatus.isColdWaterInterlockAlarm()) {
            // 冷水互锁告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 冷水互锁告警");
            list.add(createSeriousWarnTable(AlarmCodeEnums.H028.errorCode));
        } else {
            // 解除冷水互锁告警（注：需确认对应的告警码常量）
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H028.errorCode);
        }

        if (deviceStatus.isLaserEmergencyStopAlarm()) {
            // 激光器急停告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 激光器急停告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H029.errorCode));
        } else {
            // 解除激光器急停告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H029.errorCode);
        }
        // =============================激光器告警状态段3=======================
        if (deviceStatus.isPositioningLightFaultAlarm()) {
            // 定位光故障告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 定位光故障告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H030.errorCode));
        } else {
            // 解除定位光故障告警（注：需确认对应的告警码常量）
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H030.errorCode);
        }

        if (deviceStatus.isNarrowPulseProtectionAlarm()) {
            // 窄脉冲保护告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 窄脉冲保护告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H031.errorCode));
        } else {
            // 解除窄脉冲保护告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H031.errorCode);
        }
        if (deviceStatus.isLaserDriveBoardOvervoltage()) {
            // 驱动板过压
            if (debugLog) Log.d(TAG, "convertToWarnTables: 驱动板过压");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H032.errorCode));
        } else {
            // 解除驱动板过压
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H032.errorCode);
        }
        if (deviceStatus.isLaserEnvironmentalTemperatureAlarm()) {
            // 环境温度告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 环境温度告警");
            list.add(createIgnoreWarnTable(AlarmCodeEnums.H033.errorCode));
        } else {
            // 解除环境温度告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.H033.errorCode);
        }

        // ===========================送丝机告警状态段1=========================
        if (deviceStatus.isWireFeederCommunicationAlarm()) {
            // 送丝机通信告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 送丝机通信告警");
            list.add(createWaitConfirmWarnTable(AlarmCodeEnums.W001.errorCode));
        } else {
            // 解除送丝机通信告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.W001.errorCode);
        }

        if (deviceStatus.isWireFeederCurrentAlarm()) {
            // 送丝机电流告警
            if (debugLog) Log.d(TAG, "convertToWarnTables: 送丝机电流告警");
            list.add(createWaitConfirmWarnTable(AlarmCodeEnums.W002.errorCode));
        } else {
            // 解除送丝机电流告警
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.W002.errorCode);
        }
        // ===========================控制卡告警状态段1 (A001)=========================
        appendShieldingGasAlarmWarnTable(list, deviceStatus);
        // C002 (camera ping) is non-Modbus — see {@link com.lasercyber.lws.ui.common.handler.CameraCommunicationWarnAlarm}.
        return list;
    }

    /**
     * C001: device-status or device-data poll health fault (mode from {@code control_card_comm_alarm_mode}).
     */
    public static void appendControllerTabletCommWarnTable(List<WarnTable> list, DeviceStatus deviceStatus) {
        DeviceData deviceData = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_DATA_KEY);
        if (isControllerTabletCommTruncated(deviceStatus, deviceData)) {
            if (debugLog) {
                Log.d(TAG, "convertToWarnTables: 主控板与平板通讯故障");
            }
            list.add(createSeriousWarnTable(AlarmCodeEnums.C001.errorCode));
        } else {
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.C001.errorCode);
        }
    }

    static boolean isControllerTabletCommTruncated(DeviceStatus deviceStatus, DeviceData deviceData) {
        return (deviceStatus != null && deviceStatus.isModbusStatusReadTruncated())
                || (deviceData != null && deviceData.isModbusDataReadTruncated());
    }

    /**
     * A001: control-card gas path alarms (seg1 bits 0–3); code unchanged, message varies by bit.
     */
    public static void appendShieldingGasAlarmWarnTable(List<WarnTable> list, DeviceStatus deviceStatus) {
        if (ShieldingGasAlarmMessageUtil.hasActiveAlarm(deviceStatus)) {
            if (debugLog) {
                Log.d(TAG, "convertToWarnTables: " + ShieldingGasAlarmMessageUtil.buildLogMessage(Utils.getApp(), deviceStatus));
            }
            WarnTable warnTable = createWaitConfirmWarnTable(AlarmCodeEnums.A001.errorCode);
            warnTable.setContent(ShieldingGasAlarmMessageUtil.buildWarnLogContent(Utils.getApp(), deviceStatus));
            list.add(warnTable);
        } else {
            WarnLogEpisodeTracker.notifyFaultCleared(AlarmCodeEnums.A001.errorCode);
        }
    }

    /**
     * Popup for A001 with cause-specific title and troubleshooting text.
     */
    public static WarnDialogVo convertShieldingGasAlarmDialogVo(DeviceStatus deviceStatus, boolean isActiveDetection) {
        if (ShieldingGasAlarmMessageUtil.hasActiveAlarm(deviceStatus)) {
            if (debugLog) {
                Log.d(TAG, "convertToWarnDialogVo: " + ShieldingGasAlarmMessageUtil.buildLogMessage(Utils.getApp(), deviceStatus));
            }
            Context app = Utils.getApp();
            var alarmHit = createAlarmHit(
                    AlarmCodeEnums.A001.errorCode,
                    ShieldingGasAlarmMessageUtil.buildDialogTitle(app),
                    ShieldingGasAlarmMessageUtil.buildDialogContent(app, deviceStatus),
                    !isActiveDetection);
            if (alarmHit != null) {
                return alarmHit;
            }
        } else if (!isActiveDetection) {
            closeWarn(AlarmCodeEnums.A001.errorCode);
        }
        return null;
    }

    /** Builds a warn_table row only; no popup or persistence side effects. */
    public static WarnTable createWarnTable(String warnCode, Integer warnLevel) {
        WarnTable warnTable = new WarnTable();
        warnTable.setCode(warnCode);
        Date date = new Date();
        warnTable.setYmdDate(DateUtil.format(date, "yyyy-MM-dd"));
        warnTable.setHmDate(DateUtil.format(date, "HH:mm:ss"));
        warnTable.setTime(date.getTime());
        warnTable.setNewTime(date.getTime());
        warnTable.setLevel(warnLevel);
        return warnTable;
    }

    /**
     * 创建严重的告警
     *
     * @param warnCode
     * @return
     */
    public static WarnTable createSeriousWarnTable(String warnCode) {
        return createWarnTable(warnCode, WarnLevelConstant.SERIOUS);
    }
    /**
     * 创建等待确认的告警
     *
     * @param warnCode
     * @return
     */
    public static WarnTable createWaitConfirmWarnTable(String warnCode) {
        return createWarnTable(warnCode, WarnLevelConstant.WAIT_CONFIRM);
    }
    /**
     * 创建忽略的告警
     *
     * @param warnCode
     * @return
     */
    public static WarnTable createIgnoreWarnTable(String warnCode) {
        return createWarnTable(warnCode, WarnLevelConstant.IGNORE);
    }
    /**
     * 解除告警
     *
     * @param removeWarnCode
     * @return
     */
    public static WarnTable createRemoveWarnTable(String removeWarnCode) {
        return createWarnTable(removeWarnCode, WarnLevelConstant.REMOVE);
    }

    /**
     * 转化告警弹窗
     *
     * @param deviceStatus
     * @param isActiveDetection 是否主动检测
     *                          true:主动检测，由界面操作发起
     *                          false:被动检测，由后台线程检测
     * @return
     */
    public static WarnDialogVo convertToWarnDialogVo(DeviceStatus deviceStatus, boolean isActiveDetection) {
        DeviceData deviceData = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_DATA_KEY);
        WarnDialogVo pendingDialog = null;
        if (isControllerTabletCommTruncated(deviceStatus, deviceData)) {
            var seriousHit = createSeriousHit(AlarmCodeEnums.C001.errorCode,
                    Utils.getApp().getString(AlarmCodeEnums.C001.titleId),
                    Utils.getApp().getString(AlarmCodeEnums.C001.contentId),
                    !isActiveDetection);
            pendingDialog = mergeFirstWarnDialog(pendingDialog, seriousHit);
        } else if (!isActiveDetection) {
            closeWarn(AlarmCodeEnums.C001.errorCode);
        }
        // ===================枪头告警状态 gunAlarmSeg1=====================
        if (deviceStatus.isGunCommunicationAlarm()) {
            // 枪头通信告警
            var seriousHit = createSeriousHit(AlarmCodeEnums.H001.errorCode,
                    Utils.getApp().getString(AlarmCodeEnums.H001.titleId),
                    Utils.getApp().getString(AlarmCodeEnums.H001.contentId),
                    !isActiveDetection);
            pendingDialog = mergeFirstWarnDialog(pendingDialog, seriousHit);
        } else if (!isActiveDetection) {
            closeWarn(AlarmCodeEnums.H001.errorCode);
        }
        // =======================枪头告警状态段3=================================
        // 保持原注释状态，仅补全注释内的else逻辑
//        if (deviceStatus.isSensorChannelDiffAlarm()) {
//            // 传感器通道差
//            return createHitNoCharts("","");
//        } else  if (!isActiveDetection){
//            // 解除传感器通道差告警
//            closeWarn(AlarmCodeConstants.ALARM_H002);
//        }
//        if (deviceStatus.isStaticCurrentAbnormalAlarm()) {
//            // 静态电流异常
//            return createHitNoCharts("","");
//        } else  if (!isActiveDetection){
//            // 解除静态电流异常告警
//            closeWarn(AlarmCodeConstants.ALARM_H003);
//        }
//        if (deviceStatus.isMotorWireOpenAlarm()) {
//            // 电机连接线开路告警
//            return createHitNoCharts("","");
//        } else  if (!isActiveDetection){
//            // 解除电机连接线开路告警
//            closeWarn(AlarmCodeConstants.ALARM_H004);
//        }
//        if (deviceStatus.isSensorAbnormalAlarm()) {
//            // 传感器异常告警
//            return createHitNoCharts("","");
//        } else  if (!isActiveDetection){
//            // 解除传感器异常告警
//            closeWarn(AlarmCodeConstants.ALARM_H005);
//        }
//        if (deviceStatus.isFlashErrorAlarm()) {
//            // FLASH出错告警
//            return createHitNoCharts("","");
//        } else  if (!isActiveDetection){
//            // 解除FLASH出错告警
//            closeWarn(AlarmCodeConstants.ALARM_H006);
//        }
//        if (deviceStatus.isFlashUnencryptedAlarm()) {
//            // FLASH未加密告警
//            return createHitNoCharts("","");
//        } else  if (!isActiveDetection){
//            // 解除FLASH未加密告警
//            closeWarn(AlarmCodeConstants.ALARM_H007);
//        }
        // =====================枪头告警状态段2============================
        if (deviceStatus.isGunMotorOverTemperatureAlarm()) {
            // 枪头电机过温告警
            var seriousHit = createSeriousHit(AlarmCodeEnums.H008.errorCode,
                    Utils.getApp().getString(AlarmCodeEnums.H008.titleId),
                    Utils.getApp().getString(AlarmCodeEnums.H008.contentId),
                    !isActiveDetection);
            pendingDialog = mergeFirstWarnDialog(pendingDialog, seriousHit);
        } else if (!isActiveDetection) {
            // 解除枪头电机过温告警
            closeWarn(AlarmCodeEnums.H008.errorCode);
        }

        if (deviceStatus.isDriverTemperatureAlarm()) {
            // 驱动温度告警
            var seriousHit = createSeriousHit(AlarmCodeEnums.H009.errorCode,
                    Utils.getApp().getString(AlarmCodeEnums.H009.titleId),
                    Utils.getApp().getString(AlarmCodeEnums.H009.contentId),
                    !isActiveDetection);
            pendingDialog = mergeFirstWarnDialog(pendingDialog, seriousHit);
        } else if (!isActiveDetection) {
            // 解除驱动温度告警
            closeWarn(AlarmCodeEnums.H009.errorCode);
        }

        if (deviceStatus.isProtectionBoardTemperatureAlarm()) {
            // 保护镜温度告警
            var seriousHit = createSeriousHit(AlarmCodeEnums.H010.errorCode,
                    Utils.getApp().getString(AlarmCodeEnums.H010.titleId),
                    Utils.getApp().getString(AlarmCodeEnums.H010.contentId),
                    !isActiveDetection);
            pendingDialog = mergeFirstWarnDialog(pendingDialog, seriousHit);
        } else if (!isActiveDetection) {
            // 解除保护镜温度告警
            closeWarn(AlarmCodeEnums.H010.errorCode);
        }

        if (deviceStatus.isStraightTrackTemperatureAlarm()) {
            // 聚焦镜温度报警
            var seriousHit = createSeriousHit(AlarmCodeEnums.H011.errorCode,
                    Utils.getApp().getString(AlarmCodeEnums.H011.titleId),
                    Utils.getApp().getString(AlarmCodeEnums.H011.contentId),
                    !isActiveDetection);
            pendingDialog = mergeFirstWarnDialog(pendingDialog, seriousHit);
        } else if (!isActiveDetection) {
            // 解除聚焦镜温度报警
            closeWarn(AlarmCodeEnums.H011.errorCode);
        }

        if (deviceStatus.is24VUnderVoltageAlarm()) {
            // 24V欠压告警
            var seriousHit = createSeriousHit(AlarmCodeEnums.H012.errorCode,
                    Utils.getApp().getString(AlarmCodeEnums.H012.titleId),
                    Utils.getApp().getString(AlarmCodeEnums.H012.contentId),
                    !isActiveDetection);
            pendingDialog = mergeFirstWarnDialog(pendingDialog, seriousHit);
        } else if (!isActiveDetection) {
            // 解除24V欠压告警
            closeWarn(AlarmCodeEnums.H012.errorCode);
        }

        if (deviceStatus.isDriverOverCurrentAlarm()) {
            // 电机过流告警
            var seriousHit = createSeriousHit(AlarmCodeEnums.H013.errorCode,
                    Utils.getApp().getString(AlarmCodeEnums.H013.titleId),
                    Utils.getApp().getString(AlarmCodeEnums.H013.contentId),
                    !isActiveDetection);
            pendingDialog = mergeFirstWarnDialog(pendingDialog, seriousHit);
        } else if (!isActiveDetection) {
            // 解除电机过流告警
            closeWarn(AlarmCodeEnums.H013.errorCode);
        }

        if (deviceStatus.isMotorTrackAbnormalAlarm()) {
            // 电机轨迹异常告警
            var seriousHit = createSeriousHit(AlarmCodeEnums.H014.errorCode,
                    Utils.getApp().getString(AlarmCodeEnums.H014.titleId),
                    Utils.getApp().getString(AlarmCodeEnums.H014.contentId),
                    !isActiveDetection);
            pendingDialog = mergeFirstWarnDialog(pendingDialog, seriousHit);
        } else if (!isActiveDetection) {
            // 解除电机轨迹异常告警
            closeWarn(AlarmCodeEnums.H014.errorCode);
        }

        if (deviceStatus.isMotorStallAlarm()) {
            // 电机堵转告警
            var seriousHit = createSeriousHit(AlarmCodeEnums.H015.errorCode,
                    Utils.getApp().getString(AlarmCodeEnums.H015.titleId),
                    Utils.getApp().getString(AlarmCodeEnums.H015.contentId),
                    !isActiveDetection);
            pendingDialog = mergeFirstWarnDialog(pendingDialog, seriousHit);
        } else if (!isActiveDetection) {
            // 解除电机堵转告警
            closeWarn(AlarmCodeEnums.H015.errorCode);
        }
        // =======================枪头告警状态段4====================
//        if (deviceStatus.isMmiOscillatorAbnormalAlarm()) {
//            // MMI振荡器异常告警
//            return createHitNoCharts("","");
//        } else  if (!isActiveDetection){
//            // 解除MMI振荡器异常告警
//            closeWarn(AlarmCodeConstants.ALARM_H016);
//        }
//        if (deviceStatus.isHardwareBusErrorAlarm()) {
//            // 硬件总线错误告警
//            return createHitNoCharts("","");
//        } else  if (!isActiveDetection){
//            // 解除硬件总线错误告警
//            closeWarn(AlarmCodeConstants.ALARM_H017);
//        }
//        if (deviceStatus.isMemoryManagementAbnormalAlarm()) {
//            // 内存管理异常告警
//            return createHitNoCharts("","");
//        } else  if (!isActiveDetection){
//            // 解除内存管理异常告警
//            closeWarn(AlarmCodeConstants.ALARM_H018);
//        }
//        if (deviceStatus.isMemoryAccessErrorAlarm()) {
//            // 内存访问错误告警
//            return createHitNoCharts("","");
//        } else  if (!isActiveDetection){
//            // 解除内存访问错误告警
//            closeWarn(AlarmCodeConstants.ALARM_H019);
//        }
//        if (deviceStatus.isIllegalInstructionAlarm()) {
//            // 非法指令告警
//            return createHitNoCharts("","");
//        } else  if (!isActiveDetection){
//            // 解除非法指令告警
//            closeWarn(AlarmCodeConstants.ALARM_H020);
//        }
//        if (deviceStatus.isWatchdogResetAlarm()) {
//            //  看门狗重启告警
//            return createHitNoCharts("","");
//        } else  if (!isActiveDetection){
//            // 解除看门狗重启告警
//            closeWarn(AlarmCodeConstants.ALARM_H021);
//        }
        // =====================激光器告警状态段1=====================
        if (deviceStatus.isLaserCommunicationAlarm()) {
            // 激光器通信告警
//            return createHitNoCharts("","");
            var seriousHit = createSeriousHit(AlarmCodeEnums.H022.errorCode,
                    Utils.getApp().getString(AlarmCodeEnums.H022.titleId),
                    Utils.getApp().getString(AlarmCodeEnums.H022.contentId),
                    !isActiveDetection);
            pendingDialog = mergeFirstWarnDialog(pendingDialog, seriousHit);
        } else if (!isActiveDetection) {
            // 解除激光器通信告警
//            closeWarn(AlarmCodeConstants.ALARM_X006);
            closeWarn(AlarmCodeEnums.H022.errorCode);
        }

        if (deviceStatus.isPumpBoardTemperatureAlarm()) {
            // 泵板温度告警
            WarnDialogVo seriousHit = createSeriousHit(AlarmCodeEnums.E006.errorCode,
                    Utils.getApp().getString(AlarmCodeEnums.E006.titleId),
                    Utils.getApp().getString(AlarmCodeEnums.E006.contentId),
                    !isActiveDetection);
            pendingDialog = mergeFirstWarnDialog(pendingDialog, seriousHit);
        } else if (!isActiveDetection) {
            // 解除泵板温度告警
            closeWarn(AlarmCodeEnums.E006.errorCode);
        }

        if (deviceStatus.isPumpHumidityAlarm()) {
            // 泵源温度告警
//            return createHitNoCharts("","");
        } else if (!isActiveDetection) {
            // 解除泵源温度告警
//            closeWarn(AlarmCodeConstants.ALARM_X006);
        }

        if (deviceStatus.isLaserCurrentAlarm()) {
            // 激光器电流告警
//            return createHitNoCharts("","");
        } else if (!isActiveDetection) {
            // 解除激光器电流告警（注：需确认对应的告警码常量）
//            closeWarn(/* 对应激光器电流告警的常量 */);
        }

        if (deviceStatus.isRedLightCurrentAlarm()) {
            // 红光电流告警
//            return createHitNoCharts("","");
        } else if (!isActiveDetection) {
            // 解除红光电流告警（注：需确认对应的告警码常量）
//            closeWarn(/* 对应红光电流告警的常量 */);
        }

        if (deviceStatus.isPumpVoltageAlarm()) {
            // 泵源电压告警
//            return createHitNoCharts("","");
        } else if (!isActiveDetection) {
            // 解除泵源电压告警（注：需确认对应的告警码常量）
//            closeWarn(/* 对应泵源电压告警的常量 */);
        }

        if (deviceStatus.isForwardLightPdVoltageAlarm()) {
            // 前光PD电压告警
//            return createHitNoCharts("","");
        } else if (!isActiveDetection) {
            // 解除前光PD电压告警（注：需确认对应的告警码常量）
//            closeWarn(/* 对应前光PD电压告警的常量 */);
        }

        if (deviceStatus.isInternalTemperatureWarning()) {
            // 内部温度告警
//            return createHitNoCharts("","");
        } else if (!isActiveDetection) {
            // 解除内部温度告警（注：需确认对应的告警码常量）
//            closeWarn(/* 对应内部温度告警的常量 */);
        }
        // ====================激光器告警状态段2=====================
        if (deviceStatus.isDriver1CommunicationAlarm()) {
            // 激光器驱动1通信告警
//            var seriousHit = createSeriousHit(AlarmCodeConstants.ALARM_H023,
//                    Utils.getApp().getString(R.string.laser_communication_anomaly_text),
//                    Utils.getApp().getString(R.string.contact_cyber_after_sales_team_text));
//            if (seriousHit != null) {
//                return seriousHit;
//            }
        } else if (!isActiveDetection) {
            // 解除激光器驱动1通信告警（注：需确认对应的告警码常量）
//            closeWarn(AlarmCodeConstants.ALARM_H023);
        }

        if (deviceStatus.isDriver2CommunicationAlarm()) {
            // 激光器驱动2通信告警
//            return createHitNoCharts("","");
        } else if (!isActiveDetection) {
            // 解除激光器驱动2通信告警（注：需确认对应的告警码常量）
//            closeWarn(/* 对应激光器驱动2通信告警的常量 */);
        }

        if (deviceStatus.isDriver3CommunicationAlarm()) {
            // 激光器驱动3通信告警
//            return createHitNoCharts("","");
        } else if (!isActiveDetection) {
            // 解除激光器驱动3通信告警（注：需确认对应的告警码常量）
//            closeWarn(/* 对应激光器驱动3通信告警的常量 */);
        }

        if (deviceStatus.isDriver4CommunicationAlarm()) {
            // 激光器驱动4通信告警
//            return createHitNoCharts("","");
        } else if (!isActiveDetection) {
            // 解除激光器驱动4通信告警（注：需确认对应的告警码常量）
//            closeWarn(/* 对应激光器驱动4通信告警的常量 */);
        }

        if (deviceStatus.isAdFeedbackCommunicationAlarm()) {
            // AD反馈通讯告警
//            return createHitNoCharts("","");
        } else if (!isActiveDetection) {
            // 解除AD反馈通讯告警
//            closeWarn(AlarmCodeConstants.ALARM_E005);
        }

        if (deviceStatus.isPumpModuleOverTemperatureAlarm()) {
            // 泵模块超温告警
//            return createHitNoCharts("","");
        } else if (!isActiveDetection) {
            // 解除泵模块超温告警（注：需确认对应的告警码常量）
//            closeWarn(/* 对应泵模块超温告警的常量 */);
        }

        if (deviceStatus.isDriverModuleOverTemperatureAlarm()) {
            // 驱动模块超温告警
//            return createHitNoCharts("","");
        } else if (!isActiveDetection) {
            // 解除驱动模块超温告警
//            closeWarn(AlarmCodeConstants.ALARM_E007);
        }

        if (deviceStatus.isWaterTemperatureOverLimitAlarm()) {
            // 水温超限告警
            var seriousHit = createSeriousHit(AlarmCodeEnums.E008.errorCode,
                    Utils.getApp().getString(AlarmCodeEnums.E008.titleId),
                    Utils.getApp().getString(AlarmCodeEnums.E008.contentId),
                    !isActiveDetection);
            pendingDialog = mergeFirstWarnDialog(pendingDialog, seriousHit);
        } else if (!isActiveDetection) {
            // 解除水温超限告警
            closeWarn(AlarmCodeEnums.E008.errorCode);
        }

        if (deviceStatus.isFiberTemperatureOverLimitAlarm()) {
            // 光纤温度超上限告警
            var seriousHit = createSeriousHit(AlarmCodeEnums.E009.errorCode,
                    Utils.getApp().getString(AlarmCodeEnums.E009.titleId),
                    Utils.getApp().getString(AlarmCodeEnums.E009.contentId),
                    !isActiveDetection);
            pendingDialog = mergeFirstWarnDialog(pendingDialog, seriousHit);
        } else if (!isActiveDetection) {
            // 解除光纤温度超上限告警
            closeWarn(AlarmCodeEnums.E009.errorCode);
        }

        if (deviceStatus.isLaserReflectionEnergyOverLimitAlarm()) {
            // 激光反射能量超上限告警
            var seriousHit = createSeriousHit(AlarmCodeEnums.E010.errorCode,
                    Utils.getApp().getString(AlarmCodeEnums.E010.titleId),
                    Utils.getApp().getString(AlarmCodeEnums.E010.contentId),
                    !isActiveDetection);
            pendingDialog = mergeFirstWarnDialog(pendingDialog, seriousHit);
        } else {
            // 解除激光反射能量超上限告警（注：需确认对应的告警码常量）
            closeWarn(AlarmCodeEnums.E010.errorCode);
        }

        if (deviceStatus.isLaserOutputEnergyUnderLimitAlarm()) {
            // 激光输出能量超下限告警
            var seriousHit = createSeriousHit(AlarmCodeEnums.E011.errorCode,
                    Utils.getApp().getString(AlarmCodeEnums.E011.titleId),
                    Utils.getApp().getString(AlarmCodeEnums.E011.contentId),
                    !isActiveDetection);
            pendingDialog = mergeFirstWarnDialog(pendingDialog, seriousHit);
        } else if (!isActiveDetection) {
            // 解除激光输出能量超下限告警
            closeWarn(AlarmCodeEnums.E011.errorCode);
        }

        if (deviceStatus.isDiodeShortCircuitAlarm()) {
            // 二极管短路故障告警
            var seriousHit = createSeriousHit(AlarmCodeEnums.E012.errorCode,
                    Utils.getApp().getString(AlarmCodeEnums.E012.titleId),
                    Utils.getApp().getString(AlarmCodeEnums.E012.contentId),
                    !isActiveDetection);
            pendingDialog = mergeFirstWarnDialog(pendingDialog, seriousHit);
        } else if (!isActiveDetection) {
            // 解除二极管短路故障告警
            closeWarn(AlarmCodeEnums.E012.errorCode);
        }

        if (deviceStatus.isFiberDisconnectedAlarm()) {
            // 光纤断开告警
            var seriousHit = createSeriousHit(AlarmCodeEnums.E013.errorCode,
                    Utils.getApp().getString(AlarmCodeEnums.E013.titleId),
                    Utils.getApp().getString(AlarmCodeEnums.E013.contentId),
                    !isActiveDetection);
            pendingDialog = mergeFirstWarnDialog(pendingDialog, seriousHit);
        } else if (!isActiveDetection) {
            // 解除光纤断开告警
            closeWarn(AlarmCodeEnums.E013.errorCode);
        }

        if (deviceStatus.isInternalHumidityOverLimitAlarm()) {
            // 内部湿度超上限告警
//            return createHitNoCharts("","");
        } else if (!isActiveDetection) {
            // 解除内部湿度超上限告警
//            closeWarn(AlarmCodeConstants.ALARM_E013);
        }

        if (deviceStatus.isColdWaterInterlockAlarm()) {
            // 冷水互锁告警
//            return createHitNoCharts("","");
        } else if (!isActiveDetection) {
            // 解除冷水互锁告警（注：需确认对应的告警码常量）
//            closeWarn(/* 对应冷水互锁告警的常量 */);
        }

        if (deviceStatus.isLaserEmergencyStopAlarm()) {
            // 激光器急停告警
//            return createHitNoCharts("","");
        } else if (!isActiveDetection) {
            // 解除激光器急停告警
//            closeWarn(AlarmCodeConstants.ALARM_E014);
        }
        // =============================激光器告警状态段3=======================
        if (deviceStatus.isPositioningLightFaultAlarm()) {
            // 定位光故障告警
//            return createHitNoCharts("","");
        } else if (!isActiveDetection) {
            // 解除定位光故障告警（注：需确认对应的告警码常量）
//            closeWarn(/* 对应定位光故障告警的常量 */);
        }

        if (deviceStatus.isNarrowPulseProtectionAlarm()) {
            // 窄脉冲保护告警
//            return createHitNoCharts("","");
        } else if (!isActiveDetection) {
            // 解除窄脉冲保护告警
//            closeWarn(AlarmCodeConstants.ALARM_E015);
        }
        if (deviceStatus.isLaserDriveBoardOvervoltage()) {
            // 驱动板过压
//            return createHitNoCharts("","");
        } else if (!isActiveDetection) {
            // 解除驱动板过压
//            closeWarn(AlarmCodeConstants.ALARM_E015);
        }
        if (deviceStatus.isLaserEnvironmentalTemperatureAlarm()) {
            // 环境温度告警
//            return createHitNoCharts("","");
        } else if (!isActiveDetection) {
            // 解除环境温度告警
//            closeWarn(AlarmCodeConstants.ALARM_E015);
        }
        // ===========================送丝机告警状态段1=========================
        if (!isActiveDetection) {
            if (deviceStatus.isWireFeederCommunicationAlarm()) {
                // 送丝机通信告警
                var alarmHit = createAlarmHit(AlarmCodeEnums.W001.errorCode,
                        Utils.getApp().getString(AlarmCodeEnums.W001.titleId),
                        Utils.getApp().getString(AlarmCodeEnums.W001.contentId),
                        true);
                pendingDialog = mergeFirstWarnDialog(pendingDialog, alarmHit);
            } else {
                // 解除送丝机通信告警
                closeWarn(AlarmCodeEnums.W001.errorCode);
            }

            if (deviceStatus.isWireFeederCurrentAlarm()) {
                // 送丝机电流告警
                var alarmHit = createAlarmHit(AlarmCodeEnums.W002.errorCode,
                        Utils.getApp().getString(AlarmCodeEnums.W002.titleId),
                        Utils.getApp().getString(AlarmCodeEnums.W002.contentId),
                        true);
                pendingDialog = mergeFirstWarnDialog(pendingDialog, alarmHit);
            } else {
                // 解除送丝机电流告警
                closeWarn(AlarmCodeEnums.W002.errorCode);
            }
        }
        // W001/W002 laser-enable blocking is handled by LaserEnableAlarmGuard (supports dangerous-operations bypass).
        // ===========================控制卡告警状态段1 (A001)=========================
        if (!isActiveDetection) {
            WarnDialogVo shieldingGasHit = convertShieldingGasAlarmDialogVo(deviceStatus, false);
            pendingDialog = mergeFirstWarnDialog(pendingDialog, shieldingGasHit);
        }
        // A001 laser-enable blocking is handled by LaserEnableAlarmGuard (supports dangerous-operations bypass).
        // C002 is non-Modbus — {@link com.lasercyber.lws.ui.common.handler.CameraCommunicationWarnAlarm}.
        return pendingDialog;
    }

    @Nullable
    private static WarnDialogVo mergeFirstWarnDialog(@Nullable WarnDialogVo current, @Nullable WarnDialogVo candidate) {
        return current != null ? current : candidate;
    }

    /**
     * 关闭告警
     *
     * @param warnCode
     */
    public static void closeWarn(String warnCode) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            MAIN_HANDLER.post(() -> WarnEpisodeController.tryClose(
                    warnCode, WarnEpisodeController.CloseReason.FAULT_RECOVERED));
            return;
        }
        WarnEpisodeController.tryClose(warnCode, WarnEpisodeController.CloseReason.FAULT_RECOVERED);
    }

    /**
     * 创建不需要图表的提示
     *
     * @param title
     * @param content
     * @param type
     * @return
     */
    public static WarnDialogVo createNoCharts(String title, String content, int type, String errorCode) {
        WarnDialogVo vo = new WarnDialogVo();
        vo.setType(type); // 0 = 告警 不可关闭。 1= 提示，可关闭，同时关闭激光枪的出光、出气 \ 退进丝等
        vo.setTitle(title);
        vo.setContent(content);
        vo.setIsShowProgress(false); //[true]出现图表，如果不是图表告警则无需出现 出入[false]，否则要出现。
        vo.setErrorCode(errorCode);
        return vo;
    }

    /**
     * Builds a warn dialog with severity from {@link WarnDialogSeverity} (dangerous-operations bypass toggles).
     */
    @Nullable
    public static WarnDialogVo createAlarmHit(
            String warnCode, String title, String content, boolean needCheck) {
        if (needCheck && !WarnEpisodeController.prepareModbusPassiveDialog(warnCode)) {
            return null;
        }
        int type = WarnDialogSeverity.dialogTypeForCode(warnCode, Utils.getApp());
        return createNoCharts(title, content, type, warnCode);
    }

    /**
     * 创建严重的提示
     */
    public static WarnDialogVo createSeriousHit(String warnCode, String title, String content, boolean needCheck) {
        if (needCheck && !WarnEpisodeController.prepareModbusPassiveDialog(warnCode)) {
            return null;
        }
        return createNoCharts(title, content, WarnUtil.WARN_TYPE, warnCode);
    }

    /**
     * 创建普通的提示
     */
    public static WarnDialogVo createNormalHit(String warnCode, String title, String content, boolean needCheck) {
        if (needCheck && !WarnEpisodeController.prepareModbusPassiveDialog(warnCode)) {
            return null;
        }
        return createNoCharts(title, content, WarnUtil.INFO_TYPE, warnCode);
    }
}
