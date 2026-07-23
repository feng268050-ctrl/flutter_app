package com.lasercyber.lws.ui.common.device;

import android.util.Log;

import com.innohi.YNHAPI;
import com.lasercyber.lws.ui.common.config.DeviceModelConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

/**
 * Device identity access independent of transport protocol.
 * <p>
 * Device SN resolution order:
 * <ol>
 *     <li>{@link YNHAPI} serial (real device)</li>
 *     <li>If unavailable or empty, {@code sn} key in {@code /system/etc/model.properties}
 *     (injected by {@code make emulator} via the {@code SN} env var)</li>
 *     <li>Otherwise {@link #UNKNOWN_SN}</li>
 * </ol>
 */
public final class DeviceIdentity {
    private static final String TAG = LogTAGConstant.APPLICATION;
    public static final String UNKNOWN_SN = "unknown-sn";

    private DeviceIdentity() {
    }

    public static String getDeviceSnSafely() {
        try {
            String serialNo = YNHAPI.getInstance().getSerialNo();
            if (serialNo != null && !serialNo.trim().isEmpty()) {
                return serialNo.trim();
            }
        } catch (Throwable ignored) {
            // 不在此处打 YNHAPI 异常日志；最终使用注入 SN 或 unknown-sn 时再记录。
        }

        String sn = DeviceModelConfig.getSn();
        if (sn != null) {
            Log.i(TAG, "设备 SN：使用 model.properties 注入（sn），YNHAPI 无有效序列号");
            return sn;
        }
        Log.i(TAG, "设备 SN：使用未知标识（unknown-sn），YNHAPI 无有效序列号且 model.properties 未配置 sn");
        return UNKNOWN_SN;
    }

}
