package com.lasercyber.lws.ui.common.utils;

import android.content.Context;
import android.provider.Settings;
import android.util.Log;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

/**
 * Enables network ADB (adb connect host:5555) on embedded Innohi boards.
 */
public final class AdbRemoteDebugHelper {

    private static final String TAG = LogTAGConstant.DeviceInformationFragment;

    public static final int DEFAULT_TCP_PORT = 5555;

    private AdbRemoteDebugHelper() {
    }

    /**
     * Turns on USB debugging and listens on {@link #DEFAULT_TCP_PORT} for {@code adb connect}.
     */
    public static boolean enableRemoteDebugging(Context context) {
        if (context == null) {
            return false;
        }
        Context app = context.getApplicationContext();
        try {
            boolean adbEnabled = Settings.Global.putInt(
                    app.getContentResolver(),
                    Settings.Global.ADB_ENABLED,
                    1);
            String port = String.valueOf(DEFAULT_TCP_PORT);
            ShellCmdUtil.executeCmdAsRoot("setprop service.adb.tcp.port " + port);
            ShellCmdUtil.executeCmdAsRoot("setprop persist.adb.tcp.port " + port);
            ShellCmdUtil.executeCmdAsRoot("stop adbd");
            ShellCmdUtil.executeCmdAsRoot("start adbd");
            Log.i(TAG, "ADB remote debugging enabled on tcp port " + port + ", adbEnabled=" + adbEnabled);
            return adbEnabled;
        } catch (Exception exception) {
            Log.e(TAG, "enableRemoteDebugging failed", exception);
            return false;
        }
    }
}
