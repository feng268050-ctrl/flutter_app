package com.lasercyber.lws.ui.component.holder;

import android.Manifest;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;

import androidx.annotation.RequiresPermission;
import androidx.core.app.ActivityCompat;

/**
 * 极简蓝牙连接状态监听器：仅判断“已连接蓝牙/未连接蓝牙”
 */
public class SimpleBluetoothConnectReceiver extends BroadcastReceiver {
    // 核心回调：仅返回是否有蓝牙设备已连接
    public interface OnBluetoothConnectChangeListener {
        void onBluetoothConnectStateChanged(boolean isConnected);
    }

    private OnBluetoothConnectChangeListener listener;
    private boolean isBluetoothConnected = false; // 缓存当前连接状态

    public SimpleBluetoothConnectReceiver(OnBluetoothConnectChangeListener listener) {
        this.listener = listener;
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        if (action == null) return;

        // 1. 监听蓝牙设备连接成功
        if (BluetoothDevice.ACTION_ACL_CONNECTED.equals(action)) {
            isBluetoothConnected = true;
            notifyStateChange();
        }
        // 2. 监听蓝牙设备断开连接
        else if (BluetoothDevice.ACTION_ACL_DISCONNECTED.equals(action)) {
            isBluetoothConnected = false;
            notifyStateChange();
        }
        // 3. 监听蓝牙开关关闭（此时必然未连接）
        else if (BluetoothAdapter.ACTION_STATE_CHANGED.equals(action)) {
            int bluetoothState = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR);
            if (bluetoothState == BluetoothAdapter.STATE_OFF) {
                isBluetoothConnected = false;
                notifyStateChange();
            }
        }
    }

    /**
     * 通知上层状态变化（仅已连接/未连接）
     */
    private void notifyStateChange() {
        if (listener != null) {
            listener.onBluetoothConnectStateChanged(isBluetoothConnected);
        }
    }

    /**
     * 主动获取当前蓝牙连接状态（初始化时调用，避免首次无回调）
     */
    public boolean getCurrentBluetoothState(Context context) {
        BluetoothAdapter bluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
        // 蓝牙开关关闭 → 未连接
        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled()) {
            isBluetoothConnected = false;
            return false;
        }

        if (ActivityCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {}
        for (BluetoothDevice device : bluetoothAdapter.getBondedDevices()) {
            int state = device.getBondState();
            if (state == BluetoothDevice.BOND_BONDED && isDeviceConnected(device)) {
                isBluetoothConnected = true;
                return true;
            }
        }
        isBluetoothConnected = false;
        return false;
    }

    /**
     * 低版本判断设备是否已连接（反射方式，兼容不同厂商）
     */
    private boolean isDeviceConnected(BluetoothDevice device) {
        try {
            // 反射调用BluetoothDevice的isConnected方法（隐藏API，低版本可用）
            return (boolean) device.getClass().getMethod("isConnected").invoke(device);
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }
}
