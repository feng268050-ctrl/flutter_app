package com.lasercyber.lws.ui.component.dialog;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

/**
 * Legacy WiFi password dialog; delegates to {@link FrostWifiJoinDialog} (DHCP only).
 */
public final class FrostWifiPasswordDialog {

    public interface OnPasswordSubmitListener {
        void onPasswordSubmit(@NonNull String password);
    }

    @Nullable
    private final FrostWifiJoinDialog delegate;

    private FrostWifiPasswordDialog(@Nullable FrostWifiJoinDialog delegate) {
        this.delegate = delegate;
    }

    @Nullable
    public static FrostWifiPasswordDialog show(
            @NonNull Context context,
            @NonNull String ssid,
            @NonNull CharSequence title,
            @NonNull OnPasswordSubmitListener listener) {
        FrostWifiJoinDialog joinDialog = FrostWifiJoinDialog.show(
                context,
                ssid,
                title,
                true,
                null,
                (ignoredSsid, password, ipConfig) -> listener.onPasswordSubmit(password));
        if (joinDialog == null) {
            return null;
        }
        return new FrostWifiPasswordDialog(joinDialog);
    }

    public void dismiss() {
        if (delegate != null) {
            delegate.dismiss();
        }
    }

    public boolean isShowing() {
        return delegate != null && delegate.isShowing();
    }
}
