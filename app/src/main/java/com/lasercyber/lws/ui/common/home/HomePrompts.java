package com.lasercyber.lws.ui.common.home;

import android.content.Intent;
import android.graphics.Bitmap;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.BuildConfig;
import com.lasercyber.lws.ui.MainActivity;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.setting.DeviceSettingActivity;
import com.lasercyber.lws.ui.common.config.AppRuntimeEnvironment;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.device.DeviceRemoteLockPolicy;
import com.lasercyber.lws.ui.common.device.DeviceRemoteLockStore;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.upgrade.AutoCheckOtaUpdateSettings;
import com.lasercyber.lws.ui.common.upgrade.BundledFirmwareBootstrap;
import com.lasercyber.lws.ui.common.upgrade.OtaUpdateManifestService;
import com.lasercyber.lws.ui.common.upgrade.OtaUpgradeNavigation;
import com.lasercyber.lws.ui.common.utils.DeviceQRCodeUtils;
import com.lasercyber.lws.ui.common.utils.WifiStatusUtils;
import com.lasercyber.lws.ui.common.version.SemanticVersionHelper;
import com.lasercyber.lws.ui.component.dialog.FrostDialog;
import com.lasercyber.lws.ui.component.dialog.GlobalDialogUtil;

import java.util.concurrent.atomic.AtomicBoolean;

final class WifiInitHomePrompt implements HomePrompt {

    static final String ID = "wifi_init";

    @Override
    @NonNull
    public String id() {
        return ID;
    }

    @Override
    public int order() {
        return 10;
    }

    @Override
    public boolean isEligible(@NonNull MainActivity activity) {
        return HomePromptQueue.get().isFirstHomeResumeSeen()
                && !AppRuntimeEnvironment.isWifiInitializationCompleted()
                && !WifiStatusUtils.hasUsableWifiConnection(activity.getApplicationContext());
    }

    @Override
    public void markConsumedForSession(@NonNull MainActivity activity) {
        AppRuntimeEnvironment.markWifiInitializationCompleted(activity);
    }

    @Override
    public boolean show(@NonNull MainActivity activity, @NonNull Runnable onComplete) {
        return GlobalDialogUtil.showWifiInitializationDialog(
                activity,
                activity.getString(R.string.wifi_init_dialog_title),
                activity.getString(R.string.wifi_init_dialog_message),
                activity.getString(R.string.ok_text),
                activity.getString(R.string.cancel_text),
                GlobalDialogUtil::dismissCurrentDialog,
                () -> {
                    Intent intent = new Intent(activity, DeviceSettingActivity.class);
                    intent.putExtra(DeviceSettingActivity.EXTRA_INITIAL_TAB_INDEX,
                            DeviceSettingActivity.TAB_INDEX_NETWORK);
                    intent.putExtra(DeviceSettingActivity.EXTRA_OPEN_WIRELESS_NETWORK, true);
                    activity.startActivity(intent);
                },
                onComplete);
    }
}

final class RemoteLockHomePrompt implements HomePrompt {

    static final String ID = "remote_lock";

    private static volatile boolean shownThisResumeCycle;

    static void resetResumeCycle() {
        shownThisResumeCycle = false;
    }

    @Override
    @NonNull
    public String id() {
        return ID;
    }

    @Override
    public int order() {
        return 20;
    }

    @Override
    public boolean isEligible(@NonNull MainActivity activity) {
        return DeviceRemoteLockStore.isLocked() && !shownThisResumeCycle;
    }

    @Override
    public boolean show(@NonNull MainActivity activity, @NonNull Runnable onComplete) {
        boolean shown = DeviceRemoteLockPolicy.showRemoteLockDialog(activity, onComplete);
        if (shown) {
            shownThisResumeCycle = true;
        }
        return shown;
    }
}

final class BundledFirmwareHomePrompt implements HomePrompt {

    static final String ID = "bundled_firmware";

    private volatile boolean dismissedThisSession;

    @Override
    @NonNull
    public String id() {
        return ID;
    }

    @Override
    public int order() {
        return 40;
    }

    @Override
    public boolean isEligible(@NonNull MainActivity activity) {
        return !dismissedThisSession && BundledFirmwareBootstrap.isHomePromptEligible(activity);
    }

    @Override
    public boolean show(@NonNull MainActivity activity, @NonNull Runnable onComplete) {
        return BundledFirmwareBootstrap.showHomePrompt(activity, () -> {
            dismissedThisSession = true;
            onComplete.run();
        });
    }
}

final class BindDeviceHomePrompt implements HomePrompt {

    static final String ID = "bind_device";

    private volatile boolean dismissedThisSession;

    @Override
    @NonNull
    public String id() {
        return ID;
    }

    @Override
    public int order() {
        return 50;
    }

    @Override
    public void prepare(@NonNull MainActivity activity, @NonNull Runnable onPrepared) {
        HomeDeviceRegistrationProbe.ensurePrepared(activity, onPrepared);
    }

    @Override
    public boolean isEligible(@NonNull MainActivity activity) {
        return !dismissedThisSession
                && AppRuntimeEnvironment.isWifiInitializationCompleted()
                && WifiStatusUtils.hasUsableWifiConnection(activity.getApplicationContext())
                && HomeDeviceRegistrationProbe.getState() == HomeDeviceRegistrationProbe.State.NEED_BIND;
    }

    @Override
    public boolean show(@NonNull MainActivity activity, @NonNull Runnable onComplete) {
        Bitmap qr = DeviceQRCodeUtils.createDeviceIdentityQrCodeV2(280, 280);
        boolean shown = GlobalDialogUtil.showBindDeviceDialog(
                activity,
                activity.getString(R.string.bind_device_dialog_title),
                activity.getString(R.string.bind_device_dialog_subtitle),
                qr,
                () -> {
                    dismissedThisSession = true;
                    HomeDeviceRegistrationProbe.onBindPromptDismissed();
                    onComplete.run();
                });
        return shown;
    }
}

final class AutoOtaUpdateHomePrompt implements HomePrompt {

    private static final String TAG = LogTAGConstant.MainActivity;

    static final String ID = "auto_ota_update";

    private enum PrepareState {
        IDLE,
        LOADING,
        NEED_PROMPT,
        SKIP
    }

    private volatile PrepareState prepareState = PrepareState.IDLE;
    private volatile boolean checkAttemptedThisProcess;
    private volatile boolean dismissedThisSession;
    @Nullable
    private volatile OtaUpdateManifestService.ManifestData cachedManifest;

    @Override
    @NonNull
    public String id() {
        return ID;
    }

    @Override
    public int order() {
        return 60;
    }

    @Override
    public void prepare(@NonNull MainActivity activity, @NonNull Runnable onPrepared) {
        if (!AutoCheckOtaUpdateSettings.isEnabled(activity)
                || checkAttemptedThisProcess
                || !hasWifiPreconditions(activity)) {
            onPrepared.run();
            return;
        }
        HomeDeviceRegistrationProbe.ensurePrepared(activity, () -> {
            if (!HomeDeviceRegistrationProbe.isBindGateCleared()) {
                onPrepared.run();
                return;
            }
            if (prepareState != PrepareState.IDLE) {
                onPrepared.run();
                return;
            }
            prepareState = PrepareState.LOADING;
            checkAttemptedThisProcess = true;
            ThreadPoolManager.getExecutor().execute(() -> {
                PrepareState nextState = PrepareState.SKIP;
                OtaUpdateManifestService.ManifestData manifest = null;
                try {
                    OtaUpdateManifestService.CheckResult check =
                            OtaUpdateManifestService.checkAgainst(BuildConfig.VERSION_NAME);
                    if (check.hasUpdate && check.manifest != null) {
                        manifest = check.manifest;
                        nextState = PrepareState.NEED_PROMPT;
                    }
                } catch (Exception e) {
                    Log.w(TAG, "auto OTA manifest check failed", e);
                }
                cachedManifest = manifest;
                prepareState = nextState;
                activity.runOnUiThread(onPrepared);
            });
        });
    }

    @Override
    public boolean isEligible(@NonNull MainActivity activity) {
        return AutoCheckOtaUpdateSettings.isEnabled(activity)
                && HomePromptQueue.get().isFirstHomeResumeSeen()
                && !dismissedThisSession
                && hasWifiPreconditions(activity)
                && HomeDeviceRegistrationProbe.isBindGateCleared()
                && prepareState == PrepareState.NEED_PROMPT
                && cachedManifest != null;
    }

    @Override
    public boolean show(@NonNull MainActivity activity, @NonNull Runnable onComplete) {
        OtaUpdateManifestService.ManifestData manifest = cachedManifest;
        if (manifest == null) {
            return false;
        }
        String remoteVer = manifest.version;
        String displayVer = SemanticVersionHelper.toCoreVersion(remoteVer);
        if (displayVer == null || displayVer.isEmpty()) {
            displayVer = remoteVer != null ? remoteVer.trim() : "";
        }
        String title = activity.getString(R.string.auto_ota_update_dialog_title);
        String message = activity.getString(R.string.auto_ota_update_dialog_message, displayVer);
        AtomicBoolean completed = new AtomicBoolean();
        Runnable completeOnce = () -> {
            if (!completed.compareAndSet(false, true)) {
                return;
            }
            dismissedThisSession = true;
            onComplete.run();
        };
        FrostDialog.prompt(activity)
                .title(title)
                .message(message)
                .confirmText(R.string.go_to_update)
                .cancelText(R.string.cancel_text)
                .onConfirm(() -> {
                    OtaUpgradeNavigation.startUpgradeActivity(activity, manifest, null);
                    completeOnce.run();
                })
                .onCancel(completeOnce)
                .onDismiss(completeOnce)
                .show();
        return true;
    }

    @Override
    public void markConsumedForSession(@NonNull MainActivity activity) {
        dismissedThisSession = true;
    }

    boolean isCheckAttemptedThisProcessForTest() {
        return checkAttemptedThisProcess;
    }

    @Nullable
    PrepareState getPrepareStateForTest() {
        return prepareState;
    }

    private static boolean hasWifiPreconditions(@NonNull MainActivity activity) {
        return AppRuntimeEnvironment.isWifiInitializationCompleted()
                && WifiStatusUtils.hasUsableWifiConnection(activity.getApplicationContext());
    }
}
