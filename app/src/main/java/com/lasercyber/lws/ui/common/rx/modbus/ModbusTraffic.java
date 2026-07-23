package com.lasercyber.lws.ui.common.rx.modbus;

/** Classifies Modbus RTU traffic for OTA exclusive session policy. */
public enum ModbusTraffic {
    READ,
    WRITE,
    OTA_WRITE,
    /** Device status read while awaiting control-card OTA confirm ({@code otaUpgradeCmd}). */
    OTA_STATUS_READ
}
