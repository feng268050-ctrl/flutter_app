package com.lasercyber.lws.ui.network;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkRequest;
import android.os.Build;

public class NetworkMonitor {
    private static ConnectivityManager.NetworkCallback networkCallback;

    // 注册网络监听
    public static void register(Context context, OnNetworkChangedListener listener) {
        ConnectivityManager cm = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        if (cm == null) return;

        // 移除旧的监听（避免重复注册）
        if (networkCallback != null) {
            cm.unregisterNetworkCallback(networkCallback);
        }

        // 创建网络回调
        networkCallback = new ConnectivityManager.NetworkCallback() {
            @Override
            public void onAvailable(Network network) {
                super.onAvailable(network);
                listener.onNetworkChanged(true); // 网络可用
            }

            @Override
            public void onLost(Network network) {
                super.onLost(network);
                listener.onNetworkChanged(false); // 网络不可用
            }
        };

        // 注册网络监听（Android 7.0+ 推荐方式）
        NetworkRequest request = new NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .addTransportType(NetworkCapabilities.TRANSPORT_CELLULAR)
                .build();
        cm.registerNetworkCallback(request, networkCallback);
    }

    // 取消网络监听
    public static void unregister(Context context) {
        if (networkCallback == null) return;
        ConnectivityManager cm = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        if (cm != null) {
            cm.unregisterNetworkCallback(networkCallback);
        }
        networkCallback = null;
    }

    // 检查当前网络是否可用
    public static boolean isNetworkAvailable(Context context) {
        ConnectivityManager cm = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        if (cm == null) return false;

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            Network network = cm.getActiveNetwork();
            if (network == null) return false;
            NetworkCapabilities capabilities = cm.getNetworkCapabilities(network);
            return capabilities != null && capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET);
        } else {
            // 兼容旧版本
            NetworkCapabilities capabilities = cm.getNetworkCapabilities(cm.getActiveNetwork());
            return capabilities != null && capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET);
        }
    }

    // 网络变化监听器
    public interface OnNetworkChangedListener {
        void onNetworkChanged(boolean isAvailable);
    }
}
