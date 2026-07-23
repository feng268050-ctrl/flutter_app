package com.lasercyber.lws.ui.common.constant;

import android.util.Log;

/**
 * Single-tag diagnostics for cloud API probe + video metadata upload (easier {@code adb logcat -s LwsCloudSync:I}).
 */
public final class LwsCloudSyncLog {
    public static final String TAG = "LwsCloudSync";

    private LwsCloudSyncLog() {
    }

    public static void i(String where, String msg) {
        Log.i(TAG, where + " | " + msg);
    }

    public static void w(String where, String msg) {
        Log.w(TAG, where + " | " + msg);
    }

    public static void w(String where, String msg, Throwable t) {
        Log.w(TAG, where + " | " + msg, t);
    }

    public static void e(String where, String msg, Throwable t) {
        Log.e(TAG, where + " | " + msg, t);
    }
}
