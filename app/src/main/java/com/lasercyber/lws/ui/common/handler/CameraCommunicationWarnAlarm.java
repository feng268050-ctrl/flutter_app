package com.lasercyber.lws.ui.common.handler;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.bean.entity.WarnTable;
import com.lasercyber.lws.ui.bean.entity.vo.WarnDialogVo;
import com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodeController;
import com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodePolicy;
import com.lasercyber.lws.ui.common.camera.CameraCommStatus;
import com.lasercyber.lws.ui.common.enums.AlarmCodeEnums;
import com.lasercyber.lws.ui.common.utils.convert.DeviceStatusConvert;

import java.util.Collections;
import java.util.List;

/**
 * Camera ICMP communication fault ({@link AlarmCodeEnums#C002}), ping-driven instead of Modbus.
 */
public final class CameraCommunicationWarnAlarm implements ExternalWarnAlarm {

    public static final CameraCommunicationWarnAlarm INSTANCE = new CameraCommunicationWarnAlarm();

    private CameraCommunicationWarnAlarm() {
    }

    @NonNull
    @Override
    public String getAlarmCode() {
        return AlarmCodeEnums.C002.errorCode;
    }

    @Override
    public boolean isFaultActive() {
        return CameraCommStatus.isFault();
    }

    @NonNull
    @Override
    public List<WarnTable> buildActiveLogRows() {
        if (!isFaultActive()) {
            return Collections.emptyList();
        }
        return Collections.singletonList(
                DeviceStatusConvert.createSeriousWarnTable(getAlarmCode()));
    }

    @Override
    public void notifyLogFaultCleared() {
        WarnLogEpisodeTracker.notifyFaultCleared(getAlarmCode());
    }

    @Override
    public void prepareOnFaultEdge() {
        WarnEpisodeController.rearmReminder(getAlarmCode());
    }

    @Nullable
    @Override
    public WarnDialogVo buildPassiveDialogVo() {
        if (!isFaultActive()) {
            return null;
        }
        return DeviceStatusConvert.createAlarmHit(
                getAlarmCode(),
                Utils.getApp().getString(AlarmCodeEnums.C002.titleId),
                Utils.getApp().getString(AlarmCodeEnums.C002.contentId),
                true);
    }

    /** Laser-enable preflight: always materialize dialog (no passive warn-cache suppression). */
    @Nullable
    public WarnDialogVo buildActiveBlockDialogVo() {
        if (!isFaultActive()) {
            return null;
        }
        return DeviceStatusConvert.createAlarmHit(
                getAlarmCode(),
                Utils.getApp().getString(AlarmCodeEnums.C002.titleId),
                Utils.getApp().getString(AlarmCodeEnums.C002.contentId),
                false);
    }
}
