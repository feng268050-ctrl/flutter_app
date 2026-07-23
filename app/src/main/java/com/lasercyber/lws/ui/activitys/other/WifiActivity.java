package com.lasercyber.lws.ui.activitys.other;

import static com.lasercyber.lws.ui.common.modbus.call.ModbusLogger.TAG;
import static com.xuexiang.xutil.XUtil.getContext;

import android.Manifest;
import android.annotation.SuppressLint;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkInfo;
import android.net.wifi.ScanResult;
import android.net.wifi.WifiConfiguration;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.text.TextUtils;
import android.util.Log;
import android.view.View;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.frostui.control.interop.FrostSwitchView;
import com.lasercyber.lws.ui.activitys.BaseActivity;
import com.lasercyber.lws.ui.activitys.other.adapter.WifiAdapter;
import com.lasercyber.lws.ui.bean.entity.WifiModel;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.common.utils.SystemWifiManagerUtils;
import com.lasercyber.lws.ui.common.utils.WifiStatusUtils;
import com.lasercyber.lws.ui.component.ListSelectionBackgroundUtils;
import com.lasercyber.lws.ui.component.dialog.GlobalDialogUtil;
import com.lasercyber.lws.ui.component.dialog.FrostWifiJoinDialog;
import com.lasercyber.lws.ui.component.dialog.FrostWifiHiddenJoinDialog;
import com.lasercyber.lws.ui.common.network.wifi.WifiConnectRequest;
import com.lasercyber.lws.ui.common.network.wifi.WifiConnectionCoordinator;
import com.lasercyber.lws.ui.common.network.wifi.WifiIpConfig;
import com.lasercyber.lws.ui.common.network.wifi.WifiNetworkProfileStore;
import com.lasercyber.lws.ui.common.network.wifi.WifiScanResultAggregator;
import com.lasercyber.lws.ui.databinding.ActivityWifiBinding;

import java.util.ArrayList;
import java.util.List;

public class WifiActivity extends BaseActivity<ActivityWifiBinding> {
    private List<WifiModel> wifiList = new ArrayList<>();
    private WifiAdapter adapter;
    private WifiManager wifiManager;
    private BroadcastReceiver scanReceiver;
    private ConnectivityManager connectivityManager;
    private ConnectivityManager.NetworkCallback networkCallback;
    private Boolean conStatus = false;//连接状态
    private Boolean isNetworkCallbackRegistered = false;
    @androidx.annotation.Nullable
    private FrostWifiJoinDialog joinDialog;
    @androidx.annotation.Nullable
    private FrostWifiHiddenJoinDialog hiddenJoinDialog;
    private WifiModel wifiModel;
    private SystemWifiManagerUtils systemWifiManagerUtils;
    private WifiConnectionCoordinator wifiConnectionCoordinator;
    private static final long SCAN_INTERVAL = 150000; // 扫描间隔（10秒，Android 10+ 限制频繁扫描）

    private Boolean open;

    private final ActivityResultLauncher<Intent> hiddenJoinIpSettingsLauncher =
            registerForActivityResult(new ActivityResultContracts.StartActivityForResult(), result -> {
                if (result.getResultCode() != RESULT_OK || result.getData() == null) {
                    return;
                }
                String encoded = result.getData().getStringExtra(
                        WifiIpSettingsActivity.EXTRA_RESULT_IP_CONFIG);
                if (encoded == null || hiddenJoinDialog == null) {
                    return;
                }
                hiddenJoinDialog.updateIpConfig(WifiNetworkProfileStore.decodeIpConfig(encoded));
            });

    private Handler mScanHandler = new Handler(Looper.getMainLooper());

    // 定时扫描Runnable
    private final Runnable mScanRunnable = new Runnable() {
        @Override
        public void run() {
            if (wifiManager.isWifiEnabled()) {
                // 触发WiFi扫描（Android 10+ 限制每分钟最多4次）
                startScan();
            }
            // 循环执行，实现实时扫描
            mScanHandler.postDelayed(this, SCAN_INTERVAL);
        }
    };

    // 申请WiFi+定位权限
    private void requestPermissions() {
        String[] perms = {
                Manifest.permission.ACCESS_WIFI_STATE,
                Manifest.permission.CHANGE_WIFI_STATE,
                Manifest.permission.ACCESS_FINE_LOCATION
        };
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
                != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, perms, 101);
        } else if (wifiManager.isWifiEnabled()) {
            startScan();
        }
        // 启动定时扫描
        mScanHandler.post(mScanRunnable);

    }

    @Override
    protected void initView() {
        // 初始化管理器
        try {
            wifiManager = (WifiManager) getSystemService(Context.WIFI_SERVICE);
            connectivityManager = (ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE);
            systemWifiManagerUtils = new SystemWifiManagerUtils(this);
            wifiConnectionCoordinator = new WifiConnectionCoordinator(this);

            // 初始化控件
            RecyclerView wifiRecycler = binding.wifiRecycler;
            wifiRecycler.setLayoutManager(new LinearLayoutManager(this));
            adapter = new WifiAdapter(this, wifiList, this::onWifiItemClick);
            wifiRecycler.setAdapter(adapter);

            //开关监听
            wifiSwitchOper();
            binding.btnHiddenNetwork.setOnClickListener(v -> {
                GlobalSoundManager.playClickSound();
                showHiddenJoinDialog();
            });
            // 初始化网络连接回调（Android 10+）
            initNetworkCallback();

            // 监听扫描结果广播和网络状态变化
            scanReceiver = new BroadcastReceiver() {
                @Override
                public void onReceive(Context context, Intent intent) {
                    String action = intent.getAction();
                    if (WifiManager.SCAN_RESULTS_AVAILABLE_ACTION.equals(action)) {
                        if (intent.getBooleanExtra(WifiManager.EXTRA_RESULTS_UPDATED, false)) {
                            startScan(); // 扫描完成后更新列表
                        }
                    } else if (WifiManager.NETWORK_STATE_CHANGED_ACTION.equals(action)) {
                        NetworkInfo networkInfo = intent.getParcelableExtra(WifiManager.EXTRA_NETWORK_INFO);
                        if (networkInfo != null && networkInfo.isConnected()) {
                            conStatus = false;
                            connectivityWifiView(wifiManager.getConnectionInfo());
                        }
                    }
                }
            };
            IntentFilter wifiFilter = new IntentFilter(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION);
            wifiFilter.addAction(WifiManager.NETWORK_STATE_CHANGED_ACTION);
            registerReceiver(scanReceiver, wifiFilter);

            // 申请权限
            requestPermissions();
            //跳转上一页
            goToUpPage();
        } catch (Exception e) {
            Log.d("WifiActivity", "WifiActivity:" + e.getMessage().toString());
        }
    }

    //跳转上一页
    private void goToUpPage() {
        binding.goToUpPage.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                GlobalSoundManager.playClickSound();
                finish();
            }
        });
    }

    /*开关监听*/
    private void wifiSwitchOper() {
        // 初始化开关状态
        FrostSwitchView wifiSwitch = binding.wifiSwitch;
        wifiSwitch.setChecked(wifiManager.isWifiEnabled());
        if (!wifiManager.isWifiEnabled()) { //如果是wifi开关按钮关闭的初始化状态
            binding.wifiCon.setVisibility(View.GONE);
            binding.wifiConNot.setVisibility(View.VISIBLE);
        }
        // 开关监听
        wifiSwitch.setOnCheckedChangeListener((v, isChecked) -> {
            if (null != open && open == isChecked) {
                return;
            }
            GlobalSoundManager.playClickSound();
            wifiManager.setWifiEnabled(isChecked);
            if (isChecked) {
                // 开启WiFi后延迟扫描，避免系统未就绪
                mScanHandler.postDelayed(this::startScan, 1000);
            } else {
                wifiList.clear();
                adapter.updateData(wifiList);
                setUnknown();
                // 关闭WiFi时解绑网络
                unbindProcessNetwork();
            }
            open = isChecked;
        });
    }

    // 初始化网络连接回调（Android 10+）
    private void initNetworkCallback() {
        networkCallback = new ConnectivityManager.NetworkCallback() {
            @Override
            public void onAvailable(@NonNull Network network) {
                conStatus = false;
                // 先解绑旧网络，再绑定新网络
                unbindProcessNetwork();
                connectivityManager.bindProcessToNetwork(network);
                runOnUiThread(() -> {
                    ToastUtils.showShort(getString(R.string.wifi_toast_connected_success));
                    // 延迟扫描，确保网络路由生效
                    mScanHandler.postDelayed(() -> {
                        startScan();
                    }, 2000);
                });
            }

            @Override
            public void onUnavailable() {
                conStatus = false;
                runOnUiThread(() -> {
                    ToastUtils.showShort(getString(R.string.wifi_toast_connection_failed));
                    startScan();
                });
            }

            // 网络丢失（连接失败/断开）
            @Override
            public void onLost(Network network) {
                super.onLost(network);
                Log.e(TAG, "WiFi connection lost：" + network.toString());
                conStatus = false;
                // 网络丢失时解绑
                unbindProcessNetwork();
                runOnUiThread(() -> startScan());
                Log.e(TAG, "WiFi连接丢失：" + network.toString());
            }
        };
    }

    // 解绑进程网络绑定
    private void unbindProcessNetwork() {
        if (connectivityManager != null) {
            try {
                connectivityManager.bindProcessToNetwork(null);
            } catch (Exception e) {
                Log.w(TAG, "Unbind network error", e);
            }
        }
    }

    // 启动WiFi扫描
    @SuppressLint("MissingPermission")
    private void startScan() {
        List<ScanResult> results = wifiManager.getScanResults();
        updateWifiList(results);
    }

    // 更新WiFi列表
    private void updateWifiList(List<ScanResult> results) {
        wifiList.clear();
        connectivityWifiView(wifiManager.getConnectionInfo());
        String connectedSsid = getConnectedSsidNormalized();
        List<WifiScanResultAggregator.AggregatedEntry> aggregated =
                WifiScanResultAggregator.aggregate(results, connectedSsid);
        for (WifiScanResultAggregator.AggregatedEntry entry : aggregated) {
            wifiList.add(toWifiModel(entry.representative));
        }
        adapter.updateData(wifiList);
    }

    @androidx.annotation.Nullable
    private String getConnectedSsidNormalized() {
        WifiInfo wifiInfo = wifiManager.getConnectionInfo();
        if (wifiInfo == null) {
            return null;
        }
        return WifiScanResultAggregator.normalizeSsid(wifiInfo.getSSID());
    }

    private WifiModel toWifiModel(ScanResult res) {
        boolean isEncrypted = res.capabilities.contains("WPA");
        int wifiStandard = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R ? res.getWifiStandard() : 0;
        return new WifiModel(
                res.SSID,
                res.BSSID,
                res.capabilities,
                false,
                isEncrypted,
                res.level,
                wifiStandard);
    }

    /*获取已连接的wifi信息*/
    private void connectivityWifiView(WifiInfo wifiInfo) {
        if (binding == null || wifiInfo == null || wifiInfo.getSSID() == null) {
            return;
        }
        if (conStatus) {
            binding.wifiCon.setVisibility(View.GONE);
            binding.wifiConNot.setVisibility(View.VISIBLE);
            binding.wifiConNotText.setText(getString(R.string.wifi_status_connecting));
            binding.wifiConNotText.setTextColor(Color.parseColor("#00BF60"));
            return;
        }
        String connectedSsid = wifiInfo.getSSID().replace("\"", "");
        /*|| wifiInfo.getNetworkId() <= 0*/
        if (connectedSsid.equals("<unknown ssid>")) {
            setUnknown();
            return;
        }
        /*isWifiAvailable() &&*/
        if (wifiInfo.getIpAddress() != 0 && !TextUtils.isEmpty(wifiInfo.getSSID())) {
            binding.wifiCon.setVisibility(View.VISIBLE);
            binding.wifiConNot.setVisibility(View.GONE);
            bindConnectedNetworkRow(wifiInfo, connectedSsid);
            Network activeNetwork = connectivityManager.getActiveNetwork();
            if (activeNetwork != null) {
                // 把当前进程绑定到系统活跃网络
                connectivityManager.bindProcessToNetwork(activeNetwork);
            }
            ListSelectionBackgroundUtils.applyPressRipple(
                    binding.wifiCon, 1, 2, R.dimen.frost_corner_radius);
            binding.wifiCon.setOnClickListener(v -> openWifiDetails(wifiInfo));
        }
    }

    private void bindConnectedNetworkRow(WifiInfo wifiInfo, String connectedSsid) {
        View row = binding.wifiCon;
        TextView tvSsid = row.findViewById(R.id.tv_ssid);
        TextView tvStandard = row.findViewById(R.id.tv_standard);
        TextView tvState = row.findViewById(R.id.tv_state);
        ImageView ivConnected = row.findViewById(R.id.iv_connected);
        ImageView ivLock = row.findViewById(R.id.iv_lock);
        ImageView ivSignal = row.findViewById(R.id.iv_signal);

        tvSsid.setText(connectedSsid);
        ivConnected.setVisibility(View.VISIBLE);
        tvState.setVisibility(View.GONE);

        ScanResult scanResult = findConnectedScanResult(wifiInfo, connectedSsid);
        if (scanResult != null) {
            int wifiStandard = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R ? scanResult.getWifiStandard() : 0;
            tvStandard.setText(getString(R.string.wifi_list_standard_format, wifiStandard));
            ivLock.setVisibility(scanResult.capabilities.contains("WPA") ? View.VISIBLE : View.GONE);
            ivSignal.setImageResource(getSignalIconRes(scanResult.level));
            return;
        }

        tvStandard.setText("");
        ivLock.setVisibility(View.GONE);
        ivSignal.setImageResource(getSignalIconRes(wifiInfo.getRssi()));
    }

    @androidx.annotation.Nullable
    private ScanResult findConnectedScanResult(WifiInfo wifiInfo, String connectedSsid) {
        if (wifiManager == null) {
            return null;
        }
        List<ScanResult> results = wifiManager.getScanResults();
        return WifiScanResultAggregator.representativeForSsid(
                results,
                connectedSsid,
                wifiInfo.getBSSID());
    }

    private static int getSignalIconRes(int rssi) {
        if (rssi >= -70) {
            return R.mipmap.wifi_icon;
        }
        if (rssi >= -85) {
            return R.mipmap.wifi_icon_1;
        }
        return R.mipmap.wifi_icon;
    }

    private void setUnknown() {
        binding.wifiCon.setVisibility(View.GONE);
        binding.wifiConNot.setVisibility(View.VISIBLE);
        binding.wifiConNotText.setText(getString(R.string.wifi_status_not_connected));
        binding.wifiConNotText.setTextColor(Color.parseColor("#909399"));
    }


    // 【核心】处理WiFi项的点击事件
    private void onWifiItemClick(WifiModel wifiModel) {
        Log.i(TAG, "[wifi_trace] click wifi item, ssid=" + wifiModel.getSsid()
                + ", encrypted=" + wifiModel.isEncrypted()
                + ", connected=" + wifiModel.isConnected());
        if (joinDialog != null && joinDialog.isShowing()) {
            return;
        }
        if (hiddenJoinDialog != null && hiddenJoinDialog.isShowing()) {
            return;
        }
        // 1. 如果已连接，提示并返回（可添加断开连接逻辑）
        if (wifiModel.isConnected()) {
            openWifiDetails(wifiModel);
            return;
        }
        showJoinDialog(wifiModel);
    }

    private void showJoinDialog(WifiModel model) {
        Log.i(TAG, "[wifi_trace] show join dialog, ssid=" + model.getSsid());
        this.wifiModel = model;
        String securityType = WifiStatusUtils.deriveSecurityType(model.getCapabilities());
        boolean requirePassword = !"Open".equals(securityType);
        joinDialog = FrostWifiJoinDialog.show(
                this,
                model.getSsid(),
                getString(R.string.wifi_join_ssid_format, model.getSsid()),
                requirePassword,
                null,
                (ssid, password, ipConfig) -> {
                    Log.i(TAG, "[wifi_trace] submit join for ssid=" + ssid);
                    connectWifi(model, securityType, password, ipConfig);
                });
    }

    private void showHiddenJoinDialog() {
        if (hiddenJoinDialog != null && hiddenJoinDialog.isShowing()) {
            return;
        }
        if (wifiManager == null || !wifiManager.isWifiEnabled()) {
            ToastUtils.showShort(getString(R.string.wifi_toast_wifi_disabled));
            return;
        }
        hiddenJoinDialog = FrostWifiHiddenJoinDialog.show(
                this,
                (ssid, securityType, password, ipConfig) ->
                        connectHiddenWifi(ssid, securityType, password, ipConfig),
                (ssid, securityType, currentConfig) -> openHiddenJoinIpSettings(
                        ssid, securityType, currentConfig));
    }

    private void openHiddenJoinIpSettings(
            @NonNull String ssid,
            @NonNull String securityType,
            @NonNull WifiIpConfig currentConfig) {
        Intent intent = new Intent(this, WifiIpSettingsActivity.class);
        intent.putExtra(WifiIpSettingsActivity.EXTRA_SSID, ssid);
        intent.putExtra(WifiIpSettingsActivity.EXTRA_SECURITY_TYPE, securityType);
        intent.putExtra(WifiIpSettingsActivity.EXTRA_RETURN_RESULT_ONLY, true);
        intent.putExtra(
                WifiIpSettingsActivity.EXTRA_INITIAL_IP_CONFIG,
                WifiNetworkProfileStore.encodeIpConfig(currentConfig));
        hiddenJoinIpSettingsLauncher.launch(intent);
    }

    private void connectHiddenWifi(
            @NonNull String ssid,
            @NonNull String securityType,
            @androidx.annotation.Nullable String password,
            @NonNull WifiIpConfig ipConfig) {
        if (TextUtils.isEmpty(ssid)) {
            ToastUtils.showShort(getString(R.string.wifi_toast_connection_failed));
            return;
        }
        if (wifiConnectionCoordinator == null) {
            wifiConnectionCoordinator = new WifiConnectionCoordinator(this);
        }
        if (systemWifiManagerUtils == null) {
            systemWifiManagerUtils = new SystemWifiManagerUtils(this);
        }
        if (!systemWifiManagerUtils.hasPrivilegedWifiControl()) {
            ToastUtils.showShort(getString(R.string.wifi_toast_requires_system_privilege));
            return;
        }
        if (wifiManager == null || !wifiManager.isWifiEnabled()) {
            ToastUtils.showShort(getString(R.string.wifi_toast_wifi_disabled));
            return;
        }
        WifiConnectRequest request = new WifiConnectRequest(
                ssid,
                password,
                securityType,
                ipConfig,
                true);
        WifiConnectionCoordinator.ConnectResult result = wifiConnectionCoordinator.connect(request);
        if (!result.success) {
            Log.w(TAG, "[wifi_trace] hidden connect failed, reason=" + result.reason);
            ToastUtils.showShort(getString(R.string.wifi_toast_connection_failed));
            startScan();
            return;
        }
        conStatus = true;
        mScanHandler.postDelayed(() -> {
            conStatus = false;
            startScan();
        }, 2000);
    }

    private void connectWifi(
            WifiModel wifiModel,
            String securityType,
            @androidx.annotation.Nullable String password,
            WifiIpConfig ipConfig) {
        if (wifiModel == null || TextUtils.isEmpty(wifiModel.getSsid())) {
            ToastUtils.showShort(getString(R.string.wifi_toast_connection_failed));
            return;
        }
        if (wifiConnectionCoordinator == null) {
            wifiConnectionCoordinator = new WifiConnectionCoordinator(this);
        }
        if (systemWifiManagerUtils == null) {
            systemWifiManagerUtils = new SystemWifiManagerUtils(this);
        }
        if (!systemWifiManagerUtils.hasPrivilegedWifiControl()) {
            ToastUtils.showShort(getString(R.string.wifi_toast_requires_system_privilege));
            return;
        }
        if (wifiManager == null || !wifiManager.isWifiEnabled()) {
            ToastUtils.showShort(getString(R.string.wifi_toast_wifi_disabled));
            return;
        }
        WifiConnectRequest request = new WifiConnectRequest(
                wifiModel.getSsid(),
                password,
                securityType,
                ipConfig);
        WifiConnectionCoordinator.ConnectResult result = wifiConnectionCoordinator.connect(request);
        if (!result.success) {
            Log.w(TAG, "[wifi_trace] connect failed, reason=" + result.reason);
            ToastUtils.showShort(getString(R.string.wifi_toast_connection_failed));
            startScan();
            return;
        }
        conStatus = true;
        mScanHandler.postDelayed(() -> {
            conStatus = false;
            startScan();
        }, 2000);
    }

    // 安全注销网络回调
    private void unregisterNetworkCallback() {
        if (connectivityManager != null && networkCallback != null && isNetworkCallbackRegistered) {
            try {
                connectivityManager.unregisterNetworkCallback(networkCallback);
            } catch (IllegalArgumentException e) {
                Log.w(TAG, "NetworkCallback not registered", e);
            } finally {
                isNetworkCallbackRegistered = false;
            }
        }
    }

    @Override
    protected void initData() {
    }

    @Override
    protected int getLayoutId() {
        return R.layout.activity_wifi;
    }

    // 权限申请结果回调
    @Override
    public void onRequestPermissionsResult(int reqCode, @NonNull String[] perms, @NonNull int[] results) {
        super.onRequestPermissionsResult(reqCode, perms, results);
        if (reqCode == 101 && wifiManager.isWifiEnabled()) {
            startScan();
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        logCurrentWifiState("onDestroy");
        // 注销广播接收器
        try {
            if (scanReceiver != null) {
                unregisterReceiver(scanReceiver);
            }
        } catch (IllegalArgumentException e) {
            Log.w(TAG, "ScanReceiver not registered", e);
        }
        if (connectivityManager != null && networkCallback != null && isNetworkCallbackRegistered) {
            try {
                connectivityManager.unregisterNetworkCallback(networkCallback);
                networkCallback = null;
            } catch (IllegalArgumentException e) {
                e.printStackTrace();
            }
        }
        // unbindProcessNetwork();

        // 停止定时扫描
        if (mScanHandler != null) {
            mScanHandler.removeCallbacks(mScanRunnable);
            mScanHandler.removeCallbacksAndMessages(null);
            mScanHandler = null;
            // 停止定时扫描
        }
        if (joinDialog != null && joinDialog.isShowing()) {
            joinDialog.dismiss();
        }
        if (hiddenJoinDialog != null && hiddenJoinDialog.isShowing()) {
            hiddenJoinDialog.dismiss();
        }

        // 清空引用，避免内存泄漏
        adapter = null;
        wifiList = null;
        networkCallback = null;
        connectivityManager = null;
        scanReceiver = null;
        joinDialog = null;
        hiddenJoinDialog = null;
        wifiManager = null;
    }

    private void logCurrentWifiState(String stage) {
        try {
            WifiInfo info = wifiManager == null ? null : wifiManager.getConnectionInfo();
            String ssid = info == null ? "null" : info.getSSID();
            int ipAddress = info == null ? 0 : info.getIpAddress();
            Network activeNetwork = connectivityManager == null ? null : connectivityManager.getActiveNetwork();
            Log.i(TAG, "[wifi_trace] " + stage
                    + ", ssid=" + ssid
                    + ", ip=" + formatIp(ipAddress)
                    + ", activeNetwork=" + (activeNetwork != null));
        } catch (Exception e) {
            Log.w(TAG, "[wifi_trace] failed at " + stage, e);
        }
    }

    private String formatIp(int ipAddress) {
        if (ipAddress == 0) {
            return "0.0.0.0";
        }
        return WifiStatusUtils.formatIpAddress(ipAddress);
    }

    private void openWifiDetails(WifiModel model) {
        if (model == null || !model.isConnected()) {
            ToastUtils.showShort(getString(R.string.wifi_toast_details_only_when_connected));
            return;
        }
        Intent intent = new Intent(this, WifiDetailsActivity.class);
        intent.putExtra(WifiDetailsActivity.EXTRA_SSID, model.getSsid());
        intent.putExtra(WifiDetailsActivity.EXTRA_BSSID, model.getBssid());
        intent.putExtra(WifiDetailsActivity.EXTRA_CAPABILITIES, model.getCapabilities());
        intent.putExtra(WifiDetailsActivity.EXTRA_RSSI, model.getRssi());
        intent.putExtra(WifiDetailsActivity.EXTRA_LINK_SPEED, Integer.MIN_VALUE);
        intent.putExtra(WifiDetailsActivity.EXTRA_FREQUENCY, Integer.MIN_VALUE);
        startActivity(intent);
    }

    private void openWifiDetails(WifiInfo wifiInfo) {
        if (wifiInfo == null || TextUtils.isEmpty(wifiInfo.getSSID())) {
            ToastUtils.showShort(getString(R.string.wifi_toast_no_connection_details));
            return;
        }
        Intent intent = new Intent(this, WifiDetailsActivity.class);
        intent.putExtra(WifiDetailsActivity.EXTRA_SSID, wifiInfo.getSSID().replace("\"", ""));
        intent.putExtra(WifiDetailsActivity.EXTRA_BSSID, wifiInfo.getBSSID());
        intent.putExtra(WifiDetailsActivity.EXTRA_CAPABILITIES, "");
        intent.putExtra(WifiDetailsActivity.EXTRA_RSSI, wifiInfo.getRssi());
        intent.putExtra(WifiDetailsActivity.EXTRA_LINK_SPEED, wifiInfo.getLinkSpeed());
        intent.putExtra(WifiDetailsActivity.EXTRA_FREQUENCY, wifiInfo.getFrequency());
        startActivity(intent);
    }

}
