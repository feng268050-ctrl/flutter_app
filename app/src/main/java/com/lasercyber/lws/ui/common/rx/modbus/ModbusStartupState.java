package com.lasercyber.lws.ui.common.rx.modbus;

import android.util.Log;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

/**
 * Tracks Modbus availability during app startup.
 * This allows emulator/device capability differences to degrade gracefully.
 */
public final class ModbusStartupState {
    private static final String TAG = LogTAGConstant.ModbusManagerRtu;

    public static final String REASON_NONE = "NONE";
    public static final String REASON_EMULATOR_UNSUPPORTED = "EMULATOR_UNSUPPORTED";
    public static final String REASON_SERIAL_PORT_MISSING = "SERIAL_PORT_MISSING";
    public static final String REASON_INIT_FAILED = "INIT_FAILED";
    public static final String REASON_UNEXPECTED_ERROR = "UNEXPECTED_ERROR";

    private static volatile boolean available = true;
    private static volatile String reasonCode = REASON_NONE;
    private static volatile String reasonMessage = "";

    private ModbusStartupState() {
    }

    public static void markAvailable() {
        available = true;
        reasonCode = REASON_NONE;
        reasonMessage = "";
        Log.i(TAG, "Modbus startup state -> AVAILABLE");
    }

    public static void markUnavailable(String code, String message, Throwable throwable) {
        available = false;
        reasonCode = code == null ? REASON_UNEXPECTED_ERROR : code;
        reasonMessage = message == null ? "" : message;
        if (throwable == null) {
            Log.w(TAG, "Modbus startup state -> UNAVAILABLE, code=" + reasonCode + ", message=" + reasonMessage);
        } else {
            Log.e(TAG, "Modbus startup state -> UNAVAILABLE, code=" + reasonCode + ", message=" + reasonMessage, throwable);
        }
    }

    public static boolean isAvailable() {
        return available;
    }

    public static String getReasonCode() {
        return reasonCode;
    }

    public static String getReasonMessage() {
        return reasonMessage;
    }
}
