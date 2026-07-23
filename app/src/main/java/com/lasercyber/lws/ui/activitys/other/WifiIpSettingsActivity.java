package com.lasercyber.lws.ui.activitys.other;

import android.content.Intent;
import android.text.TextUtils;
import android.util.Log;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;

import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ime.field.ImeFieldType;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseActivity;
import com.lasercyber.lws.ui.common.network.wifi.WifiConnectRequest;
import com.lasercyber.lws.ui.common.network.wifi.WifiConnectionCoordinator;
import com.lasercyber.lws.ui.common.network.wifi.WifiIpConfig;
import com.lasercyber.lws.ui.common.network.wifi.WifiIpConfigValidator;
import com.lasercyber.lws.ui.common.network.wifi.WifiLinkSnapshot;
import com.lasercyber.lws.ui.common.network.wifi.WifiNetworkProfile;
import com.lasercyber.lws.ui.common.network.wifi.WifiNetworkProfileStore;
import com.lasercyber.lws.ui.common.network.wifi.WifiSubnetUtils;
import com.lasercyber.lws.ui.common.utils.SystemWifiManagerUtils;
import com.lasercyber.lws.ui.common.utils.WifiStatusUtils;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.component.dialog.FrostTextInputDialog;
import com.lasercyber.lws.ui.databinding.ActivityWifiIpSettingsBinding;

public class WifiIpSettingsActivity extends BaseActivity<ActivityWifiIpSettingsBinding> {

    private static final String TAG = "WifiIpSettings";

    public static final String EXTRA_SSID = "extra_ssid";
    public static final String EXTRA_SECURITY_TYPE = "extra_security_type";
    /** When true, Save returns {@link #EXTRA_RESULT_IP_CONFIG} without connecting. */
    public static final String EXTRA_RETURN_RESULT_ONLY = "extra_return_result_only";
    public static final String EXTRA_INITIAL_IP_CONFIG = "extra_initial_ip_config";
    public static final String EXTRA_RESULT_IP_CONFIG = "extra_result_ip_config";

    private String ssid;
    private String securityType;
    private boolean returnResultOnly;
    private boolean suppressModeCallback;
    private boolean staticMode;
    private WifiLinkSnapshot liveLink;
    private WifiConnectionCoordinator wifiConnectionCoordinator;
    private WifiNetworkProfileStore profileStore;
    private SystemWifiManagerUtils systemWifiManagerUtils;

    private String ipValue = "";
    private String maskValue = "";
    private String gatewayValue = "";
    private String dnsValue = "";

    @Override
    protected int getLayoutId() {
        return R.layout.activity_wifi_ip_settings;
    }

    @Override
    protected void initView() {
        wifiConnectionCoordinator = new WifiConnectionCoordinator(this);
        profileStore = wifiConnectionCoordinator.profiles();
        systemWifiManagerUtils = new SystemWifiManagerUtils(this);
        ssid = normalizeSsid(getIntent().getStringExtra(EXTRA_SSID));
        securityType = safe(getIntent().getStringExtra(EXTRA_SECURITY_TYPE));
        if (TextUtils.isEmpty(securityType)) {
            securityType = "Open";
        }
        returnResultOnly = getIntent().getBooleanExtra(EXTRA_RETURN_RESULT_ONLY, false);
        liveLink = WifiStatusUtils.getLinkSnapshot(this);

        binding.goToUpPage.setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            finish();
        });
        binding.ipModeSetting.setOnCheckedChangeListener((group, checkedId) -> {
            if (suppressModeCallback) {
                return;
            }
            onIpModeChanged(checkedId == R.id.ip_mode_static);
        });
        binding.btnSave.setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            saveSettings();
        });
        binding.tvIpAddress.setOnClickListener(v -> openFieldDialog(R.string.wifi_ip_address, ipValue, value -> {
            ipValue = value;
            updateIpDisplay();
        }));
        binding.tvSubnetMask.setOnClickListener(v -> openFieldDialog(R.string.wifi_subnet_mask, maskValue, value -> {
            maskValue = value;
            updateMaskDisplay();
        }));
        binding.tvGateway.setOnClickListener(v -> openFieldDialog(R.string.wifi_gateway, gatewayValue, value -> {
            gatewayValue = value;
            updateGatewayDisplay();
        }));
        binding.tvDns.setOnClickListener(v -> openFieldDialog(R.string.wifi_dns, dnsValue, value -> {
            dnsValue = value;
            updateDnsDisplay();
        }));

        WifiIpConfig initial = resolveInitialConfig();
        applyConfig(initial);
    }

    @Override
    protected void initData() {
    }

    private void applyConfig(@NonNull WifiIpConfig config) {
        staticMode = config.isStatic();
        suppressModeCallback = true;
        binding.ipModeSetting.check(staticMode ? R.id.ip_mode_static : R.id.ip_mode_dhcp);
        suppressModeCallback = false;
        if (staticMode) {
            ipValue = safe(config.ip);
            maskValue = WifiSubnetUtils.prefixLengthToMask(config.prefixLength);
            gatewayValue = safe(config.gateway);
            dnsValue = resolveDnsFromConfig(config);
        } else {
            populateDhcpFields();
        }
        updateStaticFieldsEditable(staticMode);
        refreshAllDisplays();
    }

    private void onIpModeChanged(boolean staticSelected) {
        staticMode = staticSelected;
        if (staticSelected) {
            clearFieldValues();
        } else {
            populateDhcpFields();
        }
        updateStaticFieldsEditable(staticSelected);
        refreshAllDisplays();
    }

    private void populateDhcpFields() {
        if (liveLink != null && liveLink.l3Ready) {
            ipValue = safe(liveLink.ipv4Address);
            maskValue = safe(liveLink.subnetMask);
            gatewayValue = safe(liveLink.gateway);
            dnsValue = safe(liveLink.dns2() != null ? liveLink.dns2() : liveLink.dns1());
            return;
        }
        clearFieldValues();
    }

    private void clearFieldValues() {
        ipValue = "";
        maskValue = "";
        gatewayValue = "";
        dnsValue = "";
    }

    private void updateStaticFieldsEditable(boolean editable) {
        setFieldEditable(binding.tvIpAddress, editable);
        setFieldEditable(binding.tvSubnetMask, editable);
        setFieldEditable(binding.tvGateway, editable);
        setFieldEditable(binding.tvDns, editable);
    }

    private void setFieldEditable(@NonNull TextView field, boolean editable) {
        field.setEnabled(editable);
        field.setClickable(editable);
        field.setAlpha(editable ? 1f : 0.55f);
    }

    private void openFieldDialog(int titleRes, String currentValue, @NonNull FieldConsumer onSaved) {
        if (!staticMode) {
            return;
        }
        GlobalSoundManager.playClickSound();
        FrostTextInputDialog.show(
                this,
                titleRes,
                currentValue,
                ImeFieldType.Text,
                input -> {
                    onSaved.accept(input);
                    return true;
                });
    }

    private void refreshAllDisplays() {
        updateIpDisplay();
        updateMaskDisplay();
        updateGatewayDisplay();
        updateDnsDisplay();
    }

    private void updateIpDisplay() {
        updateValueOrPlaceholder(binding.tvIpAddress, ipValue, R.string.wifi_ip_address);
    }

    private void updateMaskDisplay() {
        updateValueOrPlaceholder(binding.tvSubnetMask, maskValue, R.string.wifi_subnet_mask);
    }

    private void updateGatewayDisplay() {
        updateValueOrPlaceholder(binding.tvGateway, gatewayValue, R.string.wifi_gateway);
    }

    private void updateDnsDisplay() {
        updateValueOrPlaceholder(binding.tvDns, dnsValue, R.string.wifi_dns);
    }

    private void updateValueOrPlaceholder(
            @NonNull TextView view,
            @Nullable String value,
            int fieldLabelRes) {
        if (TextUtils.isEmpty(value)) {
            if (staticMode) {
                view.setText(getString(R.string.wifi_ip_field_enter_hint, getString(fieldLabelRes)));
            } else {
                view.setText(R.string.wifi_not_available);
            }
            view.setTextColor(ContextCompat.getColor(this, R.color.frost_text_secondary));
            return;
        }
        view.setText(value);
        view.setTextColor(ContextCompat.getColor(
                this,
                staticMode ? R.color.frost_text_primary : R.color.frost_text_secondary));
    }

    @Nullable
    private WifiIpConfig readConfig() {
        if (!staticMode) {
            return WifiIpConfig.dhcp();
        }
        int prefixLength = WifiSubnetUtils.maskToPrefixLength(maskValue);
        WifiIpConfig config = WifiIpConfig.staticIp(
                emptyToNull(ipValue),
                prefixLength,
                emptyToNull(gatewayValue),
                null,
                emptyToNull(dnsValue));

        WifiIpConfigValidator.Result validation = WifiIpConfigValidator.validate(config, null);
        if (!validation.valid) {
            ToastUtils.showShort(resolveValidationMessage(validation.reason));
            return null;
        }
        return config;
    }

    @NonNull
    private WifiIpConfig resolveInitialConfig() {
        String initialEncoded = getIntent().getStringExtra(EXTRA_INITIAL_IP_CONFIG);
        if (!TextUtils.isEmpty(initialEncoded)) {
            return WifiNetworkProfileStore.decodeIpConfig(initialEncoded);
        }
        if (!TextUtils.isEmpty(ssid)) {
            return profileStore.getIpConfigOrDhcp(ssid, securityType);
        }
        return WifiIpConfig.dhcp();
    }

    private void saveSettings() {
        if (returnResultOnly) {
            saveAndReturnResult();
            return;
        }
        if (TextUtils.isEmpty(ssid)) {
            ToastUtils.showShort(R.string.wifi_toast_no_connection_details);
            return;
        }
        if (!systemWifiManagerUtils.hasPrivilegedWifiControl()) {
            ToastUtils.showShort(R.string.wifi_toast_requires_system_privilege);
            return;
        }
        WifiIpConfig config = readConfig();
        if (config == null) {
            return;
        }
        WifiConnectRequest request = new WifiConnectRequest(
                ssid,
                null,
                securityType,
                config);
        WifiConnectionCoordinator.ConnectResult result = wifiConnectionCoordinator.connect(request);
        if (!result.success) {
            Log.w(TAG, "[save] reconnect failed, reason=" + result.reason);
            ToastUtils.showShort(R.string.wifi_toast_connection_failed);
            return;
        }
        ToastUtils.showShort(R.string.wifi_edit_ip_success);
        finish();
    }

    private void saveAndReturnResult() {
        WifiIpConfig config = readConfig();
        if (config == null) {
            return;
        }
        if (!TextUtils.isEmpty(ssid)) {
            profileStore.put(new WifiNetworkProfile(ssid, securityType, config));
        }
        Intent data = new Intent();
        data.putExtra(EXTRA_RESULT_IP_CONFIG, WifiNetworkProfileStore.encodeIpConfig(config));
        setResult(RESULT_OK, data);
        ToastUtils.showShort(R.string.wifi_edit_ip_success);
        finish();
    }

    @NonNull
    private static String resolveDnsFromConfig(@NonNull WifiIpConfig config) {
        if (!TextUtils.isEmpty(config.dns2)) {
            return config.dns2;
        }
        return safe(config.dns1);
    }

    private int resolveValidationMessage(@Nullable String reason) {
        if ("invalid_ip".equals(reason)
                || "invalid_gateway".equals(reason)
                || "invalid_dns2".equals(reason)
                || "invalid_prefix".equals(reason)
                || "invalid_mask".equals(reason)) {
            return R.string.wifi_static_ip_invalid;
        }
        if ("missing_ip".equals(reason)
                || "missing_gateway".equals(reason)
                || "missing_dns1".equals(reason)) {
            return R.string.wifi_static_ip_incomplete;
        }
        if ("gateway_not_in_subnet".equals(reason)) {
            return R.string.wifi_static_ip_gateway_subnet;
        }
        if ("conflicts_with_camera_ip".equals(reason) || "conflicts_with_eth0_ip".equals(reason)) {
            return R.string.wifi_static_ip_conflict;
        }
        return R.string.wifi_static_ip_invalid;
    }

    @Nullable
    private static String emptyToNull(@NonNull String value) {
        return value.isEmpty() ? null : value;
    }

    @NonNull
    private static String safe(@Nullable String value) {
        return value == null ? "" : value;
    }

    @NonNull
    private static String normalizeSsid(@Nullable String raw) {
        if (raw == null) {
            return "";
        }
        return raw.replace("\"", "");
    }

    private interface FieldConsumer {
        void accept(@NonNull String value);
    }
}
