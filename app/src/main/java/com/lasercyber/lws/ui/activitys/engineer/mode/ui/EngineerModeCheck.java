package com.lasercyber.lws.ui.activitys.engineer.mode.ui;

import android.app.Activity;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.DeviceData;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.config.ModbusConfig;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.handler.DeviceDialogHandler;

/**
 * 工程师模式校验
 */
public class EngineerModeCheck {
    protected static final Handler HANDLER = new Handler(Looper.getMainLooper());
    private static final String TAG = LogTAGConstant.EngineerModeCheck;
    private static final boolean isDebug = true;
    private static volatile Runnable task;
    /**
     * 开启激光校验
     * @return
     */
    public static boolean enableLaser(int model, Activity context) {
        DeviceStatus deviceStatus = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);

        if (!passesWorkStatusForLaserEnable(context, deviceStatus)) {
            return false;
        }
        if (!LaserEnableAlarmGuard.passesPreflight(context)) {
            return false;
        }
        return DeviceDialogHandler.quickCheckDeviceStatus(context);
    }

    /** Key switch, E-stop, and related machine-status gates shared by quick/engineer laser enable. */
    public static boolean passesWorkStatusForLaserEnable(@Nullable Context context, @Nullable DeviceStatus deviceStatus) {
        return checkWorkStatus(context, deviceStatus);
    }

    public static boolean checkWorkStatus(Context context, DeviceStatus deviceStatus) {
        if (deviceStatus == null) {
            OperationDialogBuilder.openErrorDialog(context,R.string.please_check_the_equipment_text);
            return false;
        }
//        if (ModelConstant.WELD_CLEAN!=model&&ModelConstant.WIDTH_CLEAN!=model){
        if (deviceStatus.isEmergencyStopTriggered()){
            OperationDialogBuilder.openErrorDialog(context,R.string.check_e_stop_state_error);
            return false;
        }
        if (isKeySwitchPreflightBlocking(deviceStatus)) {
            OperationDialogBuilder.openErrorDialog(context, R.string.check_key_error_text);
            return false;
        }
//        }
        return true;
    }

    static boolean isKeySwitchPreflightBlocking(DeviceStatus deviceStatus) {
        return !ModbusConfig.isMock() && !deviceStatus.isKeySwitchOn();
    }

    /**
     * 激光电流检测
     *
     * @param context
     */
    public static void checkLaserCurrentStatus(Activity context) {
        if (checkLaserCurrent()) {
            if (task != null) {
                return;
            }
            task = () -> {
                removeHandlerCallBack();
                if (isDebug) Log.d(TAG, "checkLaserCurrentStatus: 延迟3s后，再次检测激光电流");
                if (!checkLaserCurrent()) {
                    Log.d(TAG, "checkLaserCurrentStatus: 检测通过，结束任务");
                    return;
                }
                if (isDebug) Log.d(TAG, "checkLaserCurrentStatus: 激光电流异常，打开激光异常提示框");
                OperationDialogBuilder.openErrorDialog(context, R.string.laser_anomaly);
            };
            if (isDebug)
                Log.d(TAG, "checkLaserCurrentStatus: 激光电流异常，加入延迟任务，3s后再次检测");
            HANDLER.postDelayed(task, 3000);
            return;
        }
        removeHandlerCallBack();
    }

    /**
     * 移除任务
     */
    public static void removeHandlerCallBack() {
        if (task != null) {
            HANDLER.removeCallbacks(task);
            task = null;
        }
    }

    /**
     * @return false：激光电流正常 true：激光电流异常
     */
    private static boolean checkLaserCurrent() {
        DeviceData deviceData = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_DATA_KEY);
        if (deviceData == null || deviceData.getLaserCurrent() != null && deviceData.getLaserCurrent() > 0) {
            // 激光电流小于等于0，不管
            if (isDebug) Log.d(TAG, "checkLaserCurrent: 激光电流大于0，不管");
            return false;
        }
        DeviceStatus deviceStatus = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        if (deviceStatus == null) {

            if (isDebug) Log.d(TAG, "checkLaserCurrent: 设备状态为空，不管");
            return false;
        }
        if (!deviceStatus.isLaserOn()) {
            // 激光没有开启，不管
            if (isDebug) Log.d(TAG, "checkLaserCurrent: 激光没有开启，不管");
            return false;
        }
        return true;
    }
}
