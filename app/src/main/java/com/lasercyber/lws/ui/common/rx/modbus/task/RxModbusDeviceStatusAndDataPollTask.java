package com.lasercyber.lws.ui.common.rx.modbus.task;

import android.os.SystemClock;
import android.util.Log;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusManagerRtu;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusOtaExclusiveSession;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusPollCycleGuard;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusPollDiagnostics;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusSerialGate;
import com.lasercyber.lws.ui.common.rx.modbus.call.RxModbusCallBack;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusFiledBuilder;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusReadFiled;

import java.util.List;

/**
 * 100ms refresh timer tick attempts one poll cycle: device status then device data.
 * Discards the tick when a prior cycle or other Modbus I/O is in flight; 50ms gate between commands.
 */
public class RxModbusDeviceStatusAndDataPollTask extends AbstractRxModbusTask {

    private static final String TAG = LogTAGConstant.RxModbusPollResults;

    @Override
    public void run() {
        tryStartPollCycle();
    }

    public static void tryStartPollCycle() {
        String discard = peekDiscardReason();
        if (discard != null) {
            ModbusPollDiagnostics.recordDiscard(discard);
            return;
        }
        long cycleStartMs = SystemClock.uptimeMillis();
        ModbusManagerRtu.get().readInputRegistersSort(
                ModbusFiledBuilder.createDeviceStatus(),
                new RxModbusCallBack() {
                    @Override
                    public void onSuccess(List<ModbusReadFiled> statusFields) {
                        RxModbusPollResults.applyDeviceStatus(statusFields);
                        ModbusManagerRtu.get().readInputRegistersSort(
                                ModbusFiledBuilder.createDeviceData(),
                                new RxModbusCallBack() {
                                    @Override
                                    public void onSuccess(List<ModbusReadFiled> dataFields) {
                                        RxModbusPollResults.applyDeviceData(dataFields);
                                        finishCycle(cycleStartMs);
                                    }

                                    @Override
                                    public void onFailure(Throwable error) {
                                        RxModbusPollResults.applyDeviceDataFailure(error);
                                        finishCycle(cycleStartMs);
                                    }
                                });
                    }

                    @Override
                    public void onFailure(Throwable error) {
                        RxModbusPollResults.applyDeviceStatusFailure(error);
                        finishCycle(cycleStartMs);
                    }
                });
    }

    private static void finishCycle(long cycleStartMs) {
        RxModbusPollResults.finishPollCycle();
        ModbusPollCycleGuard.end();
        ModbusPollDiagnostics.recordCycleComplete(SystemClock.uptimeMillis() - cycleStartMs);
    }

    /** @return discard reason, or {@code null} if a poll cycle may start (and guard is acquired). */
    public static String peekDiscardReason() {
        if (ModbusOtaExclusiveSession.isActive()) {
            return "ota_active";
        }
        if (ModbusSerialGate.getInstance().isCommandInFlight()) {
            return "bus_busy";
        }
        if (!ModbusPollCycleGuard.tryBegin()) {
            return "cycle_in_flight";
        }
        return null;
    }
}
