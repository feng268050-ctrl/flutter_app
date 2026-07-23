package com.lasercyber.lws.ui.activitys.setting.fragment;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkRequest;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.View;

import androidx.core.app.ActivityCompat;
import androidx.fragment.app.Fragment;

import com.blankj.utilcode.util.PermissionUtils;
import com.blankj.utilcode.util.StringUtils;
import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ui.BR;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseFragment;
import com.lasercyber.lws.ui.activitys.other.WifiActivity;
import com.lasercyber.lws.ui.activitys.setting.DeviceSettingActivity;
import com.lasercyber.lws.ui.bean.entity.NetworkSetting;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.utils.ClickLook;
import com.lasercyber.lws.ui.common.utils.SystemSettingUtils;
import com.lasercyber.lws.ui.common.utils.WifiStatusUtils;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.component.holder.SimpleBluetoothConnectReceiver;
import com.lasercyber.lws.ui.databinding.FragmentNetworkSettingBinding;

/**
 * A simple {@link Fragment} subclass.
 * create an instance of this fragment.
 * 网络设置
 */
public class NetworkSettingFragment extends BaseFragment<FragmentNetworkSettingBinding>
        implements SimpleBluetoothConnectReceiver.OnBluetoothConnectChangeListener{
    private static final String TAG = LogTAGConstant.NetworkSettingFragment;
    private static final long WIFI_PROBE_INTERVAL_MS = 5000L;
    private static final int WIFI_PROBE_MAX_TIMES = 6;
    private ConnectivityManager connectivityManager;
    private ConnectivityManager.NetworkCallback wifiNetworkCallback;
    private boolean isWifiNetworkCallbackRegistered = false;
    private final Handler wifiProbeHandler = new Handler(Looper.getMainLooper());
    private int wifiProbeCount = 0;
    private SimpleBluetoothConnectReceiver bluetoothReceiver;
    private ClickLook look = new ClickLook();
    private boolean suppressBluetoothSwitchCallback = false;

    private boolean init = false;
    // private FragmentNetworkSettingBinding binding;
    private NetworkSetting networkSetting;
    // 蓝牙权限数组（Android 12+ 需要 BLUETOOTH_CONNECT，低版本需要 BLUETOOTH 等）
    private static final String[] BLUETOOTH_PERMISSIONS = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
            ? new String[]{
            android.Manifest.permission.BLUETOOTH_CONNECT,
            android.Manifest.permission.BLUETOOTH_ADMIN
    }
            : new String[]{
            android.Manifest.permission.BLUETOOTH,
            android.Manifest.permission.BLUETOOTH_ADMIN
    };

    @Override
    protected int getLayoutId() {
        return R.layout.fragment_network_setting;
    }

    @Override
    protected void initView() {
        binding.bluetoothSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (suppressBluetoothSwitchCallback || !buttonView.isPressed()) {
                return;
            }
            if( init ){
                GlobalSoundManager.playClickSound();
            } else init = true;
            if ( !look.clickTime() ) return;
            BluetoothAdapter bluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
            if ( bluetoothAdapter == null ) {
                // 设备不支持蓝牙
                ToastUtils.showShort( R.string.bluetooth_not_supported_text );
                return;
            }
            // 先检查权限，在操作蓝牙
            checkAndRequestBluetoothPermission( isChecked );

        });

        binding.networkBorder.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if(!look.clickTime()) return;
                GlobalSoundManager.playClickSound();
                Intent intent = new Intent(getContext(), WifiActivity.class);
                startActivity(intent);
            }
        });
        maybeAutoOpenWirelessNetwork();
        //点击蓝牙名称，进行页面跳转
      /*  binding.bluetoothText.setOnClickListener((v)->{
            if(!look.clickTime()) return;
            GlobalSoundManager.playClickSound();
            Intent intent = new Intent(getContext(), BluetoothManagerActivity.class);
            startActivity(intent);
        });*/

    }

    private void maybeAutoOpenWirelessNetwork() {
        Activity activity = getActivity();
        if (activity == null || activity.getIntent() == null) {
            return;
        }
        boolean shouldOpen = activity.getIntent()
                .getBooleanExtra(DeviceSettingActivity.EXTRA_OPEN_WIRELESS_NETWORK, false);
        if (!shouldOpen) {
            return;
        }
        activity.getIntent().putExtra(DeviceSettingActivity.EXTRA_OPEN_WIRELESS_NETWORK, false);
        startActivity(new Intent(getContext(), WifiActivity.class));
    }

    @Override
    protected void initData() {
        registerWifiNetworkCallback();
        startWifiStabilityProbe();

        requestBluetoothPermission();
        // 3. 初始化蓝牙接收器
        bluetoothReceiver = new SimpleBluetoothConnectReceiver(this);

        // 4. 动态注册广播（必须动态注册，静态注册无效）
        IntentFilter bfilter = new IntentFilter();
        bfilter.addAction(BluetoothDevice.ACTION_ACL_CONNECTED); // 设备连接
        bfilter.addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED); // 设备断开
        bfilter.addAction(BluetoothAdapter.ACTION_STATE_CHANGED); // 蓝牙开关状态
        getContext().registerReceiver(bluetoothReceiver, bfilter);

        // 5.注册蓝牙可发现状态广播
        IntentFilter scanFilter = new IntentFilter(BluetoothAdapter.ACTION_SCAN_MODE_CHANGED);
        getContext().registerReceiver(mBluetoothDiscoverableReceiver, scanFilter);

        // 6. 主动获取当前蓝牙状态（避免首次无回调）
         bluetoothReceiver.getCurrentBluetoothState(getContext());

    }

    private void registerWifiNetworkCallback() {
        if (getContext() == null) {
            return;
        }
        connectivityManager = (ConnectivityManager) getContext().getSystemService(Context.CONNECTIVITY_SERVICE);
        if (connectivityManager == null) {
            return;
        }
        wifiNetworkCallback = new ConnectivityManager.NetworkCallback() {
            @Override
            public void onAvailable(Network network) {
                refreshWifiStatus();
            }

            @Override
            public void onLost(Network network) {
                refreshWifiStatus();
            }

            @Override
            public void onCapabilitiesChanged(Network network, NetworkCapabilities networkCapabilities) {
                refreshWifiStatus();
            }
        };
        try {
            NetworkRequest request = new NetworkRequest.Builder()
                    .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                    .build();
            connectivityManager.registerNetworkCallback(request, wifiNetworkCallback);
            isWifiNetworkCallbackRegistered = true;
        } catch (Exception exception) {
            Log.e(TAG, "注册wifi监听失败: ", exception);
        }
        refreshWifiStatus();
    }
    private void requestBluetoothPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (getContext().checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions((Activity) getContext(), new String[]{Manifest.permission.BLUETOOTH_CONNECT}, 1001);
            }
        }
    }

    @Override
    protected void bindViewModel() {
        super.bindViewModel();
        networkSetting = new NetworkSetting();
        applyWifiStatusToNetworkSetting();
        networkSetting.setNetwork4G(SystemSettingUtils.is4GConnected(getContext()));
        networkSetting.setBluetooth(SystemSettingUtils.isBluetoothEnabled());
        Log.d(TAG, "onCreateView: 获取到的网络状态:" + networkSetting);

        binding.setVariable(BR.networkSetting, networkSetting);
    }

    // 监听蓝牙可发现状态的广播接收器
    private final BroadcastReceiver mBluetoothDiscoverableReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            String action = intent.getAction();
            if (BluetoothAdapter.ACTION_SCAN_MODE_CHANGED.equals(action)) {
                int scanMode = intent.getIntExtra(BluetoothAdapter.EXTRA_SCAN_MODE, BluetoothAdapter.ERROR);
                switch (scanMode) {
                    // 可被发现且可连接
                    case BluetoothAdapter.SCAN_MODE_CONNECTABLE_DISCOVERABLE:
                        break;
                    // 可连接但不可发现
                    case BluetoothAdapter.SCAN_MODE_CONNECTABLE:
                        break;
                    // 不可连接也不可发现
                    case BluetoothAdapter.SCAN_MODE_NONE:
                        break;
                }
            }
        }
    };

    // 检查并申请蓝牙权限
    private void checkAndRequestBluetoothPermission(boolean isChecked) {
        // 1. 检查权限是否已授予
        if (PermissionUtils.isGranted(BLUETOOTH_PERMISSIONS)) {
            // 权限已授予，执行蓝牙操作（如打开蓝牙）
            openOrCloseBluetooth(isChecked);
        } else {
            // 2. 权限未授予，申请权限（Fragment 中使用自身的 requestPermissions 方法）
            PermissionUtils.permission(BLUETOOTH_PERMISSIONS).callback(new PermissionUtils.SimpleCallback() {
                @Override
                public void onGranted() {
                    openOrCloseBluetooth(isChecked);
                }

                @Override
                public void onDenied() {

                }
            });
        }
    }

    @SuppressLint("MissingPermission")
    @SuppressWarnings("deprecation")
    private void openOrCloseBluetooth(boolean isChecked) {
        BluetoothAdapter bluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
        if (bluetoothAdapter.isEnabled() == isChecked) {
            return;
        }
        boolean swicthCheckd = false;
        int bluetoothText;
        if (isChecked) {
            // 打开蓝牙
            boolean enable = bluetoothAdapter.enable();
            bluetoothText = R.string.bluetooth_open_failed_text;
            if (enable) {
                swicthCheckd = true;
                bluetoothText = R.string.bluetooth_opened_text;
            }
        } else {
            // 关闭蓝牙
            boolean disable = bluetoothAdapter.disable();
            bluetoothText = R.string.bluetooth_closed_text;
            if (!disable) {
                swicthCheckd = true;
                bluetoothText = R.string.bluetooth_close_failed_text;
            }
        }
        ToastUtils.showShort(bluetoothText);
        if(binding!=null){
            suppressBluetoothSwitchCallback = true;
            binding.bluetoothSwitch.setChecked(swicthCheckd);
            suppressBluetoothSwitchCallback = false;
        }
    }

    private void refreshWifiStatus() {
        if (getContext() == null || networkSetting == null) {
            return;
        }
        if (Looper.myLooper() != Looper.getMainLooper()) {
            wifiProbeHandler.post(this::refreshWifiStatus);
            return;
        }
        applyWifiStatusToNetworkSetting();
        networkSetting.setNetwork4G(SystemSettingUtils.is4GConnected(getContext()));
        Log.d(TAG, "onCreateView: 获取到的网络状态:" + networkSetting.toString());
        if (binding != null) {
            binding.setNetworkSetting(networkSetting);
            binding.executePendingBindings();
        }
        Log.i(TAG, "[wifi_probe] refresh, wifiName=" + networkSetting.getWifiName()
                + ", wifiConnected=" + networkSetting.isNetworkWIFI()
                + ", mobileConnected=" + networkSetting.isNetwork4G());
    }

    /**
     * WiFi 连接状态以 ConnectivityManager 为准（与 NetworkCallback 同步）；
     * SSID 在断开后会滞后清空，不能单独用来判断是否已连接。
     */
    private void applyWifiStatusToNetworkSetting() {
        boolean wifiConnected = WifiStatusUtils.isWifiConnected(getContext());
        networkSetting.setNetworkWIFI(wifiConnected);
        if (!wifiConnected) {
            networkSetting.setWifiName(getContext().getString(R.string.not_connecting_text));
            return;
        }
        String wifiName = SystemSettingUtils.getConnectedWifiName(getContext());
        if (StringUtils.isEmpty(wifiName) || "<unknown ssid>".equals(wifiName)) {
            networkSetting.setWifiName(getContext().getString(R.string.not_connecting_text));
        } else {
            networkSetting.setWifiName(wifiName);
        }
    }

    private void startWifiStabilityProbe() {
        wifiProbeCount = 0;
        wifiProbeHandler.removeCallbacksAndMessages(null);
        wifiProbeHandler.postDelayed(wifiProbeRunnable, WIFI_PROBE_INTERVAL_MS);
    }

    private final Runnable wifiProbeRunnable = new Runnable() {
        @Override
        public void run() {
            if (getContext() == null) {
                return;
            }
            String wifiName = SystemSettingUtils.getConnectedWifiName(getContext());
            boolean wifiConnected = !(StringUtils.isEmpty(wifiName) || "<unknown ssid>".equals(wifiName));
            Log.i(TAG, "[wifi_probe] t+" + ((wifiProbeCount + 1) * 5) + "s"
                    + ", wifiConnected=" + wifiConnected
                    + ", wifiName=" + wifiName);
            wifiProbeCount++;
            if (wifiProbeCount < WIFI_PROBE_MAX_TIMES) {
                wifiProbeHandler.postDelayed(this, WIFI_PROBE_INTERVAL_MS);
            }
        }
    };


    @Override
    public void onBluetoothConnectStateChanged(boolean isConnected) {
        if (networkSetting!=null){
            networkSetting.setBluetooth(SystemSettingUtils.isBluetoothEnabled());
            Log.d(TAG, "onCreateView: 获取到的蓝牙状态:" + networkSetting.toString());
        }
        if (binding!=null){
            binding.setNetworkSetting(networkSetting);
        }

    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();

        if (getContext() != null) {
            if (connectivityManager != null && wifiNetworkCallback != null && isWifiNetworkCallbackRegistered) {
                try {
                    connectivityManager.unregisterNetworkCallback(wifiNetworkCallback);
                    isWifiNetworkCallbackRegistered = false;
                } catch (Exception exception) {
                    Log.e(TAG, "回收wifi异常: ", exception);
                }
            }
            try {
                getContext().unregisterReceiver(mBluetoothDiscoverableReceiver);
            } catch (Exception exception) {
                Log.e(TAG, "回收蓝牙可发现监听异常: ", exception);
            }
            if (bluetoothReceiver != null) {
                try {
                    getContext().unregisterReceiver(bluetoothReceiver);
                } catch (Exception exception) {
                    Log.e(TAG, "回收蓝牙异常: ", exception);
                }
            }
        }
        wifiProbeHandler.removeCallbacksAndMessages(null);
        wifiNetworkCallback = null;
        connectivityManager = null;
        init = false;
        suppressBluetoothSwitchCallback = false;
    }

}