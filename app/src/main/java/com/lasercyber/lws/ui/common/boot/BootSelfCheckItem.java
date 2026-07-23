package com.lasercyber.lws.ui.common.boot;

import androidx.annotation.StringRes;

import com.lasercyber.lws.ui.R;

/**
 * Fixed-order boot self-check items aligned with Monitor → Alarm Information tiles.
 */
public enum BootSelfCheckItem {

    CONTROLLER_COMM(R.string.boot_self_check_controller_comm, ItemKind.MODBUS_CONTROLLER),
    PUMP_COMM(R.string.pump_status_text, ItemKind.MODBUS_COMM),
    GUN_COMM(R.string.gun_head_communication_text, ItemKind.MODBUS_COMM),
    MOTOR_DRIVER_TEMP(R.string.motor_driver_temperature_text, ItemKind.MODBUS_TEMPERATURE),
    GUN_MOTOR_TEMP(R.string.gun_motor_temp_text, ItemKind.MODBUS_TEMPERATURE),
    PROTECTION_MIRROR_TEMP(R.string.protective_mirror_temperature_text, ItemKind.MODBUS_TEMPERATURE),
    COLLIMATOR_TEMP(R.string.collimator_temperature_text, ItemKind.MODBUS_TEMPERATURE),
    WIRE_FEEDER_COMM(R.string.wire_feeding_machine_communication_text, ItemKind.MODBUS_COMM),
    CAMERA_COMM(R.string.camera_comm_status_text, ItemKind.CAMERA);

    @StringRes
    private final int labelResId;
    private final ItemKind kind;

    BootSelfCheckItem(@StringRes int labelResId, ItemKind kind) {
        this.labelResId = labelResId;
        this.kind = kind;
    }

    @StringRes
    public int getLabelResId() {
        return labelResId;
    }

    public ItemKind getKind() {
        return kind;
    }

    public boolean requiresControllerReady() {
        return kind != ItemKind.CAMERA;
    }

    enum ItemKind {
        MODBUS_CONTROLLER,
        MODBUS_COMM,
        MODBUS_TEMPERATURE,
        CAMERA
    }
}
