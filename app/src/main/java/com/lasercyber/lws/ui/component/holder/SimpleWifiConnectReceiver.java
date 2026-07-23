package com.lasercyber.lws.ui.component.holder;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkInfo;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.util.Log;

import com.lasercyber.lws.ui.common.constant.TimeGlobalManager;

/**
 * 极简WiFi连接状态监听器：仅判断已连接/未连接WiFi
 */
public class SimpleWifiConnectReceiver extends BroadcastReceiver {

    private volatile boolean isWifiInit = false;

    // 核心回调接口：仅返回“是否连接WiFi”
    public interface OnWifiConnectChangeListener {
        void onWifiConnectStateChanged(boolean isConnected,Integer level);
    }

    private OnWifiConnectChangeListener listener;

    public SimpleWifiConnectReceiver(OnWifiConnectChangeListener listener) {
        this.listener = listener;
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        try {
            // 仅处理网络连接状态变化广播
            if (!ConnectivityManager.CONNECTIVITY_ACTION.equals(intent.getAction())) {
                return;
            }

            // 核心逻辑：判断当前是否连接WiFi
            boolean isWifiConnected = isWifiConnected(context);

            if( isWifiConnected && !this.isWifiInit ){
                this.isWifiInit = true;
                ConnectivityManager cm = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
                Network network = cm.getActiveNetwork();
                if (network != null) {
                    cm.bindProcessToNetwork(network);
                }
              }else{
                this.isWifiInit = false;
            }

            WifiManager wifiManager = (WifiManager) context.getApplicationContext()
                    .getSystemService(Context.WIFI_SERVICE);
            WifiInfo wifiInfo = wifiManager.getConnectionInfo();

            int level = WifiManager.calculateSignalLevel(wifiInfo.getRssi(), 5);

            // 回调状态（仅已连接/未连接）
            if (listener != null) {
                listener.onWifiConnectStateChanged(isWifiConnected, level);
            }
        } catch (Exception e) {
            Log.d("SimpleWifiConnectReceiver", "判断WiFi连接失败", e);
        }
    }

    /**
     * 核心判断方法：仅返回“是否连接WiFi”
     */
    private boolean isWifiConnected(Context context) {
        ConnectivityManager cm = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        if (cm == null) return false;

        TimeGlobalManager.getInstance().syncTimeWithWifi(context);
        // Android 10+ 新API（推荐）
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return cm.getActiveNetwork() != null
                    && cm.getNetworkCapabilities(cm.getActiveNetwork())
                    .hasTransport(NetworkCapabilities.TRANSPORT_WIFI);
        }
        // 低版本旧API（兼容）WifiInfo wifiInfo = wifiManager.getConnectionInfo();
        else {
            NetworkInfo wifiInfo = cm.getNetworkInfo(ConnectivityManager.TYPE_WIFI);
            return wifiInfo != null && wifiInfo.isConnected();
        }
    }
}