package com.lasercyber.lws.ui.common.handler;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.bean.entity.WarnTable;
import com.lasercyber.lws.ui.bean.entity.vo.WarnDialogVo;

import java.util.List;

/**
 * A warn source that is not driven by Modbus {@code DeviceStatus} polling (e.g. camera ICMP C002).
 * Immediate log + popup are handled by {@link WarnAlarmPipeline}.
 * Live-weld AI alerts (L001, zero-point offset) use dedicated handlers instead.
 */
public interface ExternalWarnAlarm {

    @NonNull
    String getAlarmCode();

    boolean isFaultActive();

    /** Rows to pass to {@link com.lasercyber.lws.ui.activitys.engineer.mode.model.WarnTableViewModel#saveWarnTables} when fault is active. */
    @NonNull
    List<WarnTable> buildActiveLogRows();

    /** Called on falling edge so {@link WarnLogEpisodeTracker} can close the log episode. */
    void notifyLogFaultCleared();

    /**
     * Optional hook before persist/dialog on a rising edge (e.g. re-arm popup reminder).
     */
    default void prepareOnFaultEdge() {
    }

    /**
     * Passive (background) dialog while fault is active; {@code null} when {@link #isFaultActive()} is false.
     */
    @Nullable
    WarnDialogVo buildPassiveDialogVo();
}
