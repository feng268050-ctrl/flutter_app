package com.lasercyber.lws.ui.activitys.other;

import android.annotation.SuppressLint;
import android.content.Context;
import android.content.Intent;
import android.net.wifi.WifiManager;
import android.text.TextUtils;
import android.util.Log;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseActivity;
import com.lasercyber.lws.ui.bean.entity.dto.ConnectedWifiInfo;
import com.lasercyber.lws.ui.common.network.wifi.WifiConnectionCoordinator;
import com.lasercyber.lws.ui.common.network.wifi.WifiIpConfig;
import com.lasercyber.lws.ui.common.network.wifi.WifiLinkSnapshot;
import com.lasercyber.lws.ui.common.utils.SystemWifiManagerUtils;
import com.lasercyber.lws.ui.common.utils.WifiStatusUtils;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.component.dialog.FrostDialog;
import com.lasercyber.lws.ui.databinding.ActivityWifiDetailsBinding;

public class WifiDetailsActivity extends BaseActivity<ActivityWifiDetailsBinding> {
    private static final String TAG = "WifiForgetTrace";

    public static final String EXTRA_SSID = "extra_ssid";
    public static final String EXTRA_BSSID = "extra_bssid";
    public static final String EXTRA_CAPABILITIES = "extra_capabilities";
    public static final String EXTRA_RSSI = "extra_rssi";
    public static final String EXTRA_LINK_SPEED = "extra_link_speed";
    public static final String EXTRA_FREQUENCY = "extra_frequency";

    private WifiManager wifiManager;
    private String ssid;
    private String bssid;
    private String capabilities;
    private String securityType;
    private int rssi;
    private int linkSpeed;
    private int frequency;
    private SystemWifiManagerUtils systemWifiManagerUtils;
    private WifiConnectionCoordinator wifiConnectionCoordinator;

    @Override
    protected void initView() {
        wifiManager = (WifiManager) getApplicationContext().getSystemService(Context.WIFI_SERVICE);
        systemWifiManagerUtils = new SystemWifiManagerUtils(this);
        wifiConnectionCoordinator = new WifiConnectionCoordinator(this);
        ssid = normalizeSsid(getIntent().getStringExtra(EXTRA_SSID));
        bssid = safe(getIntent().getStringExtra(EXTRA_BSSID));
        capabilities = safe(getIntent().getStringExtra(EXTRA_CAPABILITIES));
        securityType = WifiStatusUtils.deriveSecurityType(capabilities);
        rssi = getIntent().getIntExtra(EXTRA_RSSI, Integer.MIN_VALUE);
        linkSpeed = getIntent().getIntExtra(EXTRA_LINK_SPEED, Integer.MIN_VALUE);
        frequency = getIntent().getIntExtra(EXTRA_FREQUENCY, Integer.MIN_VALUE);

        binding.tvTitle.setText(TextUtils.isEmpty(ssid) ? getString(R.string.wifi_details_title) : ssid);
        binding.goToUpPage.setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            finish();
        });

        renderWifiDetails();
        binding.btnEditIp.setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            openIpSettings();
        });
        binding.btnForget.setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            showForgetConfirm();
        });
    }

    @Override
    protected void onResume() {
        super.onResume();
        renderWifiDetails();
    }

    @Override
    protected void initData() {
    }

    @Override
    protected int getLayoutId() {
        return R.layout.activity_wifi_details;
    }

    @SuppressLint("MissingPermission")
    private void renderWifiDetails() {
        ConnectedWifiInfo info = WifiStatusUtils.getConnectedWifiInfo(this);
        WifiLinkSnapshot link = WifiStatusUtils.getLinkSnapshot(this);
        if (TextUtils.isEmpty(securityType) && info != null) {
            securityType = WifiStatusUtils.deriveSecurityType(info.getCapabilities());
        }
        if (TextUtils.isEmpty(securityType) && info != null) {
            securityType = safe(info.getSecurityType());
        }

        binding.tvValueIpMode.setText(formatIpMode());
        binding.tvValueIpAddress.setText(formatStringOrFallback(
                link.l3Ready ? link.ipv4Address : (info == null ? null : info.getIpAddress())));
        binding.tvValueSubnetMask.setText(formatStringOrFallback(
                link.l3Ready ? link.subnetMask : (info == null ? null : info.getSubnetMask())));
        binding.tvValueRouter.setText(formatStringOrFallback(
                link.l3Ready ? link.gateway : (info == null ? null : info.getRouter())));
        binding.tvValueDns.setText(formatStringOrFallback(formatDns(link, info)));
        binding.tvValueSignalStrength.setText(formatRssi(info));
        binding.tvValueLinkSpeed.setText(formatLinkSpeed(info));
        binding.tvValueSecurityType.setText(formatSecurityType(info));
        binding.tvValueFrequency.setText(formatFrequency(info));
        binding.tvValueMac.setText(formatStringOrFallback(info == null ? null : info.getMacAddress()));
    }

    private void openIpSettings() {
        if (TextUtils.isEmpty(ssid)) {
            ToastUtils.showShort(R.string.wifi_toast_no_connection_details);
            return;
        }
        Intent intent = new Intent(this, WifiIpSettingsActivity.class);
        intent.putExtra(WifiIpSettingsActivity.EXTRA_SSID, ssid);
        intent.putExtra(WifiIpSettingsActivity.EXTRA_SECURITY_TYPE, resolveSecurityType());
        startActivity(intent);
    }

    private void showForgetConfirm() {
        FrostDialog.prompt(this)
                .title(R.string.prompt_text)
                .message(R.string.wifi_forget_confirm_message)
                .confirmText(R.string.confirm_text)
                .cancelText(R.string.cancel_text)
                .onConfirm(this::forgetCurrentNetwork)
                .show();
    }

    @SuppressLint("MissingPermission")
    private void forgetCurrentNetwork() {
        if (systemWifiManagerUtils == null) {
            systemWifiManagerUtils = new SystemWifiManagerUtils(this);
        }
        if (wifiManager == null || systemWifiManagerUtils == null) {
            ToastUtils.showShort(R.string.operation_failed_text);
            return;
        }
        if (!systemWifiManagerUtils.hasPrivilegedWifiControl()) {
            ToastUtils.showShort(R.string.wifi_toast_requires_system_privilege);
            return;
        }

        String resolvedSecurityType = TextUtils.isEmpty(securityType) ? "Open" : securityType;
        wifiConnectionCoordinator.removeProfile(ssid, resolvedSecurityType);

        SystemWifiManagerUtils.OperationResult result =
                systemWifiManagerUtils.forgetNetwork(ssid, bssid);
        if (!result.success) {
            Log.w(TAG, "[forget] privileged forget failed, reason=" + result.reason);
            ToastUtils.showShort(R.string.wifi_forget_partial_failed);
            return;
        }
        ToastUtils.showShort(R.string.wifi_forget_success);
        finish();
    }

    private String formatIpMode() {
        WifiIpConfig.Mode mode = WifiStatusUtils.getConfiguredIpMode(this, ssid, resolveSecurityType());
        if (mode == WifiIpConfig.Mode.STATIC) {
            return getString(R.string.wifi_ip_mode_static);
        }
        return getString(R.string.wifi_ip_mode_dhcp);
    }

    @Nullable
    private String formatDns(@NonNull WifiLinkSnapshot link, @Nullable ConnectedWifiInfo info) {
        if (link.l3Ready) {
            if (!TextUtils.isEmpty(link.dns2())) {
                return link.dns2();
            }
            return link.dns1();
        }
        return info == null ? null : info.getDns();
    }

    @NonNull
    private String resolveSecurityType() {
        return TextUtils.isEmpty(securityType) ? "Open" : securityType;
    }

    private String formatRssi(@Nullable ConnectedWifiInfo info) {
        int value = rssi;
        if (value == Integer.MIN_VALUE && info != null && info.getRssi() != null) {
            value = info.getRssi();
        }
        if (value == Integer.MIN_VALUE) {
            return fallback();
        }
        return value + " dBm";
    }

    private String formatLinkSpeed(@Nullable ConnectedWifiInfo info) {
        int value = linkSpeed;
        if ((value == Integer.MIN_VALUE || value <= 0) && info != null && info.getLinkSpeed() != null) {
            value = info.getLinkSpeed();
        }
        if (value == Integer.MIN_VALUE || value <= 0) {
            return fallback();
        }
        return value + " Mbps";
    }

    private String formatFrequency(@Nullable ConnectedWifiInfo info) {
        int value = frequency;
        if ((value == Integer.MIN_VALUE || value <= 0) && info != null && info.getFrequency() != null) {
            value = info.getFrequency();
        }
        if (value == Integer.MIN_VALUE || value <= 0) {
            return fallback();
        }
        if (value >= 5000) {
            return value + " MHz (5 GHz)";
        }
        return value + " MHz (2.4 GHz)";
    }

    private String formatSecurityType(@Nullable ConnectedWifiInfo info) {
        String securityCapabilities = capabilities;
        if (TextUtils.isEmpty(securityCapabilities) && info != null) {
            securityCapabilities = safe(info.getCapabilities());
        }
        if (TextUtils.isEmpty(securityCapabilities) && info != null) {
            securityCapabilities = safe(info.getSecurityType());
        }
        String label = WifiStatusUtils.deriveSecurityType(securityCapabilities);
        if (TextUtils.isEmpty(label)) {
            return fallback();
        }
        return label;
    }

    private String formatStringOrFallback(@Nullable String value) {
        if (TextUtils.isEmpty(value)) {
            return fallback();
        }
        return value;
    }

    private String fallback() {
        return getString(R.string.wifi_not_available);
    }

    private String normalizeSsid(String raw) {
        if (raw == null) {
            return "";
        }
        return raw.replace("\"", "");
    }

    private String safe(String value) {
        return value == null ? "" : value;
    }
}
