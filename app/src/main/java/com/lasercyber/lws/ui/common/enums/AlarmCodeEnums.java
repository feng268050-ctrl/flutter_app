package com.lasercyber.lws.ui.common.enums;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.constant.AlarmCodeConstants;

import lombok.AllArgsConstructor;

/**
 * 告警错误码枚举
 */
@AllArgsConstructor
public enum AlarmCodeEnums {
    // 保护气告警
    A001(AlarmCodeConstants.ALARM_A001,
            R.string.shielding_gas_alarm_title,
            R.string.shielding_gas_alarm_content),

    // 泵浦模块超温
    E006(AlarmCodeConstants.ALARM_E006,
            R.string.pump_module_overtemperature_alarm_title,
            R.string.pump_module_overtemperature_alarm_content),
    // 水温超限
    E008(AlarmCodeConstants.ALARM_E008,
            R.string.water_temperature_upper_limit_alarm_title,
            R.string.water_temperature_upper_limit_alarm_content),
    // 光纤温度超上限
    E009(AlarmCodeConstants.ALARM_E009,
            R.string.fiber_temperature_upper_limit_alarm_title,
            R.string.water_temperature_upper_limit_alarm_content),
    // 激光反射能量超上限
    E010(AlarmCodeConstants.ALARM_E010,
            R.string.laser_reflected_energy_upper_limit_cleared_title,
            R.string.contact_cyber_after_sales_team_text),
    // 激光输出能量超下限
    E011(AlarmCodeConstants.ALARM_E011,
            R.string.laser_output_energy_lower_limit_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 二极体短路故障
    E012(AlarmCodeConstants.ALARM_E012,
            R.string.fiber_disconnection_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 光纤断开
    E013(AlarmCodeConstants.ALARM_E013,
            R.string.diode_short_circuit_error_cleared_title,
            R.string.contact_cyber_after_sales_team_text),
    // 泵源温度告警
    E014(AlarmCodeConstants.ALARM_E014,
            R.string.pump_source_temperature_alarm_title,
            R.string.contact_cyber_after_sales_team_text),

    // 驱动模块超温告警
    E015(AlarmCodeConstants.ALARM_E015,
            R.string.driver_module_overtemperature_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 内部湿度超上限告警
    E016(AlarmCodeConstants.ALARM_E016,
            R.string.internal_humidity_exceeds_the_upper_limit_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 枪头通信告警
    H001(AlarmCodeConstants.ALARM_H001,
            R.string.gun_head_communication_alarm_title,
            R.string.gun_head_communication_alarm_content),
    // 传感器通道差
    H002(AlarmCodeConstants.ALARM_H002,
            R.string.sensor_channel_deviation_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 静态电流异常
    H003(AlarmCodeConstants.ALARM_H003,
            R.string.quiescent_current_abnormal_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 电机连接线开路告警
    H004(AlarmCodeConstants.ALARM_H004,
            R.string.motor_cable_open_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 传感器异常告警
    H005(AlarmCodeConstants.ALARM_H005,
            R.string.sensor_abnormal_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // FLASH出错告警
    H006(AlarmCodeConstants.ALARM_H006,
            R.string.flash_error_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // FLASH未加密告警
    H007(AlarmCodeConstants.ALARM_H007,
            R.string.flash_unencrypted_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 枪头电机过温告警
    H008(AlarmCodeConstants.ALARM_H008,
            R.string.gun_head_motor_overtemperature_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 驱动温度告警
    H009(AlarmCodeConstants.ALARM_H009,
            R.string.drive_overtemperature_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 保护镜温度告警
    H010(AlarmCodeConstants.ALARM_H010,
            R.string.protective_lens_overtemperature_alarm_title,
            R.string.protective_lens_overtemperature_alarm_content),
    // 聚焦镜温度告警
    H011(AlarmCodeConstants.ALARM_H011,
            R.string.collimating_lens_overtemperature_alarm_title,
            R.string.straight_track_temperature_alarm_content),
    // 24V欠压告警
    H012(AlarmCodeConstants.ALARM_H012,
            R.string.undervoltage_24v_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 电机过流告警
    H013(AlarmCodeConstants.ALARM_H013,
            R.string.galvanometer_motor_overcurrent_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 电机轨迹异常告警
    H014(AlarmCodeConstants.ALARM_H014,
            R.string.galvanometer_motor_trajectory_error_title,
            R.string.contact_cyber_after_sales_team_text),
    // 电机堵转告警
    H015(AlarmCodeConstants.ALARM_H015,
            R.string.galvanometer_motor_stall_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // MMI振荡器异常告警
    H016(AlarmCodeConstants.ALARM_H016,
            R.string.mmi_oscillator_malfunction_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 硬件总线错误告警
    H017(AlarmCodeConstants.ALARM_H017,
            R.string.hardware_bus_error_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 内存管理异常告警
    H018(AlarmCodeConstants.ALARM_H018,
            R.string.memory_management_error_title,
            R.string.contact_cyber_after_sales_team_text),
    // 内存访问错误告警
    H019(AlarmCodeConstants.ALARM_H019,
            R.string.memory_access_error_title,
            R.string.contact_cyber_after_sales_team_text),
    // 非法指令告警
    H020(AlarmCodeConstants.ALARM_H020,
            R.string.illegal_instruction_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 看门狗重启告警
    H021(AlarmCodeConstants.ALARM_H021,
            R.string.watchdog_reset_event_title,
            R.string.contact_cyber_after_sales_team_text),
    // 激光器通信告警
    H022(AlarmCodeConstants.ALARM_H022,
            R.string.laser_communication_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 激光器电流告警
    H023(AlarmCodeConstants.ALARM_H023,
            R.string.laser_current_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 红光电流告警
    H024(AlarmCodeConstants.ALARM_H024,
            R.string.red_light_current_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 泵源电压告警
    H025(AlarmCodeConstants.ALARM_H025,
            R.string.pump_source_voltage_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 激光器驱动通信告警
    H026(AlarmCodeConstants.ALARM_H026,
            R.string.laser_driver_communication_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // AD反馈通讯告警
    H027(AlarmCodeConstants.ALARM_H027,
            R.string.ad_feedback_communication_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 冷水互锁告警
    H028(AlarmCodeConstants.ALARM_H028,
            R.string.cold_water_interlock_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 激光器急停告警
    H029(AlarmCodeConstants.ALARM_H029,
            R.string.laser_emergency_stop_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 定位光故障告警
    H030(AlarmCodeConstants.ALARM_H030,
            R.string.positioning_light_fault_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 窄脉冲保护告警
    H031(AlarmCodeConstants.ALARM_H031,
            R.string.narrow_pulse_protection_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 驱动板过压
    H032(AlarmCodeConstants.ALARM_H032,
            R.string.driver_board_overvoltage_title,
            R.string.contact_cyber_after_sales_team_text),
    // 环境温度告警
    H033(AlarmCodeConstants.ALARM_H033,
            R.string.environment_temperature_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 零点偏移告警（产线 AI 检测）
    H034(AlarmCodeConstants.ALARM_H034,
            R.string.zero_point_offset_alarm_title,
            R.string.zero_point_offset_alert_body),

    // 镜片重度污染告警
    L001(AlarmCodeConstants.ALARM_L001,
            R.string.lens_heavy_contamination_alarm_title,
            R.string.lens_alert_heavy_body_default),

    // 主控板与平板 Modbus 通讯故障（状态读数截断）
    C001(AlarmCodeConstants.ALARM_C001,
            R.string.controller_tablet_comm_alarm_title,
            R.string.controller_tablet_comm_alarm_content),

    // 工业摄像头 HTTP 通信告警
    C002(AlarmCodeConstants.ALARM_C002,
            R.string.camera_communication_alarm_title,
            R.string.camera_communication_alarm_content),

    // 主控板与温控板通讯故障（激光模组故障表）
    C003(AlarmCodeConstants.ALARM_C003,
            R.string.main_controller_temp_board_comm_alarm_title,
            R.string.main_controller_temp_board_comm_alarm_content),

    // 温控板与制冷系统通讯故障（激光模组故障表）
    C004(AlarmCodeConstants.ALARM_C004,
            R.string.temp_board_refrigeration_comm_alarm_title,
            R.string.temp_board_refrigeration_comm_alarm_content),

    // 送丝机通信告警
    W001(AlarmCodeConstants.ALARM_W001,
            R.string.wire_feeder_communication_alarm_title,
            R.string.contact_cyber_after_sales_team_text),
    // 送丝机电流告警
    W002(AlarmCodeConstants.ALARM_W002,
            R.string.wire_feeder_current_alarm_title,
            R.string.contact_cyber_after_sales_team_text),

    // 泵浦模块超温解除
    X006(AlarmCodeConstants.ALARM_X006,
            R.string.pump_module_overtemperature_cleared_title,
            R.string.contact_cyber_after_sales_team_text),
    // 水温超限解除
    X008(AlarmCodeConstants.ALARM_X008,
            R.string.water_temperature_limit_cleared_title,
            R.string.contact_cyber_after_sales_team_text),
    // 光纤温度超上限解除
    X009(AlarmCodeConstants.ALARM_X009,
            R.string.fiber_temperature_upper_limit_cleared_title
            ,
            R.string.contact_cyber_after_sales_team_text),
    // 激光反射能量超上限解除
    X010(AlarmCodeConstants.ALARM_X010,
            R.string.laser_reflected_energy_upper_limit_cleared_title,
            R.string.contact_cyber_after_sales_team_text),
    // 激光输出能量超下限解除
    X011(AlarmCodeConstants.ALARM_X011,
            R.string.laser_output_energy_lower_limit_cleared_title,
            R.string.contact_cyber_after_sales_team_text),
    // 二极体短路故障解除
    X012(AlarmCodeConstants.ALARM_X012,
            R.string.diode_short_circuit_error_cleared_title,
            R.string.contact_cyber_after_sales_team_text),
    // 光纤断开解除
    X013(AlarmCodeConstants.ALARM_X013,
            R.string.fiber_disconnection_cleared_title,
            R.string.contact_cyber_after_sales_team_text);
    /**
     * 故障码
     */
    public final String errorCode;
    /**
     * 提示标题
     */
    public final int titleId;
    /**
     * 提示内容Id
     */
    public final int contentId;

    /**
     * 查找标题Id
     *
     * @param errorCode
     * @return
     */
    public static int findTitleId(String errorCode) {
        for (AlarmCodeEnums value : values()) {
            if (value.errorCode.equals(errorCode)) {
                return value.titleId;
            }
        }
        return -1;
    }

    @Nullable
    public static AlarmCodeEnums findByCode(@Nullable String errorCode) {
        if (errorCode == null) {
            return null;
        }
        for (AlarmCodeEnums value : values()) {
            if (value.errorCode.equals(errorCode)) {
                return value;
            }
        }
        return null;
    }
}
