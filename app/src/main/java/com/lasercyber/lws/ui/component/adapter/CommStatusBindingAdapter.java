package com.lasercyber.lws.ui.component.adapter;

import androidx.databinding.BindingAdapter;

import com.lasercyber.lws.frostui.control.FrostStatusState;
import com.lasercyber.lws.frostui.control.FrostStatusVariant;
import com.lasercyber.lws.frostui.control.interop.FrostStatusIndicatorView;
import com.lasercyber.lws.ui.activitys.device.monitor.CommStatusDisplay;

/**
 * Binds alarm comm/metric indicators to {@link FrostStatusIndicatorView} Icon variant (check/cross).
 */
public final class CommStatusBindingAdapter {

    private CommStatusBindingAdapter() {
    }

    @BindingAdapter(value = {"commStatusEmulator", "commStatusReady", "commStatusAlarm"}, requireAll = false)
    public static void setCommStatusIndicator(
            FrostStatusIndicatorView indicator,
            boolean emulator,
            boolean statusReady,
            Boolean commAlarm) {
        if (indicator == null) {
            return;
        }
        boolean alarm = commAlarm != null && commAlarm;
        applyDisplay(indicator, CommStatusDisplay.resolve(emulator, statusReady, alarm));
    }

    @BindingAdapter(value = {
            "cameraCommStatusEmulator",
            "cameraCommStatusReady",
            "cameraCommStatusAlarm",
            "cameraCommHostConfigured"
    }, requireAll = false)
    public static void setCameraCommStatusIndicator(
            FrostStatusIndicatorView indicator,
            boolean emulator,
            boolean statusReady,
            Boolean commAlarm,
            boolean cameraHostConfigured) {
        if (indicator == null) {
            return;
        }
        boolean alarm = commAlarm != null && commAlarm;
        applyDisplay(indicator, CommStatusDisplay.resolveCameraComm(
                emulator, statusReady, alarm, cameraHostConfigured));
    }

    @BindingAdapter(value = {"alarmMetricReady", "alarmMetricHasValue", "alarmMetricFault"}, requireAll = false)
    public static void setAlarmMetricIndicator(
            FrostStatusIndicatorView indicator,
            boolean ready,
            Boolean hasValue,
            Boolean fault) {
        if (indicator == null) {
            return;
        }
        boolean valuePresent = hasValue != null && hasValue;
        boolean faultActive = fault != null && fault;
        applyDisplay(indicator, CommStatusDisplay.resolveMetric(ready, valuePresent, faultActive));
    }

    static FrostStatusState toStatusState(CommStatusDisplay state) {
        if (state == CommStatusDisplay.HEALTHY) {
            return FrostStatusState.Success;
        }
        if (state == CommStatusDisplay.FAULT) {
            return FrostStatusState.Failure;
        }
        return FrostStatusState.Idle;
    }

    private static void applyDisplay(FrostStatusIndicatorView indicator, CommStatusDisplay state) {
        indicator.setVariant(FrostStatusVariant.Icon);
        indicator.setState(toStatusState(state));
    }
}
