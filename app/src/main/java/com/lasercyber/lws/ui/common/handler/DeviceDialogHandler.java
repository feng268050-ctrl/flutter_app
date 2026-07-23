package com.lasercyber.lws.ui.common.handler;

import android.app.Activity;
import android.content.ComponentName;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;

import com.blankj.utilcode.util.ActivityUtils;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.bean.entity.vo.WarnDialogVo;
import com.lasercyber.lws.ui.common.boot.BootSelfCheckGate;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.LaserEnableAlarmGuard;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.LaserWorkGuard;
import com.lasercyber.lws.ui.common.utils.convert.DeviceStatusConvert;
import com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodeController;

import cn.hutool.core.util.ObjectUtil;

/**
 * 后台 设备弹窗处理
 */
public class DeviceDialogHandler {
    private static final Handler handler = new Handler(Looper.getMainLooper());
    private static final String TAG = LogTAGConstant.DeviceDialogHandler;

    private static final int WARN_DIALOG_ACTIVITY_RETRY_MAX = 60;
    private static final long WARN_DIALOG_ACTIVITY_RETRY_MS = 500L;

    /** Modbus-driven passive popup evaluation (non-Modbus sources use {@link WarnAlarmPipeline}). */
    public static void checkModbusDeviceStatus(DeviceStatus deviceStatus) {
        if (BootSelfCheckGate.isActive()) {
            Log.d(TAG, "checkModbusDeviceStatus: suppressed during boot self-check");
            return;
        }
        // convertToWarnDialogVo may call closeWarn; UI dismiss must run on the main thread.
        handler.post(() -> evaluateModbusWarnOnMainThread(deviceStatus));
    }

    private static void evaluateModbusWarnOnMainThread(DeviceStatus deviceStatus) {
        if (BootSelfCheckGate.isActive()) {
            Log.d(TAG, "checkModbusDeviceStatus: suppressed during boot self-check");
            return;
        }
        WarnDialogVo vo = DeviceStatusConvert.convertToWarnDialogVo(deviceStatus, false);
        if (vo != null) {
            showWarnDialogOnMainThread(vo, 0);
        }
    }

    public static void showPassiveWarnDialog(WarnDialogVo vo) {
        if (vo == null) {
            return;
        }
        if (BootSelfCheckGate.isActive()) {
            Log.d(TAG, "showPassiveWarnDialog: suppressed during boot self-check");
            return;
        }
        showWarnDialog(vo);
    }

    /** Visible for unit tests. */
    public static boolean isAsyncWarnSuppressed() {
        return BootSelfCheckGate.isActive();
    }

    private static void showWarnDialog(WarnDialogVo vo) {
        showWarnDialog(vo, 0);
    }

    private static void showWarnDialog(WarnDialogVo vo, int attempt) {
        handler.post(() -> showWarnDialogOnMainThread(vo, attempt));
    }

    private static void showWarnDialogOnMainThread(WarnDialogVo vo, int attempt) {
        if (BootSelfCheckGate.isActive()) {
            Log.d(TAG, "showWarnDialog: suppressed during boot self-check");
            return;
        }
        Activity topActivity = ActivityUtils.getTopActivity();
        if (topActivity == null || topActivity.isFinishing()) {
            if (attempt < WARN_DIALOG_ACTIVITY_RETRY_MAX
                    && vo.getErrorCode() != null
                    && WarnEpisodeController.isReminderPending(vo.getErrorCode())) {
                handler.postDelayed(
                        () -> showWarnDialog(vo, attempt + 1),
                        WARN_DIALOG_ACTIVITY_RETRY_MS);
                return;
            }
            if (vo.getErrorCode() != null && WarnEpisodeController.isReminderPending(vo.getErrorCode())) {
                Log.w(TAG, "showWarnDialog: no activity for " + vo.getErrorCode()
                        + ", will retry on next device status poll");
            }
            return;
        }
        ComponentName componentName = topActivity.getComponentName();
        String shortClassName = componentName.getShortClassName();
        if (ObjectUtil.equals(shortClassName, ".activitys.SafetyTipsActivity")) {
            return;
        }
        WarnEpisodeController.requestPassiveShow(topActivity, vo);
        maybeInterruptLaserForCodedWarn(topActivity, vo);
    }

    private static void maybeInterruptLaserForCodedWarn(@NonNull Activity activity, @NonNull WarnDialogVo vo) {
        if (LaserEnableAlarmGuard.shouldInterruptLaserForErrorCode(vo.getErrorCode())) {
            LaserWorkGuard.evaluateAndInterruptIfNeeded(activity);
        }
    }

    /**
     * 快速检查设备状态
     *
     * @param activity
     * @return true:未告警，false：告警中
     */
    public static boolean quickCheckDeviceStatus(Activity activity) {
        DeviceStatus deviceStatus = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        if (deviceStatus == null) {
            Log.d(TAG, "quickCheckDeviceStatus: 状态数据为空，不用判断告警");
            return true;
        }
        WarnDialogVo vo = DeviceStatusConvert.convertToWarnDialogVo(deviceStatus, true);
        if (vo == null) {
            Log.d(TAG, "quickCheckDeviceStatus: 当前没有告警，可以正常打开激光");
            return true;
        }
        WarnEpisodeController.requestImmediateShow(activity, vo);
        maybeInterruptLaserForCodedWarn(activity, vo);
        return false;
    }
}
