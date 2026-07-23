package com.lasercyber.lws.ui.component.adapter;

import androidx.databinding.BindingAdapter;

import com.lasercyber.lws.frostui.control.FrostStatusState;
import com.lasercyber.lws.ui.activitys.device.monitor.MachineStatusIndicatorMapping;
import com.lasercyber.lws.ui.component.machine.MachineStatusStatusTile;

public final class MachineStatusBindingAdapter {

    private MachineStatusBindingAdapter() {
    }

    /**
     * Legacy boolean binding: on/off only. Maps to Success / Idle at the adapter layer;
     * use {@link #setMachineStatusIndicatorState} when a full four-state signal is available.
     */
    @BindingAdapter("machineStatusChecked")
    public static void setMachineStatusChecked(MachineStatusStatusTile tile, boolean on) {
        setMachineStatusIndicatorState(tile, MachineStatusIndicatorMapping.fromOnOff(on));
    }

    @BindingAdapter("machineStatusIndicatorState")
    public static void setMachineStatusIndicatorState(MachineStatusStatusTile tile, FrostStatusState state) {
        if (tile == null || state == null) {
            return;
        }
        if (tile.getIndicatorState() != state) {
            tile.setIndicatorState(state);
        }
    }
}
