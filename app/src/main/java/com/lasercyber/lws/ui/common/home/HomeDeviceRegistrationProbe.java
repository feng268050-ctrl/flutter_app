package com.lasercyber.lws.ui.common.home;

import androidx.annotation.NonNull;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ui.MainActivity;
import com.lasercyber.lws.ui.common.config.AppRuntimeEnvironment;
import com.lasercyber.lws.ui.common.device.DeviceIdentity;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.WifiStatusUtils;
import com.lasercyber.lws.ui.network.http.DeviceWorkerUsersClient;

import java.util.ArrayList;
import java.util.List;

/**
 * One-per-process probe for whether the device has bound users on the Worker API.
 * Shared by {@link BindDeviceHomePrompt} and {@link AutoOtaUpdateHomePrompt}.
 */
public final class HomeDeviceRegistrationProbe {

    public enum State {
        IDLE,
        LOADING,
        NEED_BIND,
        SKIP,
        FAILED
    }

    private static volatile State state = State.IDLE;
    private static volatile boolean bindPromptDismissedThisSession;
    private static final List<Runnable> pendingPreparedCallbacks = new ArrayList<>();

    private HomeDeviceRegistrationProbe() {
    }

    @NonNull
    public static State getState() {
        return state;
    }

    public static boolean isBindGateCleared() {
        return state == State.SKIP
                || state == State.FAILED
                || (state == State.NEED_BIND && bindPromptDismissedThisSession);
    }

    public static void onBindPromptDismissed() {
        bindPromptDismissedThisSession = true;
    }

    public static void ensurePrepared(@NonNull MainActivity activity, @NonNull Runnable onPrepared) {
        if (!AppRuntimeEnvironment.isWifiInitializationCompleted()
                || !WifiStatusUtils.hasUsableWifiConnection(activity.getApplicationContext())) {
            activity.runOnUiThread(onPrepared);
            return;
        }
        if (state == State.SKIP || state == State.FAILED || state == State.NEED_BIND) {
            activity.runOnUiThread(onPrepared);
            return;
        }
        synchronized (HomeDeviceRegistrationProbe.class) {
            pendingPreparedCallbacks.add(onPrepared);
            if (state == State.LOADING) {
                return;
            }
            state = State.LOADING;
        }
        String sn = DeviceIdentity.getDeviceSnSafely();
        ThreadPoolManager.getExecutor().execute(() -> {
            DeviceWorkerUsersClient.Outcome outcome = DeviceWorkerUsersClient.fetchDeviceUsers(sn);
            synchronized (HomeDeviceRegistrationProbe.class) {
                if (!outcome.isOk()) {
                    state = State.FAILED;
                } else if (outcome.getUsers() != null && !outcome.getUsers().isEmpty()) {
                    state = State.SKIP;
                } else {
                    state = State.NEED_BIND;
                }
                List<Runnable> callbacks = new ArrayList<>(pendingPreparedCallbacks);
                pendingPreparedCallbacks.clear();
                activity.runOnUiThread(() -> {
                    for (Runnable callback : callbacks) {
                        callback.run();
                    }
                });
            }
        });
    }

    @VisibleForTesting
    public static void resetForTest() {
        synchronized (HomeDeviceRegistrationProbe.class) {
            state = State.IDLE;
            bindPromptDismissedThisSession = false;
            pendingPreparedCallbacks.clear();
        }
    }

    @VisibleForTesting
    public static void setStateForTest(@NonNull State probeState, boolean bindDismissed) {
        synchronized (HomeDeviceRegistrationProbe.class) {
            state = probeState;
            bindPromptDismissedThisSession = bindDismissed;
            pendingPreparedCallbacks.clear();
        }
    }
}
