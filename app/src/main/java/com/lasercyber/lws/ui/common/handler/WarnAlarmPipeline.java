package com.lasercyber.lws.ui.common.handler;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.activitys.engineer.mode.model.WarnTableViewModel;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.bean.entity.WarnTable;
import com.lasercyber.lws.ui.bean.entity.vo.WarnDialogVo;
import com.lasercyber.lws.ui.common.boot.BootSelfCheckGate;
import com.lasercyber.lws.ui.common.utils.convert.DeviceStatusConvert;

import java.util.List;

/**
 * Shared orchestration for warn log persistence and passive popups.
 * <ul>
 *   <li>Modbus: {@link #onModbusDeviceStatusPolled} on each device-status poll</li>
 *   <li>Immediate non-Modbus: {@link #onExternalFaultActive} / {@link #onExternalFaultCleared}</li>
 *   <li>Live-weld AI: {@link #onLiveWeldFaultSignaled} / {@link #onLiveWeldFaultCleared}</li>
 * </ul>
 * Log insert/update rules live in {@link WarnTableViewModel}; popup gating lives in
 * {@link DeviceDialogHandler} + {@link com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodeController}.
 */
public final class WarnAlarmPipeline {

    private static final String TAG = "WarnAlarmPipeline";
    private static final WarnTableViewModel WARN_TABLE = new WarnTableViewModel();

    private WarnAlarmPipeline() {
    }

    /**
     * Modbus poll callback: persist all active warn rows, then evaluate modbus-driven dialogs.
     */
    public static void onModbusDeviceStatusPolled(@NonNull DeviceStatus deviceStatus,
                                                  @NonNull Context context) {
        if (deviceStatus.requestFirmwareData() || BootSelfCheckGate.isActive()) {
            return;
        }
        WARN_TABLE.saveWarnLog(deviceStatus, context);
        DeviceDialogHandler.checkModbusDeviceStatus(deviceStatus);
    }

    /** Rising edge for a non-Modbus warn source (e.g. camera C002). */
    public static void onExternalFaultActive(@NonNull ExternalWarnAlarm alarm, @NonNull Context context) {
        if (!alarm.isFaultActive()) {
            return;
        }
        alarm.prepareOnFaultEdge();
        List<WarnTable> rows = alarm.buildActiveLogRows();
        if (!rows.isEmpty()) {
            persistWarnLog(rows, context);
        }
        showPassiveDialogIfNeeded(alarm.buildPassiveDialogVo(), alarm.getAlarmCode());
    }

    /** Live weld AI: persist or arm pending and show dialog immediately when eligible. */
    public static void onLiveWeldFaultSignaled(@NonNull ZeroPointOffsetWarnAlarm alarm,
                                               @NonNull Context context) {
        if (BootSelfCheckGate.isActive()) {
            return;
        }
        alarm.onFaultSignaled(context);
    }

    /** Clears a live-weld alert episode. */
    public static void onLiveWeldFaultCleared(@NonNull ZeroPointOffsetWarnAlarm alarm) {
        alarm.onFaultCleared();
    }

    /** Falling edge for an immediate non-Modbus warn source. */
    public static void onExternalFaultCleared(@NonNull ExternalWarnAlarm alarm) {
        alarm.notifyLogFaultCleared();
        DeviceStatusConvert.closeWarn(alarm.getAlarmCode());
    }

    private static void persistWarnLog(@NonNull List<WarnTable> rows,
                                       @NonNull Context context) {
        WARN_TABLE.saveWarnTables(context, rows);
    }

    private static void showPassiveDialogIfNeeded(@Nullable WarnDialogVo vo, @NonNull String alarmCode) {
        if (vo != null) {
            DeviceDialogHandler.showPassiveWarnDialog(vo);
        } else {
            Log.w(TAG, "passive warn dialog skipped for " + alarmCode
                    + " (reminder or episode gating)");
        }
    }
}
