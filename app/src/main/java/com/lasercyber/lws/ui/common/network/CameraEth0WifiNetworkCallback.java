package com.lasercyber.lws.ui.common.network;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.LinkProperties;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.os.SystemClock;
import android.util.Log;

import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.bean.entity.dto.ConnectedWifiInfo;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.SystemSettingUtils;
import com.lasercyber.lws.ui.common.utils.WifiStatusUtils;

import androidx.annotation.Nullable;

import java.util.Objects;

/**
 * Re-applies camera {@code eth0} addressing when Wi-Fi link or DHCP address changes, so
 * {@code eth0} stays off the current {@code wlan0} IPv4.
 */
public final class CameraEth0WifiNetworkCallback extends ConnectivityManager.NetworkCallback {
    private static final String TAG = LogTAGConstant.SystemSettingUtils;
    private static final long REFRESH_DEBOUNCE_MS = 600L;
    /** Allow Wi-Fi stack to settle after disconnect before re-routing camera LAN. */
    private static final long WIFI_LOST_DELAY_MS = 1500L;

    private static volatile String lastAppliedForWlanIp;
    private static volatile long lastRefreshRequestMs;

    /** Called after a successful explicit {@code eth0} configure to avoid duplicate Wi-Fi callbacks. */
    public static void noteWlanIpAtConfigure(@Nullable String wlanIp) {
        lastAppliedForWlanIp = wlanIp;
    }

    @Override
    public void onAvailable(Network network) {
        scheduleRefresh("wifi_available");
    }

    @Override
    public void onLost(Network network) {
        lastAppliedForWlanIp = null;
        scheduleRefresh("wifi_lost");
    }

    @Override
    public void onCapabilitiesChanged(Network network, NetworkCapabilities networkCapabilities) {
        if (networkCapabilities != null
                && networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
            scheduleRefresh("wifi_capabilities");
        }
    }

    @Override
    public void onLinkPropertiesChanged(Network network, LinkProperties linkProperties) {
        scheduleRefresh("wifi_link_properties");
    }

    private static void scheduleRefresh(String reason) {
        long now = SystemClock.elapsedRealtime();
        if (now - lastRefreshRequestMs < REFRESH_DEBOUNCE_MS) {
            return;
        }
        lastRefreshRequestMs = now;
        long delayMs = "wifi_lost".equals(reason) ? WIFI_LOST_DELAY_MS : 0L;
        ThreadPoolManager.getExecutor().execute(() -> {
            if (delayMs > 0L) {
                try {
                    Thread.sleep(delayMs);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    return;
                }
            }
            applyIfNeeded(reason);
        });
    }

    private static void applyIfNeeded(String reason) {
        Context app = Utils.getApp();
        if (app == null) {
            return;
        }
        ConnectedWifiInfo wifi = WifiStatusUtils.getConnectedWifiInfo(app);
        String wlanIp = wifi == null ? null : wifi.getIpAddress();
        boolean force = "wifi_lost".equals(reason);
        if (!force && Objects.equals(wlanIp, lastAppliedForWlanIp)) {
            return;
        }
        lastAppliedForWlanIp = wlanIp;
        Log.i(TAG, "eth0 refresh (" + reason + ") wlanIp=" + wlanIp);
        SystemSettingUtils.setCameraNetworkSegment(app);
    }
}
