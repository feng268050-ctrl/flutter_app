package com.lasercyber.lws.ui.common.handler;

import android.content.Context;
import android.util.Log;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.activitys.engineer.mode.ui.LaserWorkGuard;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.camera.CameraCommStatus;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.enums.AlarmCodeEnums;

/**
 * Observes {@link CacheKey#CAMERA_PING_REACHABLE} edges and delegates C002 log + popup to
 * {@link WarnAlarmPipeline} (same persist/dialog rules as Modbus warns).
 */
public final class CameraCommunicationAlarmController implements MemoryCacheManager.OnCacheChangedListener {

    private static final String TAG = LogTAGConstant.CameraCommunicationAlarm;

    private static final CameraCommunicationAlarmController INSTANCE = new CameraCommunicationAlarmController();
    private static final ExternalWarnAlarm C002 = CameraCommunicationWarnAlarm.INSTANCE;

    @Nullable
    private Context appContext;
    private boolean started;
    @Nullable
    private Boolean lastFault;

    private CameraCommunicationAlarmController() {
    }

    public static CameraCommunicationAlarmController getInstance() {
        return INSTANCE;
    }

    public synchronized void start(Context context) {
        if (started) {
            return;
        }
        appContext = context.getApplicationContext();
        lastFault = CameraCommStatus.isFault();
        MemoryCacheManager.getInstance().addListener(CacheKey.CAMERA_PING_REACHABLE, this);
        started = true;
        if (lastFault) {
            emitActiveFault();
        }
    }

    public synchronized void stop() {
        if (!started) {
            return;
        }
        MemoryCacheManager.getInstance().removeListener(CacheKey.CAMERA_PING_REACHABLE, this);
        started = false;
        appContext = null;
        lastFault = null;
    }

    @Override
    public void onCacheChanged(String key) {
        if (!CacheKey.CAMERA_PING_REACHABLE.equals(key)) {
            return;
        }
        boolean fault = CameraCommStatus.isFault();
        Boolean previous = lastFault;
        lastFault = fault;
        if (previous != null && previous == fault) {
            return;
        }
        if (fault) {
            Log.e(TAG, "Camera communication fault " + AlarmCodeEnums.C002.errorCode
                    + " pingReachable=false");
            emitActiveFault();
        } else {
            emitRecovery();
        }
    }

    private void emitActiveFault() {
        Context context = appContext;
        if (context == null) {
            return;
        }
        WarnAlarmPipeline.onExternalFaultActive(C002, context);
        GpioLedHandler.refresh();
        LaserWorkGuard.evaluateAndInterruptIfNeeded(context);
    }

    private void emitRecovery() {
        Log.i(TAG, "Camera communication recovered " + AlarmCodeEnums.C002.errorCode);
        WarnAlarmPipeline.onExternalFaultCleared(C002);
        GpioLedHandler.refresh();
    }
}
