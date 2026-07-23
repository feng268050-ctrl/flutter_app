package com.lasercyber.lws.ui.common.constant;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.os.Handler;
import android.os.Looper;

import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.SystemSettingUtils;

import org.apache.commons.net.ntp.NTPUDPClient;
import org.apache.commons.net.ntp.TimeInfo;

import java.net.InetAddress;
import java.util.concurrent.CopyOnWriteArraySet;

public class TimeGlobalManager {

    private static TimeGlobalManager instance;
    private long currentTime; // 毫秒级时间，始终跟随系统时间
    private final CopyOnWriteArraySet<TimeUpdateListener> listeners = new CopyOnWriteArraySet<>();
    private Handler mainHandler = new Handler(Looper.getMainLooper());
    private Runnable timeTicker = new Runnable() {
        @Override
        public void run() {
            currentTime = System.currentTimeMillis();
            notifyListeners(currentTime);
            mainHandler.postDelayed(this, 1000);
        }
    };

    // 单例初始化
    public static TimeGlobalManager getInstance() {
        if (instance == null) {
            synchronized (TimeGlobalManager.class) {
                if (instance == null) {
                    instance = new TimeGlobalManager();
                }
            }
        }
        return instance;
    }

    private TimeGlobalManager() {
        currentTime = System.currentTimeMillis(); // 初始取系统时间
        mainHandler.post(timeTicker); // 启动每秒更新
    }

    private void notifyListeners(long time) {
        for (TimeUpdateListener listener : listeners) {
            listener.onTimeUpdated(time);
        }
    }

    // 1. WiFi下自动校时
    public void syncTimeWithWifi(Context context) {
        // 检查WiFi是否连接
        ConnectivityManager connMgr = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        NetworkInfo wifiNetwork = connMgr.getNetworkInfo(ConnectivityManager.TYPE_WIFI);
        if (wifiNetwork == null || !wifiNetwork.isConnected()) {
            return;
        }

        // 异步请求NTP服务器
        ThreadPoolManager.getExecutor().execute(() -> {
            try {
                NTPUDPClient ntpClient = new NTPUDPClient();
                ntpClient.setDefaultTimeout(5000);
                InetAddress ntpServer = InetAddress.getByName("pool.ntp.org");
                TimeInfo timeInfo = ntpClient.getTime(ntpServer);
                long networkTime = timeInfo.getMessage().getTransmitTimeStamp().getTime();
                // Use system update path first so all UI surfaces stay consistent.
                SystemSettingUtils.setDateAndTimeMillis(context, networkTime);
                currentTime = System.currentTimeMillis();
                mainHandler.post(() -> notifyListeners(currentTime));
            } catch (Exception e) {
                e.printStackTrace();
            }
        });
    }

    // 2. 手动设置时间
    public void setCustomTime(long customTime) {
        SystemSettingUtils.setDateAndTimeMillis(com.blankj.utilcode.util.Utils.getApp(), customTime);
        currentTime = System.currentTimeMillis();
        notifyListeners(currentTime);
    }

    public void addTimeUpdateListener(TimeUpdateListener listener) {
        if (listener == null) {
            return;
        }
        listeners.add(listener);
        listener.onTimeUpdated(System.currentTimeMillis());
    }

    public void removeTimeUpdateListener(TimeUpdateListener listener) {
        if (listener != null) {
            listeners.remove(listener);
        }
    }

    // 注册时间更新监听器（兼容单监听调用方；可多次注册不同实例）
    public void setTimeUpdateListener(TimeUpdateListener listener) {
        addTimeUpdateListener(listener);
    }

    // 获取当前时间
    public long getCurrentTime() {
        return currentTime;
    }

    // 时间更新回调接口
    public interface TimeUpdateListener {
        void onTimeUpdated(long currentTime);
    }
}
