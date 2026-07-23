package com.lasercyber.lws.ui.common.handler;

import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.gpio.IndicatorMode;
import com.lasercyber.lws.ui.common.gpio.LedColor;
import com.lasercyber.lws.ui.common.gpio.LedIndicatorManager;
import com.lasercyber.lws.ui.common.gpio.LaserEnableStateHolder;

public class GpioLedHandler {

    private static volatile boolean autoRefreshPaused;

    public static void setAutoRefreshPaused(boolean paused) {
        autoRefreshPaused = paused;
    }

    public static boolean isAutoRefreshPaused() {
        return autoRefreshPaused;
    }

    public static void ledHandler(DeviceStatus deviceStatus) {
        if (autoRefreshPaused) {
            return;
        }
        applyLedStates(deviceStatus, LaserEnableStateHolder.isActive());
    }

    public static void refresh() {
        if (autoRefreshPaused) {
            return;
        }
        DeviceStatus deviceStatus = MemoryCacheManager.getInstance()
                .getSerializable(CacheKey.DEVICE_STATUS_KEY);
        ledHandler(deviceStatus);
    }

    /** Applies business LED rules even when auto refresh is paused (Dev manual refresh). */
    public static void refreshForced() {
        DeviceStatus deviceStatus = MemoryCacheManager.getInstance()
                .getSerializable(CacheKey.DEVICE_STATUS_KEY);
        applyLedStates(deviceStatus, LaserEnableStateHolder.isActive());
    }

    static void applyLedStates(DeviceStatus deviceStatus, boolean laserEnableActive) {
        applyColor(LedColor.RED, toIndicatorMode(RgbLedDecision.redMode(deviceStatus)));
        applyColor(LedColor.YELLOW, toIndicatorMode(RgbLedDecision.yellowMode(deviceStatus, Utils.getApp())));
        applyColor(
                LedColor.GREEN,
                toIndicatorMode(RgbLedDecision.greenMode(
                        deviceStatus,
                        laserEnableActive,
                        Utils.getApp(),
                        LaserEnableStateHolder.getActiveWorkModel())));
    }

    private static void applyColor(LedColor color, IndicatorMode mode) {
        LedIndicatorManager.setIndicator(color, mode);
    }

    private static IndicatorMode toIndicatorMode(RgbLedDecision.RedMode mode) {
        switch (mode) {
            case STEADY_ON:
                return IndicatorMode.STEADY_ON;
            case BLINK:
                return IndicatorMode.BLINK;
            default:
                return IndicatorMode.OFF;
        }
    }

    private static IndicatorMode toIndicatorMode(RgbLedDecision.YellowMode mode) {
        switch (mode) {
            case BLINK:
                return IndicatorMode.BLINK;
            default:
                return IndicatorMode.OFF;
        }
    }

    private static IndicatorMode toIndicatorMode(RgbLedDecision.GreenMode mode) {
        switch (mode) {
            case STEADY_ON:
                return IndicatorMode.STEADY_ON;
            default:
                return IndicatorMode.OFF;
        }
    }
}
