package com.lasercyber.lws.ui.common.modbus.monitor;

import android.util.Log;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

/**
 * 崩溃监控工具类
 */
public class CrashMonitor {
    private static final String TAG = LogTAGConstant.CrashMonitor;
    private static CrashMonitor instance;
    private OnCrashListener listener;

    public interface OnCrashListener {
        void onCrash(Throwable throwable);
    }

    private CrashMonitor() {
        // 注册全局异常捕获
        Thread.setDefaultUncaughtExceptionHandler((thread, throwable) -> {
            Log.e(TAG, "Uncaught exception in thread: " + thread.getName(), throwable);
            if (listener != null) {
                listener.onCrash(throwable);
            }
        });
    }

    /**
     * 获取示例
     * @return
     */
    public static CrashMonitor getInstance() {
        if (instance == null) {
            synchronized (CrashMonitor.class) {
                if (instance == null) {
                    instance = new CrashMonitor();
                }
            }
        }
        return instance;
    }

    public void setOnCrashListener(OnCrashListener listener) {
        this.listener = listener;
    }

    // 主动上报异常
    public void reportException(Throwable throwable) {
        Log.e(TAG, "Reported exception", throwable);
        if (listener != null) {
            listener.onCrash(throwable);
        }
    }
}
