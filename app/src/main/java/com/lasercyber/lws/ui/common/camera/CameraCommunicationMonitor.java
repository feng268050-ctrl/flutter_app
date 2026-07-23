package com.lasercyber.lws.ui.common.camera;

import android.content.Context;
import android.util.Log;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.handler.CameraCommunicationAlarmController;

/**
 * Defers camera ICMP health checks and C002 alarms until the HMI home screen ({@link com.lasercyber.lws.ui.MainActivity})
 * is shown, so popups always have a foreground Activity.
 */
public final class CameraCommunicationMonitor {

    private static final String TAG = LogTAGConstant.CameraCommunicationAlarm;

    private static boolean started;

    private CameraCommunicationMonitor() {
    }

    /**
     * Idempotent: starts 1 Hz ping and the C002 listener when the operator reaches the home page.
     */
    public static synchronized void startWhenHomeEntered(@Nullable Context context) {
        if (started || context == null) {
            return;
        }
        Context app = context.getApplicationContext();
        CameraPingHealthScheduler.getInstance().start(app);
        CameraCommunicationAlarmController.getInstance().start(app);
        started = true;
        Log.d(TAG, "Camera communication monitor started (home entered)");
    }

    public static synchronized void stop() {
        if (!started) {
            return;
        }
        CameraPingHealthScheduler.getInstance().stop();
        CameraCommunicationAlarmController.getInstance().stop();
        started = false;
        Log.d(TAG, "Camera communication monitor stopped");
    }

    /** Visible for unit tests. */
    public static boolean isStartedForTest() {
        return started;
    }

    /** Visible for unit tests. */
    public static void resetStartedForTest() {
        started = false;
    }
}
