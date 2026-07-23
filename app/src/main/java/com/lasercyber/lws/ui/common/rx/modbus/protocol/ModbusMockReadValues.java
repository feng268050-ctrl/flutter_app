package com.lasercyber.lws.ui.common.rx.modbus.protocol;

import androidx.annotation.NonNull;

import com.lasercyber.lws.ui.common.constant.DeviceUpgradeConstant;
import com.lasercyber.lws.ui.common.modbus.register.address.DeviceDataRegisterAddress;
import com.lasercyber.lws.ui.common.modbus.register.address.DeviceInfoRegisterAddress;
import com.lasercyber.lws.ui.common.modbus.register.address.DeviceStatusRegisterAddress;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusOtaExclusiveSession;

import java.util.List;

/**
 * Default register values for emulator Modbus mock reads ({@link com.lasercyber.lws.ui.common.config.ModbusConfig#isMock()}).
 */
public final class ModbusMockReadValues {

    /** LSW01 control board — matches {@link DeviceStatusRegisterAddress#DEVICE_TYPE} protocol. */
    public static final long DEVICE_TYPE_LSW01 = 1L;

    /** Sea-level standard atmospheric pressure (kPa). */
    public static final long STANDARD_ATMOSPHERIC_PRESSURE_KPA = 101L;

    /** Machine Status pump gauge mock display current (A). */
    public static final double PUMP_GAUGE_CURRENT_AMPS = 0.2;

    /** Modbus 0x006F raw for {@link #PUMP_GAUGE_CURRENT_AMPS} (raw × 0.1 = A). */
    public static final long LASER_CURRENT_RAW = 2L;

    /** machineStatusSeg1 Bit3 — red light on. */
    public static final long MACHINE_STATUS_RED_LIGHT_ON = 1L << 3;

    /** Welding Gun motor temperature mock (°C). */
    public static final double GUN_MOTOR_TEMPERATURE_C = 30.6;
    /** Welding Gun driver board temperature mock (°C). */
    public static final double GUN_DRIVER_BOARD_TEMPERATURE_C = 43.3;
    /** Welding Gun protective cover temperature mock (°C). */
    public static final double PROTECTIVE_COVER_TEMPERATURE_C = 30.7;
    /** Welding Gun collimator temperature mock (°C). */
    public static final double COLLIMATOR_TEMPERATURE_C = 30.8;

    /** 0x0061 raw (×0.1 °C) — {@link #GUN_MOTOR_TEMPERATURE_C}. */
    public static final long GUN_MOTOR_TEMPERATURE_RAW = 306L;
    /** 0x0062 raw — {@link #GUN_DRIVER_BOARD_TEMPERATURE_C}. */
    public static final long GUN_DRIVER_BOARD_TEMPERATURE_RAW = 433L;
    /** 0x0063 raw — {@link #PROTECTIVE_COVER_TEMPERATURE_C}. */
    public static final long PROTECTIVE_COVER_TEMPERATURE_RAW = 307L;
    /** 0x0064 raw — {@link #COLLIMATOR_TEMPERATURE_C}. */
    public static final long COLLIMATOR_TEMPERATURE_RAW = 308L;

    /** Device Information — Gunhead SN display value. */
    public static final String MOCK_GUNHEAD_SN = "1832048";
    /** 0x0038/0x0039 raw — hex concat yields {@link #MOCK_GUNHEAD_SN}. */
    public static final long GUN_HEAD_SN_HIGH_RAW = 0x183L;
    public static final long GUN_HEAD_SN_LOW_RAW = 0x2048L;

    /** Device Information — Firmware Version (control-card software version). */
    public static final long MOCK_FIRMWARE_VERSION = 1014L;

    /** Device Information — Laser Version display value. */
    public static final String MOCK_LASER_VERSION = "2025730";
    /** 0x0032/0x0033 raw — hex concat yields {@link #MOCK_LASER_VERSION}. */
    public static final long LASER_SOFTWARE_VERSION_HIGH_RAW = 0x2025L;
    public static final long LASER_SOFTWARE_VERSION_LOW_RAW = 0x730L;

    /** Device Information — Wire Feeder Version (0x0035). */
    public static final long MOCK_WIRE_FEEDER_VERSION = 20L;

    private ModbusMockReadValues() {
    }

    public static void apply(@NonNull List<ModbusReadFiled> fields) {
        for (ModbusReadFiled field : fields) {
            field.setValuePresent(true);
            if (field.getAddress() == DeviceStatusRegisterAddress.DEVICE_TYPE) {
                field.setValue(DEVICE_TYPE_LSW01);
            } else if (field.getAddress() == DeviceStatusRegisterAddress.DEVICE_SOFTWARE_VERSION) {
                field.setValue(MOCK_FIRMWARE_VERSION);
            } else if (field.getAddress() == DeviceStatusRegisterAddress.OTA_UPGRADE_COMMAND
                    && ModbusOtaExclusiveSession.currentPhase() == ModbusOtaExclusiveSession.Phase.AWAIT_CONFIRM) {
                field.setValue(DeviceUpgradeConstant.UPGRADE_SUCCESS);
            } else if (field.getAddress() == DeviceStatusRegisterAddress.MACHINE_STATUS_FIELD_1) {
                field.setValue(MACHINE_STATUS_RED_LIGHT_ON);
            } else if (field.getAddress() == DeviceDataRegisterAddress.BLOWING_PRESSURE) {
                field.setValue(STANDARD_ATMOSPHERIC_PRESSURE_KPA);
            } else if (field.getAddress() == DeviceDataRegisterAddress.LASER_CURRENT) {
                field.setValue(LASER_CURRENT_RAW);
            } else if (field.getAddress() == DeviceDataRegisterAddress.GUN_MOTOR_CURRENT) {
                field.setValue(GUN_MOTOR_TEMPERATURE_RAW);
            } else if (field.getAddress() == DeviceDataRegisterAddress.GUN_MOTOR_DRIVE_TEMPERATURE) {
                field.setValue(GUN_DRIVER_BOARD_TEMPERATURE_RAW);
            } else if (field.getAddress() == DeviceDataRegisterAddress.PROTECTIVE_COVER_TEMPERATURE) {
                field.setValue(PROTECTIVE_COVER_TEMPERATURE_RAW);
            } else if (field.getAddress() == DeviceDataRegisterAddress.COLLIMATOR_TEMPERATURE) {
                field.setValue(COLLIMATOR_TEMPERATURE_RAW);
            } else if (field.getAddress() == DeviceInfoRegisterAddress.LASER_SOFTWARE_VERSION_HIGH) {
                field.setValue(LASER_SOFTWARE_VERSION_HIGH_RAW);
            } else if (field.getAddress() == DeviceInfoRegisterAddress.LASER_SOFTWARE_VERSION_LOW) {
                field.setValue(LASER_SOFTWARE_VERSION_LOW_RAW);
            } else if (field.getAddress() == DeviceInfoRegisterAddress.WIRE_FEEDER_SOFTWARE_VERSION) {
                field.setValue(MOCK_WIRE_FEEDER_VERSION);
            } else if (field.getAddress() == DeviceInfoRegisterAddress.GUN_HEAD_SN_HIGH) {
                field.setValue(GUN_HEAD_SN_HIGH_RAW);
            } else if (field.getAddress() == DeviceInfoRegisterAddress.GUN_HEAD_SN_LOW) {
                field.setValue(GUN_HEAD_SN_LOW_RAW);
            }
        }
    }
}
