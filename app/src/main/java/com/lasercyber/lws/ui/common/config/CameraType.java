package com.lasercyber.lws.ui.common.config;

/**
 * Camera modality from ROM {@code camera_type} in {@code /system/etc/model.properties}.
 */
public enum CameraType {
    /** Blue-light camera (蓝光); default production path. */
    BLUE_LIGHT(1),
    /** Red-light camera (红光); future AI inference path. */
    RED_LIGHT(2);

    private final int value;

    CameraType(int value) {
        this.value = value;
    }

    public int getValue() {
        return value;
    }

    static CameraType fromInt(int value) {
        if (value == RED_LIGHT.value) {
            return RED_LIGHT;
        }
        return BLUE_LIGHT;
    }
}
