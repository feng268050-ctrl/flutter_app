package com.lasercyber.lws.ui.common.handler;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.camera.CameraCommStatus;
import com.lasercyber.lws.ui.common.constant.AlarmCodeConstants;
import com.lasercyber.lws.ui.common.enums.AlarmCodeEnums;
import com.lasercyber.lws.ui.common.settings.DangerousOperationsSettings;
import com.lasercyber.lws.ui.common.utils.ShieldingGasAlarmMessageUtil;
import com.lasercyber.lws.ui.common.utils.WarnUtil;
import com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodeController;

/**
 * Maps coded alarms to {@link WarnUtil#WARN_TYPE} vs {@link WarnUtil#INFO_TYPE} from dangerous-operations bypass toggles.
 */
public final class WarnDialogSeverity {

    private WarnDialogSeverity() {
    }

    public static int dialogTypeForCode(@NonNull String alarmCode, @Nullable Context context) {
        if (isBypassAllowingInfo(alarmCode, context)) {
            return WarnUtil.INFO_TYPE;
        }
        return WarnUtil.WARN_TYPE;
    }

    public static boolean isWarnSeverity(@NonNull String alarmCode, @Nullable Context context) {
        return dialogTypeForCode(alarmCode, context) == WarnUtil.WARN_TYPE;
    }

    public static boolean hasAnyActiveWarnSeverityAlarm(
            @Nullable DeviceStatus deviceStatus, @Nullable Context context) {
        if (isActiveAtWarnSeverity(AlarmCodeConstants.ALARM_C002, context)) {
            if (CameraCommStatus.isFault()
                    || WarnEpisodeController.isDemoFaultActive(AlarmCodeConstants.ALARM_C002)) {
                return true;
            }
        }
        if (isActiveAtWarnSeverity(AlarmCodeConstants.ALARM_L001, context)) {
            if (LensHeavyContaminationWarnAlarm.INSTANCE.isLaserEnableBlocked()
                    || WarnEpisodeController.isDemoFaultActive(AlarmCodeConstants.ALARM_L001)) {
                return true;
            }
        }
        if (isActiveAtWarnSeverity(AlarmCodeConstants.ALARM_A001, context)) {
            if ((deviceStatus != null && ShieldingGasAlarmMessageUtil.hasActiveAlarm(deviceStatus))
                    || WarnEpisodeController.isDemoFaultActive(AlarmCodeConstants.ALARM_A001)) {
                return true;
            }
        }
        if (deviceStatus != null) {
            if (deviceStatus.isWireFeederCommunicationAlarm()
                    && isActiveAtWarnSeverity(AlarmCodeConstants.ALARM_W001, context)) {
                return true;
            }
            if (deviceStatus.isWireFeederCurrentAlarm()
                    && isActiveAtWarnSeverity(AlarmCodeConstants.ALARM_W002, context)) {
                return true;
            }
            if (hasNonFeederHardwareAlarm(deviceStatus)) {
                return true;
            }
        }
        if (isActiveAtWarnSeverity(AlarmCodeConstants.ALARM_W001, context)
                && WarnEpisodeController.isDemoFaultActive(AlarmCodeConstants.ALARM_W001)) {
            return true;
        }
        if (isActiveAtWarnSeverity(AlarmCodeConstants.ALARM_W002, context)
                && WarnEpisodeController.isDemoFaultActive(AlarmCodeConstants.ALARM_W002)) {
            return true;
        }
        AlarmCodeEnums otherBlocking = WarnEpisodeController.findFirstBlockingOtherCodedWarn();
        if (otherBlocking != null && isActiveAtWarnSeverity(otherBlocking.errorCode, context)) {
            return true;
        }
        return false;
    }

    private static boolean isActiveAtWarnSeverity(@NonNull String alarmCode, @Nullable Context context) {
        return isWarnSeverity(alarmCode, context);
    }

    private static boolean isBypassAllowingInfo(@NonNull String alarmCode, @Nullable Context context) {
        if (AlarmCodeConstants.ALARM_A001.equals(alarmCode)) {
            return DangerousOperationsSettings.isAllowWorkAfterGasAlarm(context);
        }
        if (AlarmCodeConstants.ALARM_C002.equals(alarmCode)) {
            return DangerousOperationsSettings.isAllowWorkAfterCameraAlarm(context);
        }
        if (AlarmCodeConstants.ALARM_L001.equals(alarmCode)) {
            return DangerousOperationsSettings.isAllowWorkAfterLensContamination(context);
        }
        if (AlarmCodeConstants.ALARM_W001.equals(alarmCode)
                || AlarmCodeConstants.ALARM_W002.equals(alarmCode)) {
            return DangerousOperationsSettings.isAllowWorkAfterFeederAlarm(context);
        }
        return false;
    }

    private static boolean hasNonFeederHardwareAlarm(@NonNull DeviceStatus deviceStatus) {
        return isSegmentActive(deviceStatus.getGunAlarmSeg1())
                || isSegmentActive(deviceStatus.getGunAlarmSeg2())
                || isSegmentActive(deviceStatus.getGunAlarmSeg3())
                || isSegmentActive(deviceStatus.getGunAlarmSeg4())
                || isSegmentActive(deviceStatus.getLaserAlarmSeg1())
                || isSegmentActive(deviceStatus.getLaserAlarmSeg2())
                || isSegmentActive(deviceStatus.getLaserAlarmSeg3())
                || isSegmentActive(deviceStatus.getLaserAlarmSeg4())
                || isSegmentActive(deviceStatus.getControlCardAlarmSeg1())
                || isSegmentActive(deviceStatus.getControlCardAlarmSeg2());
    }

    private static boolean isSegmentActive(@Nullable Integer segment) {
        return segment != null && segment != 0;
    }
}
