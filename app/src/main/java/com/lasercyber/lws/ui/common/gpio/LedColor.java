package com.lasercyber.lws.ui.common.gpio;

import com.lasercyber.lws.ui.common.config.GpioLedConfig;

public enum LedColor {
    RED(GpioLedConfig.GPIO_RED),
    YELLOW(GpioLedConfig.GPIO_YELLOW),
    GREEN(GpioLedConfig.GPIO_GREEN);

    private final int gpioPin;

    LedColor(int gpioPin) {
        this.gpioPin = gpioPin;
    }

    public int gpioPin() {
        return gpioPin;
    }
}
