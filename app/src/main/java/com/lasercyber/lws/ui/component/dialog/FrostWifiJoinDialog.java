package com.lasercyber.lws.ui.component.dialog;

import android.app.Activity;
import android.content.Context;
import android.text.TextUtils;
import android.view.View;
import android.widget.EditText;
import android.widget.ImageButton;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ime.ImeAction;
import com.lasercyber.lws.ime.core.ImeConfig;
import com.lasercyber.lws.ime.engine.EditTextImeInputConnection;
import com.lasercyber.lws.ime.engine.ImeEnterKeyConfig;
import com.lasercyber.lws.ime.field.ImeFieldType;
import com.lasercyber.lws.ime.interop.ImeOverlayHost;
import com.lasercyber.lws.ime.interop.ImeOverlaySpec;
import com.lasercyber.lws.frostui.dialog.FrostOverlayHost;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.network.wifi.WifiIpConfig;
import com.lasercyber.lws.ui.common.network.wifi.WifiLinkSnapshot;

/**
 * WiFi join dialog with optional password and collapsible IP settings.
 */
public final class FrostWifiJoinDialog {

    public interface OnJoinSubmitListener {
        void onJoinSubmit(
                @NonNull String ssid,
                @Nullable String password,
                @NonNull WifiIpConfig ipConfig);
    }

    @Nullable
    private final FrostDialog.Handle handle;

    private FrostWifiJoinDialog(@Nullable FrostDialog.Handle handle) {
        this.handle = handle;
    }

    @Nullable
    public static FrostWifiJoinDialog show(
            @NonNull Context context,
            @NonNull String ssid,
            @NonNull CharSequence title,
            boolean requirePassword,
            @Nullable WifiIpConfig initialIpConfig,
            @NonNull OnJoinSubmitListener listener) {
        return show(context, ssid, title, requirePassword, initialIpConfig, null, listener);
    }

    @Nullable
    public static FrostWifiJoinDialog show(
            @NonNull Context context,
            @NonNull String ssid,
            @NonNull CharSequence title,
            boolean requirePassword,
            @Nullable WifiIpConfig initialIpConfig,
            @Nullable WifiLinkSnapshot liveLink,
            @NonNull OnJoinSubmitListener listener) {
        final EditText[] passwordHolder = new EditText[1];
        final EditText[] focusHolder = new EditText[1];
        final FrostDialog.Handle[] handleHolder = new FrostDialog.Handle[1];
        final JoinFormState[] formHolder = new JoinFormState[1];
        String connectLabel = context.getString(R.string.wifi_dialog_connect);

        ImeOverlaySpec imeOverlay = ImeOverlaySpec.create(
                ImeConfig.withEnterKey(ImeEnterKeyConfig.customConnect(connectLabel)),
                requirePassword ? ImeFieldType.WiFi : ImeFieldType.Text,
                action -> {
                    if (action instanceof ImeAction.Custom
                            && ((ImeAction.Custom) action).getActionId()
                                    == ImeAction.WIFI_PASSWORD_CONNECT_ACTION_ID) {
                        submitJoin(context, ssid, requirePassword, passwordHolder[0],
                                formHolder[0], handleHolder[0], listener);
                        return true;
                    }
                    return false;
                });

        FrostDialog.Handle handle = FrostDialog.prompt(context)
                .title(title)
                .maxHeightDimen(R.dimen.frost_dialog_prompt_max_height)
                .expandBodyScroll(true)
                .imeOverlay(imeOverlay)
                .customBodyView(R.layout.dialog_frost_body_wifi_join, body -> {
                    formHolder[0] = bindJoinForm(
                            context, body, requirePassword, initialIpConfig, liveLink);
                    passwordHolder[0] = formHolder[0].passwordField;
                    focusHolder[0] = formHolder[0].focusField;
                })
                .showActionBar(false)
                .dismissOnScrimClick(true)
                .show();
        handleHolder[0] = handle;
        if (handle == null) {
            return null;
        }
        Activity activity = FrostOverlayHost.findActivity(context);
        View overlay = handle.getRootView();
        JoinFormState form = formHolder[0];
        if (activity != null && overlay != null && form != null) {
            form.ipSettingsPanel.setOnEditableFieldFocus(
                    field -> ImeOverlayHost.showKeyboardFor(activity, overlay, field));
            form.ipSettingsPanel.setOnHideKeyboard(
                    () -> ImeOverlayHost.hideKeyboardFor(activity, overlay));
            form.ipSettingsPanel.bindImeFocus(activity, overlay);
        }
        EditText focusField = passwordHolder[0];
        if (focusField == null && form != null) {
            focusField = form.focusField;
        }
        if (activity != null && overlay != null && focusField != null) {
            ImeOverlayHost.scheduleKeyboardAfterDialogShown(activity, overlay, focusField);
        }
        return new FrostWifiJoinDialog(handle);
    }

    public void dismiss() {
        if (handle != null) {
            handle.dismiss();
        }
    }

    public boolean isShowing() {
        return handle != null && handle.isShowing();
    }

    private static final class JoinFormState {
        @Nullable
        final EditText passwordField;
        @NonNull
        final EditText focusField;
        @NonNull
        final FrostWifiIpSettingsPanel ipSettingsPanel;
        @NonNull
        final View ipSettingsPanelContainer;

        JoinFormState(
                @Nullable EditText passwordField,
                @NonNull EditText focusField,
                @NonNull FrostWifiIpSettingsPanel ipSettingsPanel,
                @NonNull View ipSettingsPanelContainer) {
            this.passwordField = passwordField;
            this.focusField = focusField;
            this.ipSettingsPanel = ipSettingsPanel;
            this.ipSettingsPanelContainer = ipSettingsPanelContainer;
        }

        boolean isIpSettingsExpanded() {
            return ipSettingsPanelContainer.getVisibility() == View.VISIBLE;
        }
    }

    @NonNull
    private static JoinFormState bindJoinForm(
            @NonNull Context context,
            @NonNull View body,
            boolean requirePassword,
            @Nullable WifiIpConfig initialIpConfig,
            @Nullable WifiLinkSnapshot liveLink) {
        View passwordSection = body.findViewById(R.id.frost_dialog_wifi_password_section);
        EditText password = body.findViewById(R.id.frost_dialog_wifi_password);
        EditText connectAnchor = body.findViewById(R.id.frost_dialog_wifi_connect_anchor);
        ImageButton visibilityToggle = body.findViewById(R.id.frost_dialog_wifi_password_visibility);
        if (requirePassword) {
            if (password != null) {
                password.setShowSoftInputOnFocus(false);
                bindPasswordVisibilityToggle(password, visibilityToggle);
            }
        } else if (passwordSection != null) {
            passwordSection.setVisibility(View.GONE);
        }

        TextView ipSettingsToggle = body.findViewById(R.id.frost_dialog_wifi_ip_settings_toggle);
        View ipSettingsPanelContainer = body.findViewById(R.id.frost_dialog_wifi_ip_settings_panel);
        FrostWifiIpSettingsPanel ipSettingsPanel = FrostWifiIpSettingsPanel.bind(
                context,
                ipSettingsPanelContainer,
                initialIpConfig,
                liveLink);

        boolean staticMode = initialIpConfig != null && initialIpConfig.isStatic();
        if (ipSettingsToggle != null && ipSettingsPanelContainer != null) {
            ipSettingsToggle.setOnClickListener(v -> {
                boolean expanded = ipSettingsPanelContainer.getVisibility() == View.VISIBLE;
                ipSettingsPanelContainer.setVisibility(expanded ? View.GONE : View.VISIBLE);
                ipSettingsToggle.setText(context.getString(
                        expanded ? R.string.wifi_ip_settings : R.string.wifi_ip_settings_hide));
            });
            if (staticMode) {
                ipSettingsPanelContainer.setVisibility(View.VISIBLE);
                ipSettingsToggle.setText(R.string.wifi_ip_settings_hide);
            }
        }

        EditText focusField = requirePassword && password != null ? password : connectAnchor;
        if (focusField != null) {
            focusField.setShowSoftInputOnFocus(false);
        }
        if (staticMode) {
            EditText staticFocus = ipSettingsPanel.getFirstFocusField();
            if (staticFocus != null) {
                focusField = staticFocus;
            }
        }
        EditText resolvedFocus = focusField != null ? focusField : connectAnchor;
        if (resolvedFocus == null) {
            resolvedFocus = connectAnchor;
        }
        return new JoinFormState(
                requirePassword ? password : null,
                resolvedFocus,
                ipSettingsPanel,
                ipSettingsPanelContainer);
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
            @NonNull String ssid,
            boolean requirePassword,
            @Nullable EditText passwordField,
            @Nullable JoinFormState form,
            @Nullable FrostDialog.Handle handle,
            @NonNull OnJoinSubmitListener listener) {
        String password = null;
        if (requirePassword) {
            if (passwordField == null) {
                return;
            }
            password = passwordField.getText() != null ? passwordField.getText().toString().trim() : "";
            if (TextUtils.isEmpty(password)) {
                ToastUtils.showShort(R.string.wifi_toast_password_required);
                return;
            }
        }

        WifiIpConfig ipConfig = readIpConfig(form);
        if (ipConfig == null) {
            return;
        }

        listener.onJoinSubmit(ssid, password, ipConfig);
        if (handle != null) {
            handle.dismiss();
        } else {
            FrostDialog.dismiss();
        }
    }

    @Nullable
    private static WifiIpConfig readIpConfig(@Nullable JoinFormState form) {
        if (form == null || !form.isIpSettingsExpanded()) {
            return WifiIpConfig.dhcp();
        }
        return form.ipSettingsPanel.readConfig();
    }
}
