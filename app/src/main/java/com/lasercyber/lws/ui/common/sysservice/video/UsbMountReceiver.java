package com.lasercyber.lws.ui.common.sysservice.video;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;

public class UsbMountReceiver extends BroadcastReceiver {
    private OnUsbStateChangeListener listener;

    public UsbMountReceiver(OnUsbStateChangeListener listener) {
        this.listener = listener;
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        if (Intent.ACTION_MEDIA_MOUNTED.equals(action)) {
            // U 盘已挂载
            String usbPath = intent.getDataString().replace("file://", "");
            if (listener != null) {
                listener.onUsbMounted(usbPath);
            }
        } else if (Intent.ACTION_MEDIA_UNMOUNTED.equals(action)
                || Intent.ACTION_MEDIA_REMOVED.equals(action)) {
            // U 盘已卸载
            if (listener != null) {
                listener.onUsbUnmounted();
            }
        }
    }

    // 注册广播
    public void register(Context context) {
        IntentFilter filter = new IntentFilter();
        filter.addAction(Intent.ACTION_MEDIA_MOUNTED);
        filter.addAction(Intent.ACTION_MEDIA_UNMOUNTED);
        filter.addAction(Intent.ACTION_MEDIA_REMOVED);
        filter.addDataScheme("file"); // 必须添加，否则无法接收存储事件
        context.registerReceiver(this, filter);
    }

    // 注销广播
    public void unregister(Context context) {
        context.unregisterReceiver(this);
    }

    // U 盘状态变化回调
    public interface OnUsbStateChangeListener {
        void onUsbMounted(String usbPath); // U 盘挂载
        void onUsbUnmounted(); // U 盘卸载
    }
}
