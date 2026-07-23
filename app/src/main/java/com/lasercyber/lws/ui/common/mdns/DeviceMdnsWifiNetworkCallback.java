package com.lasercyber.lws.ui.common.mdns;

import android.net.ConnectivityManager;
import android.net.Network;
import android.util.Log;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

/**
 * Drives mDNS strictly from Wi-Fi link state, without requiring validated internet.
 * <p>
 * The app-wide {@link com.lasercyber.lws.ui.common.call.NetworkCallback} is built with
 * {@link android.net.NetworkCapabilities#NET_CAPABILITY_INTERNET}, so isolated LANs or
 * captive-portal Wi-Fi may never notify that path. Local service discovery must still work.
 */
public final class DeviceMdnsWifiNetworkCallback extends ConnectivityManager.NetworkCallback {
    private static final String TAG = LogTAGConstant.DEVICE_MDNS;

    @Override
    public void onAvailable(Network network) {
        Log.i(TAG, "mdns wifi onAvailable: " + network);
        DeviceMdnsAdvertiseManager.getInstance().setActiveWifiNetwork(network);
        DeviceMdnsAdvertiseManager.getInstance().onNetworkAvailable();
    }

    @Override
    public void onLost(Network network) {
        Log.i(TAG, "mdns wifi onLost: " + network);
        DeviceMdnsAdvertiseManager.getInstance().setActiveWifiNetwork(null);
        DeviceMdnsAdvertiseManager.getInstance().onNetworkLost();
    }
}
