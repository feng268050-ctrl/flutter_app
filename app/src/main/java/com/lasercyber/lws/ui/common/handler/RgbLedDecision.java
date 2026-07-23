package com.lasercyber.lws.ui.common.handler;

import android.content.Context;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.activitys.engineer.mode.ui.LaserEnableAlarmGuard;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.constant.ModelConstant;

/**
 * Pure predicates for tablet RGB GPIO indicator desired state.
 *
 * <p>Red = laser indicator; yellow = alarm; green = ready.</p>
 */
public final class RgbLedDecision {

    public enum RedMode {
        STEADY_ON,
        BLINK,
        OFF
    }

    public enum YellowMode {
        BLINK,
        OFF
    }

    public enum GreenMode {
        STEADY_ON,
        OFF
    }

    private RgbLedDecision() {
    }

    public static RedMode redMode(DeviceStatus deviceStatus) {
        if (deviceStatus == null) {
            return RedMode.OFF;
        }
        if (deviceStatus.isLaserOn()) {
            return RedMode.STEADY_ON;
        }
        if (deviceStatus.isLaserCommunicationAlarm()) {
            return RedMode.OFF;
        }
        return RedMode.BLINK;
    }

    public static YellowMode yellowMode(@Nullable DeviceStatus deviceStatus) {
        return yellowMode(deviceStatus, null);
    }

    public static YellowMode yellowMode(@Nullable DeviceStatus deviceStatus, @Nullable Context context) {
        if (WarnDialogSeverity.hasAnyActiveWarnSeverityAlarm(deviceStatus, context)) {
            return YellowMode.BLINK;
        }
        return YellowMode.OFF;
    }

    public static GreenMode greenMode(DeviceStatus deviceStatus, boolean laserEnableActive) {
        return greenMode(deviceStatus, laserEnableActive, null, 0);
    }

    public static GreenMode greenMode(
            DeviceStatus deviceStatus, boolean laserEnableActive, @Nullable Context context) {
        return greenMode(deviceStatus, laserEnableActive, context, 0);
    }

    public static GreenMode greenMode(
            DeviceStatus deviceStatus,
            boolean laserEnableActive,
            @Nullable Context context,
            int workModel) {
        if (deviceStatus == null
                || deviceStatus.isLaserOn()
                || LaserEnableAlarmGuard.isReadyIndicatorBlocked(context, deviceStatus)) {
            return GreenMode.OFF;
        }
        if (!deviceStatus.isKeySwitchOn()) {
            return GreenMode.OFF;
        }
        if (workModel == ModelConstant.CNC_CUT) {
            return deviceStatus.isConnectCNC() ? GreenMode.STEADY_ON : GreenMode.OFF;
        }
        if (laserEnableActive && deviceStatus.isSafetyGroundLockLocked()) {
            return GreenMode.STEADY_ON;
        }
        return GreenMode.OFF;
    }
}
