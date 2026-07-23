package com.lasercyber.lws.ui.common.upgrade;

import android.util.Log;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.network.ws.DeviceWebSocketConnectionManager;

/**
 * Serializes {@code device.update_progress} sends with a minimum wall-clock gap so upstream
 * coordinators are less likely to drop bursts. Mandatory sends retry until WS accepts or attempts exhaust.
 */
public final class OtaWsProgressOutbound {

    private static final String TAG = LogTAGConstant.UpgradeActivity;
    public static final long MIN_INTER_SEND_GAP_MS = 150L;
    private static final int MANDATORY_MAX_ATTEMPTS = 15;
    private static final long MANDATORY_RETRY_MS = 50L;

    private final Object sendLock = new Object();
    private final OtaStageProgressDeduper delivered = new OtaStageProgressDeduper();
    private long lastSendWallMs;

    /** Clears per-stage delivery memory at the start of a new OTA session. */
    public void resetSession() {
        synchronized (sendLock) {
            delivered.reset();
            lastSendWallMs = 0L;
        }
    }

    /**
     * @return {@code true} if the frame was accepted by the local WS layer
     */
    public boolean trySend(
            @Nullable String stage,
            int progress,
            @Nullable String status,
            @Nullable String message,
            @Nullable String errorCode
    ) {
        synchronized (sendLock) {
            long now = System.currentTimeMillis();
            if (now - lastSendWallMs < MIN_INTER_SEND_GAP_MS) {
                return false;
            }
            return sendNowLocked(stage, progress, status, message, errorCode);
        }
    }

    /**
     * Retries across short sleeps (safe from a background thread; caller may also invoke on main).
     */
    public boolean sendMandatory(
            @Nullable String stage,
            int progress,
            @Nullable String status,
            @Nullable String message,
            @Nullable String errorCode
    ) {
        for (int attempt = 0; attempt < MANDATORY_MAX_ATTEMPTS; attempt++) {
            synchronized (sendLock) {
                if (sendNowLocked(stage, progress, status, message, errorCode)) {
                    return true;
                }
            }
            if (attempt + 1 < MANDATORY_MAX_ATTEMPTS) {
                try {
                    Thread.sleep(MANDATORY_RETRY_MS);
                } catch (InterruptedException ex) {
                    Thread.currentThread().interrupt();
                    return false;
                }
            }
        }
        Log.w(TAG, "OTA WS progress mandatory send failed stage=" + stage + " progress=" + progress
                + " status=" + status);
        return false;
    }

    /** Caller must hold {@link #sendLock}. */
    private boolean sendNowLocked(
            @Nullable String stage,
            int progress,
            @Nullable String status,
            @Nullable String message,
            @Nullable String errorCode
    ) {
        if (stage == null || status == null) {
            return false;
        }
        if (delivered.alreadyDelivered(stage, progress)) {
            return true;
        }
        boolean sent = DeviceWebSocketConnectionManager.getInstance().sendDeviceUpdateProgress(
                stage,
                progress,
                status,
                message,
                errorCode
        );
        if (sent) {
            delivered.markDelivered(stage, progress);
            lastSendWallMs = System.currentTimeMillis();
            Log.i(TAG, "OTA WS progress sent stage=" + stage + " progress=" + progress + " status=" + status);
        }
        return sent;
    }
}
