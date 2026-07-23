package com.lasercyber.lws.ui.component.dialog;

import android.app.Activity;
import android.content.Context;
import android.text.TextUtils;
import android.view.View;
import android.widget.EditText;
import android.widget.ImageButton;
import android.widget.RadioGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.frostui.control.interop.FrostSegmentedControlView;
import com.lasercyber.lws.frostui.dialog.FrostOverlayHost;
import com.lasercyber.lws.ime.ImeAction;
import com.lasercyber.lws.ime.core.ImeConfig;
import com.lasercyber.lws.ime.engine.EditTextImeInputConnection;
import com.lasercyber.lws.ime.engine.ImeEnterKeyConfig;
import com.lasercyber.lws.ime.field.ImeFieldType;
import com.lasercyber.lws.ime.interop.ImeOverlayHost;
import com.lasercyber.lws.ime.interop.ImeOverlaySpec;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.network.wifi.WifiIpConfig;

/**
 * Join dialog for hidden Wi-Fi networks: manual SSID, security type, password, and IP settings.
 */
public final class FrostWifiHiddenJoinDialog {

    public interface OnJoinSubmitListener {
        void onJoinSubmit(
                @NonNull String ssid,
                @NonNull String securityType,
                @Nullable String password,
                @NonNull WifiIpConfig ipConfig);
    }

    public interface OnIpSettingsListener {
        void onOpenIpSettings(
                @NonNull String ssid,
                @NonNull String securityType,
                @NonNull WifiIpConfig currentConfig);
    }

    @Nullable
    private final FrostDialog.Handle handle;
    @Nullable
    private final HiddenJoinFormState form;

    private FrostWifiHiddenJoinDialog(
            @Nullable FrostDialog.Handle handle,
            @Nullable HiddenJoinFormState form) {
        this.handle = handle;
        this.form = form;
    }

    @Nullable
    public static FrostWifiHiddenJoinDialog show(
            @NonNull Context context,
            @NonNull OnJoinSubmitListener listener,
            @NonNull OnIpSettingsListener ipSettingsListener) {
        final HiddenJoinFormState[] formHolder = new HiddenJoinFormState[1];
        final FrostDialog.Handle[] handleHolder = new FrostDialog.Handle[1];
        String connectLabel = context.getString(R.string.wifi_dialog_connect);

        ImeOverlaySpec imeOverlay = ImeOverlaySpec.create(
                ImeConfig.withEnterKey(ImeEnterKeyConfig.customConnect(connectLabel)),
                ImeFieldType.WiFi,
                action -> {
                    if (action instanceof ImeAction.Custom
                            && ((ImeAction.Custom) action).getActionId()
                                    == ImeAction.WIFI_PASSWORD_CONNECT_ACTION_ID) {
                        submitJoin(context, formHolder[0], handleHolder[0], listener);
                        return true;
                    }
                    return false;
                });

        FrostDialog.Handle handle = FrostDialog.prompt(context)
                .title(R.string.wifi_hidden_network_title)
                .maxHeightDimen(R.dimen.frost_dialog_prompt_max_height)
                .expandBodyScroll(true)
                .imeOverlay(imeOverlay)
                .customBodyView(R.layout.dialog_frost_body_wifi_hidden_join, body ->
                        formHolder[0] = bindHiddenJoinForm(context, body, ipSettingsListener, handleHolder))
                .showActionBar(false)
                .dismissOnScrimClick(true)
                .show();
        handleHolder[0] = handle;
        if (handle == null) {
            return null;
        }
        Activity activity = FrostOverlayHost.findActivity(context);
        View overlay = handle.getRootView();
        HiddenJoinFormState form = formHolder[0];
        if (activity != null && overlay != null && form != null) {
            ImeOverlayHost.scheduleKeyboardAfterDialogShown(activity, overlay, form.focusField);
            bindFieldImeFocus(activity, overlay, form.ssidField);
            if (form.passwordField != null) {
                bindFieldImeFocus(activity, overlay, form.passwordField);
            }
        }
        return new FrostWifiHiddenJoinDialog(handle, form);
    }

    public void updateIpConfig(@NonNull WifiIpConfig ipConfig) {
        if (form != null) {
            form.ipConfig = ipConfig;
        }
    }

    public void dismiss() {
        if (handle != null) {
            handle.dismiss();
        }
    }

    public boolean isShowing() {
        return handle != null && handle.isShowing();
    }

    private static final class HiddenJoinFormState {
        @NonNull
        final EditText ssidField;
        @NonNull
        final FrostSegmentedControlView securityControl;
        @NonNull
        final View passwordSection;
        @Nullable
        final EditText passwordField;
        @NonNull
        final EditText focusField;
        @NonNull
        WifiIpConfig ipConfig;

        HiddenJoinFormState(
                @NonNull EditText ssidField,
                @NonNull FrostSegmentedControlView securityControl,
                @NonNull View passwordSection,
                @Nullable EditText passwordField,
                @NonNull EditText focusField) {
            this.ssidField = ssidField;
            this.securityControl = securityControl;
            this.passwordSection = passwordSection;
            this.passwordField = passwordField;
            this.focusField = focusField;
            this.ipConfig = WifiIpConfig.dhcp();
        }

        @NonNull
        String readSsid() {
            return ssidField.getText() != null
                    ? ssidField.getText().toString().trim()
                    : "";
        }

        @NonNull
        String securityType() {
            int checkedId = securityControl.getCheckedRadioButtonId();
            if (checkedId == R.id.frost_dialog_wifi_security_wpa3) {
                return "WPA3";
            }
            if (checkedId == R.id.frost_dialog_wifi_security_open) {
                return "Open";
            }
            return "WPA2";
        }

        boolean requiresPassword() {
            return !"Open".equals(securityType());
        }
    }

    @NonNull
    private static HiddenJoinFormState bindHiddenJoinForm(
            @NonNull Context context,
            @NonNull View body,
            @NonNull OnIpSettingsListener ipSettingsListener,
            @NonNull FrostDialog.Handle[] handleHolder) {
        EditText ssidField = body.findViewById(R.id.frost_dialog_wifi_hidden_ssid);
        FrostSegmentedControlView securityControl =
                body.findViewById(R.id.frost_dialog_wifi_hidden_security);
        View passwordSection = body.findViewById(R.id.frost_dialog_wifi_password_section);
        EditText password = body.findViewById(R.id.frost_dialog_wifi_password);
        EditText connectAnchor = body.findViewById(R.id.frost_dialog_wifi_connect_anchor);
        ImageButton visibilityToggle = body.findViewById(R.id.frost_dialog_wifi_password_visibility);

        ssidField.setShowSoftInputOnFocus(false);
        if (password != null) {
            password.setShowSoftInputOnFocus(false);
            bindPasswordVisibilityToggle(password, visibilityToggle);
        }

        securityControl.check(R.id.frost_dialog_wifi_security_wpa2);
        securityControl.setOnCheckedChangeListener((RadioGroup group, int checkedId) ->
                updatePasswordSectionVisibility(passwordSection, checkedId));

        EditText focusField = ssidField != null ? ssidField : connectAnchor;
        if (focusField == null) {
            focusField = connectAnchor;
        }
        HiddenJoinFormState form = new HiddenJoinFormState(
                ssidField,
                securityControl,
                passwordSection,
                password,
                focusField);

        TextView ipSettingsToggle = body.findViewById(R.id.frost_dialog_wifi_ip_settings_toggle);
        if (ipSettingsToggle != null) {
            ipSettingsToggle.setOnClickListener(v -> {
                Activity activity = FrostOverlayHost.findActivity(context);
                FrostDialog.Handle handle = handleHolder[0];
                if (activity != null && handle != null) {
                    ImeOverlayHost.hideKeyboardFor(activity, handle.getRootView());
                }
                ipSettingsListener.onOpenIpSettings(
                        form.readSsid(),
                        form.securityType(),
                        form.ipConfig);
            });
        }

        return form;
    }

    private static void updatePasswordSectionVisibility(
            @Nullable View passwordSection,
            int checkedSecurityId) {
        if (passwordSection == null) {
            return;
        }
        passwordSection.setVisibility(
                checkedSecurityId == R.id.frost_dialog_wifi_security_open
                        ? View.GONE
                        : View.VISIBLE);
    }

    private static void bindFieldImeFocus(
            @NonNull Activity activity,
            @NonNull View overlay,
            @NonNull EditText field) {
        field.setShowSoftInputOnFocus(false);
        View.OnFocusChangeListener focusListener = (v, hasFocus) -> {
            if (!hasFocus || !(v instanceof EditText)) {
                return;
            }
            ImeOverlayHost.showKeyboardFor(activity, overlay, (EditText) v);
        };
        field.setOnFocusChangeListener(focusListener);
        field.setOnClickListener(v -> {
            v.requestFocus();
            if (v instanceof EditText) {
                ImeOverlayHost.showKeyboardFor(activity, overlay, (EditText) v);
            }
        });
    }

    private static void bindPasswordVisibilityToggle(
            @NonNull EditText password,
            @Nullable ImageButton visibilityToggle) {
        if (visibilityToggle == null) {
            return;
        }
        EditTextImeInputConnection connection = new EditTextImeInputConnection(password, action -> false);
        Runnable syncToggleIcon = () -> {
            boolean visible = connection.isPasswordVisible();
            visibilityToggle.setImageResource(
                    visible ? R.drawable.ic_password_visibility : R.drawable.ic_password_visibility_off);
            visibilityToggle.setContentDescription(
                    password.getContext().getString(
                            visible ? R.string.wifi_dialog_hide_password
                                    : R.string.wifi_dialog_show_password));
        };
        visibilityToggle.setOnClickListener(v -> {
            connection.setPasswordVisible(!connection.isPasswordVisible());
            syncToggleIcon.run();
        });
        syncToggleIcon.run();
    }

    private static void submitJoin(
            @NonNull Context context,
            @Nullable HiddenJoinFormState form,
            @Nullable FrostDialog.Handle handle,
            @NonNull OnJoinSubmitListener listener) {
        if (form == null) {
            return;
        }
        String ssid = form.readSsid();
        if (TextUtils.isEmpty(ssid)) {
            ToastUtils.showShort(R.string.wifi_toast_ssid_required);
            return;
        }

        String securityType = form.securityType();
        String password = null;
        if (form.requiresPassword()) {
            if (form.passwordField == null) {
                return;
            }
            password = form.passwordField.getText() != null
                    ? form.passwordField.getText().toString().trim()
                    : "";
            if (TextUtils.isEmpty(password)) {
                ToastUtils.showShort(R.string.wifi_toast_password_required);
                return;
            }
        }

        listener.onJoinSubmit(ssid, securityType, password, form.ipConfig);
        if (handle != null) {
            handle.dismiss();
        } else {
            FrostDialog.dismiss();
        }
    }
}
