package com.lasercyber.lws.ui.component.dialog;

import android.app.Activity;
import android.content.Context;
import android.view.View;
import android.view.ViewGroup;
import android.widget.EditText;
import android.widget.LinearLayout;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.frostui.dialog.FrostOverlayHost;
import com.lasercyber.lws.ime.ImeAction;
import com.lasercyber.lws.ime.core.ImeConfig;
import com.lasercyber.lws.ime.engine.ImeEnterKeyConfig;
import com.lasercyber.lws.ime.field.ImeFieldType;
import com.lasercyber.lws.ime.interop.ImeOverlayHost;
import com.lasercyber.lws.ime.interop.ImeOverlaySpec;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.network.wifi.WifiIpConfig;
import com.lasercyber.lws.ui.common.network.wifi.WifiLinkSnapshot;

/**
 * IP-only settings dialog with Cancel / Apply actions.
 */
public final class FrostWifiIpSettingsDialog {

    public interface OnApplyListener {
        void onApply(@NonNull WifiIpConfig ipConfig);
    }

    @Nullable
    private final FrostDialog.Handle handle;

    private FrostWifiIpSettingsDialog(@Nullable FrostDialog.Handle handle) {
        this.handle = handle;
    }

    @Nullable
    public static FrostWifiIpSettingsDialog show(
            @NonNull Context context,
            @Nullable WifiIpConfig initialIpConfig,
            @Nullable WifiLinkSnapshot liveLink,
            @NonNull OnApplyListener listener) {
        final FrostWifiIpSettingsPanel[] panelHolder = new FrostWifiIpSettingsPanel[1];
        final FrostDialog.Handle[] handleHolder = new FrostDialog.Handle[1];

        ImeOverlaySpec imeOverlay = ImeOverlaySpec.create(
                ImeConfig.withEnterKey(ImeEnterKeyConfig.done()),
                ImeFieldType.Text,
                action -> action instanceof ImeAction.Done);

        FrostDialog.Handle handle = FrostDialog.prompt(context)
                .title(R.string.wifi_ip_settings)
                .maxHeightDimen(R.dimen.frost_dialog_prompt_max_height)
                .expandBodyScroll(true)
                .imeOverlay(imeOverlay)
                .customBodyView(R.layout.dialog_frost_body_wifi_ip_settings, body -> {
                    pinIpModeScrollFields(body);
                    panelHolder[0] = FrostWifiIpSettingsPanel.bind(
                            context, body, initialIpConfig, liveLink);
                })
                .confirmText(R.string.wifi_apply)
                .cancelText(R.string.cancel_text)
                .autoDismissOnConfirm(false)
                .onConfirm(() -> {
                    FrostWifiIpSettingsPanel panel = panelHolder[0];
                    if (panel == null) {
                        return;
                    }
                    WifiIpConfig config = panel.readConfig();
                    if (config == null) {
                        return;
                    }
                    listener.onApply(config);
                    if (handleHolder[0] != null) {
                        handleHolder[0].dismiss();
                    }
                })
                .show();
        handleHolder[0] = handle;
        if (handle == null) {
            return null;
        }
        Activity activity = FrostOverlayHost.findActivity(context);
        View overlay = handle.getRootView();
        FrostWifiIpSettingsPanel panel = panelHolder[0];
        if (activity != null && overlay != null && panel != null) {
            panel.setOnEditableFieldFocus(
                    field -> ImeOverlayHost.showKeyboardFor(activity, overlay, field));
            panel.setOnHideKeyboard(() -> ImeOverlayHost.hideKeyboardFor(activity, overlay));
            panel.bindImeFocus(activity, overlay);
            EditText focusField = panel.getFirstFocusField();
            if (focusField != null) {
                ImeOverlayHost.scheduleKeyboardAfterDialogShown(activity, overlay, focusField);
            }
        }
        return new FrostWifiIpSettingsDialog(handle);
    }

    /** Keep DHCP/Static row fixed; only address fields scroll when body is height-capped. */
    private static void pinIpModeScrollFields(@NonNull View body) {
        View scroll = body.findViewById(R.id.frost_dialog_wifi_ip_fields_scroll);
        if (scroll == null) {
            return;
        }
        ViewGroup.LayoutParams params = scroll.getLayoutParams();
        if (!(params instanceof LinearLayout.LayoutParams)) {
            return;
        }
        LinearLayout.LayoutParams lp = (LinearLayout.LayoutParams) params;
        lp.height = 0;
        lp.weight = 1f;
        scroll.setLayoutParams(lp);
    }

    public void dismiss() {
        if (handle != null) {
            handle.dismiss();
        }
    }

    public boolean isShowing() {
        return handle != null && handle.isShowing();
    }
}
