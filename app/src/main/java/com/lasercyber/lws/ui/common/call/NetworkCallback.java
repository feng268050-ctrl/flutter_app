package com.lasercyber.lws.ui.common.call;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.os.SystemClock;
import android.util.Log;

import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.common.config.DeviceApiOriginConfig;
import com.lasercyber.lws.ui.common.config.DeviceApiOriginProber;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.LwsCloudSyncLog;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.network.ws.DeviceWebSocketConnectionManager;

/**
 * 网络变化回调
 */
public class NetworkCallback extends ConnectivityManager.NetworkCallback {

    private static final String TAG = LogTAGConstant.NetworkCallback;
    /** System may deliver duplicate onAvailable bursts; throttle duplicate log lines only (probe still runs). */
    private static final long ON_AVAILABLE_LOG_THROTTLE_MS = 400L;
    private static long lastOnAvailableLogMs;

    @Override
    public void onAvailable(Network network) {
        super.onAvailable(network);
        try {
            long now = SystemClock.elapsedRealtime();
            if (now - lastOnAvailableLogMs >= ON_AVAILABLE_LOG_THROTTLE_MS) {
                lastOnAvailableLogMs = now;
                Log.i(TAG, "network onAvailable: schedule debounced API origin probe + ws bootstrap");
                LwsCloudSyncLog.i("NetCb", "onAvailable -> debounced API origin probe + ws");
            }
            // mDNS is driven by DeviceMdnsWifiNetworkCallback (Wi-Fi without requiring validated internet).
            DeviceApiOriginProber.probeWhenNetworkAvailable(network, () -> {
                try {
                    DeviceWebSocketConnectionManager.getInstance().connectOrReconnect("network_available");
                } catch (Throwable inner) {
                    Log.e(TAG, "onAvailable runtime guard: ws bootstrap skipped", inner);
                }
            });
        } catch (Throwable throwable) {
            Log.e(TAG, "onAvailable runtime guard: ws bootstrap skipped", throwable);
        }
    }

    @Override
    public void onLost(Network network) {
        super.onLost(network);
        Log.d(TAG, "网络丢失");
        // Default route may switch (e.g. Wi‑Fi → cellular); wait briefly then re-check before clearing pin.
        ThreadPoolManager.getExecutor().execute(() -> {
            try {
                Thread.sleep(120L);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return;
            }
            Context app = Utils.getApp();
            if (app == null) {
                return;
            }
            ConnectivityManager cm = (ConnectivityManager) app.getSystemService(Context.CONNECTIVITY_SERVICE);
            if (cm == null) {
                DeviceApiOriginConfig.clearPinnedBase();
                LwsCloudSyncLog.i("NetCb", "onLost: ConnectivityManager null, cleared pinned API base");
                disconnectWsSafe("network_lost_cm_null");
                return;
            }
            Network active = cm.getActiveNetwork();
            if (!hasInternet(cm, active)) {
                DeviceApiOriginConfig.clearPinnedBase();
                LwsCloudSyncLog.i("NetCb", "onLost: no internet-capable default network, cleared pinned API base");
                disconnectWsSafe("network_lost_no_default_internet");
            } else {
                LwsCloudSyncLog.i("NetCb", "onLost: default network still internet-capable, keep pinned API base");
            }
        });
    }

    private static boolean hasInternet(ConnectivityManager cm, Network n) {
        if (n == null) {
            return false;
        }
        NetworkCapabilities caps = cm.getNetworkCapabilities(n);
        return caps != null && caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET);
    }

    private static void disconnectWsSafe(String reason) {
        try {
            DeviceWebSocketConnectionManager.getInstance().disconnect(reason);
        } catch (Throwable t) {
            Log.w(TAG, "onLost: ws disconnect skipped", t);
        }
    }

    @Override
    public void onCapabilitiesChanged(Network network, NetworkCapabilities networkCapabilities) {
        super.onCapabilitiesChanged(network, networkCapabilities);
        Log.d(TAG, "网络类型变化");
    }
}
