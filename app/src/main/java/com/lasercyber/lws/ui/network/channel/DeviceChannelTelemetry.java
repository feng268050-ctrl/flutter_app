package com.lasercyber.lws.ui.network.channel;

import android.util.Log;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

public final class DeviceChannelTelemetry {
    private static final String TAG = LogTAGConstant.DEVICE_DATA_CHANNEL;

    private DeviceChannelTelemetry() {
    }

    public static void logDataPath(DeviceDataEvent event, String result, long latencyMs) {
        Log.d(TAG, "device_data_channel result=" + result
                + ",deviceId=" + event.getDeviceId()
                + ",correlationId=" + event.getCorrelationId()
                + ",protocol=" + event.getSourceProtocol()
                + ",latencyMs=" + latencyMs);
    }

    public static void logCommandPath(DeviceCommandRequest request, DeviceCommandResult result, boolean fallback) {
        Log.d(TAG, "device_command_channel status=" + result.getStatus()
                + ",deviceId=" + request.getDeviceId()
                + ",correlationId=" + request.getCorrelationId()
                + ",protocol=" + result.getProtocol()
                + ",fallback=" + fallback
                + ",errorCode=" + result.getErrorCode());
    }
}
