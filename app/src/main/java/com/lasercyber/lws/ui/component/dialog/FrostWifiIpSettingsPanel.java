package com.lasercyber.lws.ui.component.dialog;

import android.app.Activity;
import android.content.Context;
import android.text.TextUtils;
import android.view.View;
import android.widget.EditText;
import android.widget.RadioGroup;
import android.widget.TextView;

import androidx.annotation.ColorInt;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.frostui.control.interop.FrostSegmentedControlView;
import com.lasercyber.lws.ime.interop.ImeOverlayHost;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.network.wifi.WifiIpConfig;
import com.lasercyber.lws.ui.common.network.wifi.WifiIpConfigValidator;
import com.lasercyber.lws.ui.common.network.wifi.WifiLinkSnapshot;
import com.lasercyber.lws.ui.common.network.wifi.WifiSubnetUtils;

import java.util.function.Consumer;

/**
 * Shared IP mode + address fields for Wi-Fi join and IP settings dialogs.
 */
final class FrostWifiIpSettingsPanel {

    @NonNull
    private final Context context;
    @NonNull
    private final FrostSegmentedControlView ipModeControl;
    @NonNull
    private final EditText ipField;
    @NonNull
    private final EditText maskField;
    @NonNull
    private final EditText gatewayField;
    @NonNull
    private final EditText dnsField;
    @Nullable
    private final WifiLinkSnapshot liveLink;
    @ColorInt
    private final int editableTextColor;
    @ColorInt
    private final int readOnlyTextColor;
    @Nullable
    private Consumer<EditText> onEditableFieldFocus;
    @Nullable
    private Runnable onHideKeyboard;

    private FrostWifiIpSettingsPanel(
            @NonNull Context context,
            @NonNull FrostSegmentedControlView ipModeControl,
            @NonNull EditText ipField,
            @NonNull EditText maskField,
            @NonNull EditText gatewayField,
            @NonNull EditText dnsField,
            @Nullable WifiLinkSnapshot liveLink) {
        this.context = context;
        this.ipModeControl = ipModeControl;
        this.ipField = ipField;
        this.maskField = maskField;
        this.gatewayField = gatewayField;
        this.dnsField = dnsField;
        this.liveLink = liveLink;
        this.editableTextColor = context.getColor(R.color.frost_text_primary);
        this.readOnlyTextColor = context.getColor(R.color.frost_text_secondary);
    }

    @NonNull
    static FrostWifiIpSettingsPanel bind(
            @NonNull Context context,
            @NonNull View root,
            @Nullable WifiIpConfig initialIpConfig,
            @Nullable WifiLinkSnapshot liveLink) {
        FrostSegmentedControlView ipModeControl = root.findViewById(R.id.frost_dialog_wifi_ip_mode);
        EditText ipField = bindIpFieldRow(root, R.id.frost_dialog_wifi_ip_row, R.string.wifi_ip_address);
        EditText maskField = bindIpFieldRow(root, R.id.frost_dialog_wifi_mask_row, R.string.wifi_subnet_mask);
        EditText gatewayField = bindIpFieldRow(root, R.id.frost_dialog_wifi_gateway_row, R.string.wifi_gateway);
        EditText dnsField = bindIpFieldRow(root, R.id.frost_dialog_wifi_dns_row, R.string.wifi_dns);

        FrostWifiIpSettingsPanel panel = new FrostWifiIpSettingsPanel(
                context,
                ipModeControl,
                ipField,
                maskField,
                gatewayField,
                dnsField,
                liveLink);
        panel.configureIme(ipField, maskField, gatewayField, dnsField);
        panel.applyInitialState(initialIpConfig != null ? initialIpConfig : WifiIpConfig.dhcp());
        ipModeControl.setOnCheckedChangeListener((RadioGroup group, int checkedId) ->
                panel.onIpModeChanged(checkedId));
        return panel;
    }

    void setOnEditableFieldFocus(@Nullable Consumer<EditText> onEditableFieldFocus) {
        this.onEditableFieldFocus = onEditableFieldFocus;
    }

    void setOnHideKeyboard(@Nullable Runnable onHideKeyboard) {
        this.onHideKeyboard = onHideKeyboard;
    }

    void bindImeFocus(@NonNull Activity activity, @NonNull View overlay) {
        View.OnFocusChangeListener focusListener = (v, hasFocus) -> {
            if (!hasFocus || !(v instanceof EditText)) {
                return;
            }
            EditText field = (EditText) v;
            if (field.isEnabled() && field.isFocusable()) {
                ImeOverlayHost.showKeyboardFor(activity, overlay, field);
            }
        };
        for (EditText field : editableFields()) {
            field.setOnFocusChangeListener(focusListener);
            field.setOnClickListener(v -> {
                if (!v.isEnabled() || !v.isFocusable()) {
                    return;
                }
                v.requestFocus();
                if (v instanceof EditText) {
                    ImeOverlayHost.showKeyboardFor(activity, overlay, (EditText) v);
                }
            });
        }
    }

    @NonNull
    private EditText[] editableFields() {
        return new EditText[] {ipField, maskField, gatewayField, dnsField};
    }

    private void requestKeyboardFor(@NonNull EditText field) {
        if (onEditableFieldFocus != null) {
            onEditableFieldFocus.accept(field);
        }
    }

    private void hideKeyboard() {
        if (onHideKeyboard != null) {
            onHideKeyboard.run();
        }
    }

    @Nullable
    EditText getFirstFocusField() {
        if (isStaticMode()) {
            return ipField;
        }
        return null;
    }

    boolean isStaticMode() {
        return ipModeControl.getCheckedRadioButtonId() == R.id.frost_dialog_wifi_ip_mode_static;
    }

    @Nullable
    WifiIpConfig readConfig() {
        if (!isStaticMode()) {
            return WifiIpConfig.dhcp();
        }
        String ip = textOf(ipField);
        String mask = textOf(maskField);
        String gateway = textOf(gatewayField);
        String dns = textOf(dnsField);

        int prefixLength = WifiSubnetUtils.maskToPrefixLength(mask);
        WifiIpConfig config = WifiIpConfig.staticIp(
                emptyToNull(ip),
                prefixLength,
                emptyToNull(gateway),
                null,
                emptyToNull(dns));

        WifiIpConfigValidator.Result validation = WifiIpConfigValidator.validate(config, null);
        if (!validation.valid) {
            ToastUtils.showShort(resolveValidationMessage(validation.reason));
            return null;
        }
        return config;
    }

    private void applyInitialState(@NonNull WifiIpConfig initial) {
        boolean staticMode = initial.isStatic();
        ipModeControl.check(staticMode
                ? R.id.frost_dialog_wifi_ip_mode_static
                : R.id.frost_dialog_wifi_ip_mode_dhcp);
        if (staticMode) {
            populateStaticFields(initial);
            setFieldsEditable(true);
        } else {
            populateDhcpFields();
            setFieldsEditable(false);
        }
    }

    private void onIpModeChanged(int checkedId) {
        if (checkedId == R.id.frost_dialog_wifi_ip_mode_static) {
            clearFieldValues();
            setFieldsEditable(true);
            ipField.requestFocus();
            requestKeyboardFor(ipField);
            return;
        }
        populateDhcpFields();
        setFieldsEditable(false);
        hideKeyboard();
    }

    private void populateStaticFields(@NonNull WifiIpConfig config) {
        setFieldText(ipField, config.ip);
        String mask = WifiSubnetUtils.prefixLengthToMask(config.prefixLength);
        setFieldText(maskField, mask);
        setFieldText(gatewayField, config.gateway);
        setFieldText(dnsField, resolveDnsFromConfig(config));
    }

    private void populateDhcpFields() {
        if (liveLink != null && liveLink.l3Ready) {
            setFieldText(ipField, liveLink.ipv4Address);
            setFieldText(maskField, liveLink.subnetMask);
            setFieldText(gatewayField, liveLink.gateway);
            setFieldText(dnsField, liveLink.dns2() != null ? liveLink.dns2() : liveLink.dns1());
            return;
        }
        clearFieldValues();
    }

    private void clearFieldValues() {
        setFieldText(ipField, null);
        setFieldText(maskField, null);
        setFieldText(gatewayField, null);
        setFieldText(dnsField, null);
    }

    private void setFieldsEditable(boolean editable) {
        configureField(ipField, editable);
        configureField(maskField, editable);
        configureField(gatewayField, editable);
        configureField(dnsField, editable);
    }

    private void configureField(@NonNull EditText field, boolean editable) {
        field.setEnabled(editable);
        field.setFocusable(editable);
        field.setFocusableInTouchMode(editable);
        field.setClickable(editable);
        field.setCursorVisible(editable);
        field.setTextColor(editable ? editableTextColor : readOnlyTextColor);
        if (!editable) {
            field.clearFocus();
        }
    }

    private void configureIme(EditText... fields) {
        for (EditText field : fields) {
            field.setShowSoftInputOnFocus(false);
        }
    }

    @NonNull
    private static EditText bindIpFieldRow(
            @NonNull View root,
            int includeId,
            int labelRes) {
        View row = root.findViewById(includeId);
        TextView label = row.findViewById(R.id.frost_dialog_wifi_ip_field_label);
        EditText input = row.findViewById(R.id.frost_dialog_wifi_ip_field_input);
        label.setText(labelRes);
        return input;
    }

    private static void setFieldText(@NonNull EditText field, @Nullable String value) {
        field.setText(TextUtils.isEmpty(value) ? "" : value);
    }

    @NonNull
    private static String textOf(@NonNull EditText field) {
        return field.getText() != null ? field.getText().toString().trim() : "";
    }

    @Nullable
    private static String emptyToNull(@NonNull String value) {
        return value.isEmpty() ? null : value;
    }

    @Nullable
    private static String resolveDnsFromConfig(@NonNull WifiIpConfig config) {
        if (!TextUtils.isEmpty(config.dns2)) {
            return config.dns2;
        }
        return config.dns1;
    }

    private int resolveValidationMessage(@Nullable String reason) {
        if ("invalid_ip".equals(reason)
                || "invalid_gateway".equals(reason)
                || "invalid_dns1".equals(reason)
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
}
