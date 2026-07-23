package com.lasercyber.lws.ui.activitys.device.monitor;

import com.lasercyber.lws.frostui.control.FrostStatusState;

/**
 * Maps machine-status domain signals to {@link FrostStatusState} for indicator display.
 * Modbus / {@link com.lasercyber.lws.ui.bean.entity.DeviceStatus} semantics stay unchanged;
 * only the visual state is resolved here.
 */
public final class MachineStatusIndicatorMapping {

    private MachineStatusIndicatorMapping() {
    }

    /** Target running/on → {@link FrostStatusState#Success}; off → {@link FrostStatusState#Idle} (gray). */
    public static FrostStatusState fromOnOff(boolean on) {
        return on ? FrostStatusState.Success : FrostStatusState.Idle;
    }
}
