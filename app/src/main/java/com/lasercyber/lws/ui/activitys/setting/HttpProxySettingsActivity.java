package com.lasercyber.lws.ui.activitys.setting;

import android.text.TextUtils;
import android.view.View;
import android.widget.RadioButton;
import android.widget.TextView;

import androidx.core.content.ContextCompat;

import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ime.field.ImeFieldType;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseActivity;
import com.lasercyber.lws.ui.common.config.DeviceApiOriginConfig;
import com.lasercyber.lws.ui.common.config.RetrofitClient;
import com.lasercyber.lws.ui.common.network.proxy.HttpProxySettings;
import com.lasercyber.lws.ui.common.network.proxy.HttpProxySettingsStore;
import com.lasercyber.lws.ui.common.network.proxy.NetworkHttpClientProvider;
import com.lasercyber.lws.ui.common.network.proxy.ProxyAuthType;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.component.dialog.FrostNumericInputDialog;
import com.lasercyber.lws.ui.component.dialog.FrostTextInputDialog;
import com.lasercyber.lws.ui.databinding.ActivityHttpProxySettingsBinding;
import com.lasercyber.lws.ui.network.ws.DeviceWebSocketConnectionManager;

import java.io.IOException;
import java.util.List;

import okhttp3.HttpUrl;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.ResponseBody;

public class HttpProxySettingsActivity extends BaseActivity<ActivityHttpProxySettingsBinding> {

    private static final String PASSWORD_MASK = "••••••";

    private HttpProxySettingsStore settingsStore;
    private boolean suppressAuthCallback;
    private String hostValue = "";
    private String portValue = "";
    private String usernameValue = "";
    private String passwordValue = "";

    @Override
    protected int getLayoutId() {
        return R.layout.activity_http_proxy_settings;
    }

    @Override
    protected void initView() {
        settingsStore = new HttpProxySettingsStore(this);
        binding.goToUpPage.setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            finish();
        });
        binding.authTypeSetting.setOnCheckedChangeListener((group, checkedId) -> {
            if (suppressAuthCallback) {
                return;
            }
            updateAuthFieldsVisibility(checkedId == R.id.auth_basic);
        });
        binding.btnTestConnection.setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            testConnection();
        });
        binding.btnSave.setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            saveSettings();
        });
        binding.tvProxyHost.setOnClickListener(v -> openHostDialog());
        binding.tvProxyPort.setOnClickListener(v -> openPortDialog());
        binding.tvProxyUsername.setOnClickListener(v -> openUsernameDialog());
        binding.tvProxyPassword.setOnClickListener(v -> openPasswordDialog());
        renderSettings(settingsStore.load());
    }

    @Override
    protected void initData() {
    }

    private void openHostDialog() {
        GlobalSoundManager.playClickSound();
        FrostTextInputDialog.show(
                this,
                R.string.http_proxy_host,
                hostValue,
                ImeFieldType.Text,
                input -> {
                    hostValue = input;
                    updateHostDisplay();
                    return true;
                });
    }

    private void openPortDialog() {
        GlobalSoundManager.playClickSound();
        FrostNumericInputDialog.show(
                this,
                FrostNumericInputDialog.Config.builder(getString(R.string.http_proxy_port))
                        .integerNumberInput()
                        .minValue(1)
                        .maxValue(65535)
                        .defaultInput(portValue)
                        .showStepper(false)
                        .build(),
                input -> {
                    portValue = input;
                    updatePortDisplay();
                    return true;
                });
    }

    private void openUsernameDialog() {
        GlobalSoundManager.playClickSound();
        FrostTextInputDialog.show(
                this,
                R.string.http_proxy_username,
                usernameValue,
                ImeFieldType.Text,
                input -> {
                    usernameValue = input;
                    updateUsernameDisplay();
                    return true;
                });
    }

    private void openPasswordDialog() {
        GlobalSoundManager.playClickSound();
        FrostTextInputDialog.show(
                this,
                R.string.http_proxy_password,
                passwordValue,
                ImeFieldType.WiFi,
                input -> {
                    passwordValue = input;
                    updatePasswordDisplay();
                    return true;
                });
    }

    private void renderSettings(HttpProxySettings settings) {
        binding.switchEnableProxy.setChecked(settings.enabled);
        hostValue = settings.host != null ? settings.host : "";
        portValue = settings.port > 0 ? String.valueOf(settings.port) : "";
        usernameValue = settings.username != null ? settings.username : "";
        passwordValue = settings.password != null ? settings.password : "";
        suppressAuthCallback = true;
        if (settings.authType == ProxyAuthType.BASIC) {
            binding.authTypeSetting.check(R.id.auth_basic);
        } else {
            binding.authTypeSetting.check(R.id.auth_none);
        }
        suppressAuthCallback = false;
        updateHostDisplay();
        updatePortDisplay();
        updateUsernameDisplay();
        updatePasswordDisplay();
        updateAuthFieldsVisibility(settings.authType == ProxyAuthType.BASIC);
    }

    private void updateHostDisplay() {
        updateValueOrHint(binding.tvProxyHost, hostValue, R.string.http_proxy_host_hint);
    }

    private void updatePortDisplay() {
        updateValueOrHint(binding.tvProxyPort, portValue, R.string.http_proxy_port_hint);
    }

    private void updateUsernameDisplay() {
        updateValueOrHint(binding.tvProxyUsername, usernameValue, R.string.http_proxy_username);
    }

    private void updatePasswordDisplay() {
        if (TextUtils.isEmpty(passwordValue)) {
            binding.tvProxyPassword.setText(R.string.http_proxy_password);
            binding.tvProxyPassword.setTextColor(
                    ContextCompat.getColor(this, R.color.frost_text_secondary));
        } else {
            binding.tvProxyPassword.setText(PASSWORD_MASK);
            binding.tvProxyPassword.setTextColor(
                    ContextCompat.getColor(this, R.color.frost_text_primary));
        }
    }

    private void updateValueOrHint(TextView view, String value, int hintRes) {
        if (TextUtils.isEmpty(value)) {
            view.setText(hintRes);
            view.setTextColor(ContextCompat.getColor(this, R.color.frost_text_secondary));
        } else {
            view.setText(value);
            view.setTextColor(ContextCompat.getColor(this, R.color.frost_text_primary));
        }
    }

    private void updateAuthFieldsVisibility(boolean basicAuth) {
        int visibility = basicAuth ? View.VISIBLE : View.GONE;
        binding.rowUsername.setVisibility(visibility);
        binding.dividerUsername.setVisibility(visibility);
        binding.rowPassword.setVisibility(visibility);
        binding.dividerPassword.setVisibility(visibility);
    }

    private HttpProxySettings readFormSettings() {
        HttpProxySettings settings = new HttpProxySettings();
        settings.enabled = binding.switchEnableProxy.isChecked();
        settings.host = hostValue;
        settings.port = parsePort(portValue);
        RadioButton checked = binding.authTypeSetting.findViewById(binding.authTypeSetting.getCheckedRadioButtonId());
        int authIndex = checked == null ? 0 : binding.authTypeSetting.indexOfChild(checked);
        settings.authType = authIndex == 1 ? ProxyAuthType.BASIC : ProxyAuthType.NONE;
        settings.username = usernameValue;
        settings.password = passwordValue;
        return settings;
    }

    private void saveSettings() {
        HttpProxySettings settings = readFormSettings();
        String validationError = validate(settings);
        if (validationError != null) {
            ToastUtils.showShort(validationMessage(validationError));
            return;
        }
        settingsStore.save(settings);
        RetrofitClient.invalidateOnProxyChange();
        DeviceWebSocketConnectionManager.getInstance().connectOrReconnect("proxy_settings_changed");
        ToastUtils.showShort(R.string.http_proxy_save_success);
        finish();
    }

    private void testConnection() {
        HttpProxySettings settings = readFormSettings();
        if (settings.enabled) {
            String validationError = validate(settings);
            if (validationError != null) {
                ToastUtils.showShort(validationMessage(validationError));
                return;
            }
        }
        HttpUrl probeBase = resolveProbeBase();
        if (probeBase == null) {
            ToastUtils.showShort(R.string.http_proxy_test_no_origin);
            return;
        }
        binding.btnTestConnection.setEnabled(false);
        binding.btnSave.setEnabled(false);
        ThreadPoolManager.getExecutor().execute(() -> {
            boolean ok = false;
            String message;
            try {
                HttpUrl probeUrl = DeviceApiOriginConfig.rootProbeHttpUrl(probeBase);
                OkHttpClient client = settings.enabled
                        ? NetworkHttpClientProvider.getInstance().getProbeClientWithSettings(settings, null)
                        : NetworkHttpClientProvider.getInstance().getProbeClientWithSettings(
                                HttpProxySettings.disabled(), null);
                Request request = new Request.Builder().url(probeUrl).get().build();
                try (Response response = client.newCall(request).execute()) {
                    ResponseBody body = response.body();
                    if (body != null) {
                        body.string();
                    }
                    ok = response.isSuccessful() || response.code() < 500;
                }
                message = ok
                        ? getString(R.string.http_proxy_test_success)
                        : getString(R.string.http_proxy_test_failed);
            } catch (IOException ex) {
                message = getString(R.string.http_proxy_test_failed)
                        + (ex.getMessage() != null ? ": " + ex.getMessage() : "");
            }
            boolean finalOk = ok;
            String finalMessage = message;
            handler.post(() -> {
                binding.btnTestConnection.setEnabled(true);
                binding.btnSave.setEnabled(true);
                if (finalOk) {
                    ToastUtils.showShort(finalMessage);
                } else {
                    ToastUtils.showLong(finalMessage);
                }
            });
        });
    }

    private HttpUrl resolveProbeBase() {
        HttpUrl pinned = DeviceApiOriginConfig.getPinnedBase();
        if (pinned != null) {
            return pinned;
        }
        List<HttpUrl> candidates = DeviceApiOriginConfig.orderedCandidateBases();
        return candidates.isEmpty() ? null : candidates.get(0);
    }

    private static String validate(HttpProxySettings settings) {
        if (!settings.enabled) {
            return null;
        }
        if (TextUtils.isEmpty(settings.host.trim())) {
            return "host_required";
        }
        if (settings.port <= 0 || settings.port > 65535) {
            return "port_invalid";
        }
        if (settings.authType == ProxyAuthType.BASIC && TextUtils.isEmpty(settings.username.trim())) {
            return "username_required";
        }
        return null;
    }

    private String validationMessage(String code) {
        return switch (code) {
            case "host_required" -> getString(R.string.http_proxy_validation_host_required);
            case "port_invalid" -> getString(R.string.http_proxy_validation_port_invalid);
            case "username_required" -> getString(R.string.http_proxy_validation_username_required);
            default -> code;
        };
    }

    private static int parsePort(String raw) {
        if (TextUtils.isEmpty(raw)) {
            return 0;
        }
        try {
            return Integer.parseInt(raw.trim());
        } catch (NumberFormatException ignored) {
            return 0;
        }
    }
}
