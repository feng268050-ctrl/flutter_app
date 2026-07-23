package com.lasercyber.lws.ui.common.upgrade;

import android.app.Activity;
import android.content.Context;
import android.os.Build;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.lifecycle.ViewModelProvider;
import androidx.lifecycle.ViewModelStoreOwner;

import com.lasercyber.lws.ui.MainActivity;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.setting.model.DeviceInfoViewModel;
import com.lasercyber.lws.ui.bean.entity.DeviceInfo;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.bean.event.DeviceUpgradeEvent;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.DeviceUpgradeConstant;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.enums.DeviceUpgradeEventTypeEnum;
import com.lasercyber.lws.ui.common.enums.UpgradeStatusEnum;
import com.lasercyber.lws.ui.common.handler.DeviceStatusTaskHandler;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusStartupState;
import com.lasercyber.lws.ui.common.utils.UpgradeFileReaderUtils;
import com.lasercyber.lws.ui.component.dialog.GlobalDialogUtil;

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;
import org.greenrobot.eventbus.ThreadMode;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Objects;

/**
 * Home-screen only: detect APK-bundled control-card firmware and prompt user before Modbus OTA.
 */
public final class BundledFirmwareBootstrap {

    private static final String TAG = LogTAGConstant.BundledFirmwareBootstrap;
    private static final String ASSET_DIR = "firmware";
    private static final BundledFirmwareBootstrap INSTANCE = new BundledFirmwareBootstrap();

    private volatile boolean dialogVisible;
    private volatile boolean awaitingBundledResult;
    private volatile String activeBundledFileName;
    private File activeTempFirmwareFile;
    private Activity hostActivity;
    @Nullable
    private Runnable sessionCompleteCallback;
    private volatile boolean sessionCompleteDelivered;

    private BundledFirmwareBootstrap() {
    }

    /** Dev {@code make sync-firmware}: OTA from adb-pushed {@code .bin} (no confirm, no version gate). */
    public static void startSyncFirmwareUpgrade(@NonNull Activity activity, @NonNull File firmwareFile) {
        if (activity.isFinishing()) {
            return;
        }
        if (Looper.myLooper() != Looper.getMainLooper()) {
            activity.runOnUiThread(() -> startSyncFirmwareUpgrade(activity, firmwareFile));
            return;
        }
        INSTANCE.startSyncFirmwareUpgradeInternal(activity, firmwareFile);
    }

    private void startSyncFirmwareUpgradeInternal(@NonNull Activity activity, @NonNull File firmwareFile) {
        if (activity.isFinishing()) {
            return;
        }
        if (awaitingBundledResult || dialogVisible || FirmwareUpgradeCoordinator.isBusy()) {
            Log.w(TAG, "sync firmware skipped: upgrade session already active");
            return;
        }
        if (isProbablyEmulator()) {
            Log.i(TAG, "skip sync firmware on emulator");
            return;
        }
        if (!ModbusStartupState.isAvailable()) {
            Log.w(TAG, "sync firmware skipped: modbus unavailable");
            return;
        }
        if (!firmwareFile.isFile()) {
            Log.w(TAG, "sync firmware skipped: not a file " + firmwareFile.getAbsolutePath());
            return;
        }
        String fileName = firmwareFile.getName();
        if (!BundledFirmwareVersionGate.isValidFirmwareFileName(fileName)) {
            Log.w(TAG, "sync firmware skipped: invalid firmware file name " + fileName);
            return;
        }
        startFirmwareUpgrade(activity, firmwareFile, fileName, true, false);
    }

    public static void onHostDestroyed(MainActivity activity) {
        BundledFirmwareBootstrap inst = INSTANCE;
        if (inst.hostActivity != activity
                && !inst.dialogVisible
                && !inst.awaitingBundledResult
                && inst.sessionCompleteCallback == null) {
            return;
        }
        if (inst.hostActivity == activity) {
            inst.hostActivity = null;
        }
        if (inst.dialogVisible || inst.awaitingBundledResult || inst.sessionCompleteCallback != null) {
            GlobalDialogUtil.closeDialog();
            inst.finishBundledUpgradeSession(false);
            inst.deliverSessionComplete();
        }
    }

    public static void checkAndPromptIfNeeded(MainActivity activity) {
        com.lasercyber.lws.ui.common.home.HomePromptQueue.get().onHomeResume(activity);
    }

    public static boolean isHomePromptEligible(@Nullable MainActivity activity) {
        return activity != null && !activity.isFinishing() && INSTANCE.evaluateHomePrompt(activity) != null;
    }

    /** Called when confirm / progress / result flow ends and the auto-dialog queue may continue. */
    public static boolean showHomePrompt(@NonNull MainActivity activity, @NonNull Runnable onSessionComplete) {
        HomePromptOffer offer = INSTANCE.evaluateHomePrompt(activity);
        if (offer == null) {
            return false;
        }
        return INSTANCE.presentHomePrompt(activity, offer, onSessionComplete);
    }

    private static final class HomePromptOffer {
        private final String bundledName;
        private final String title;
        private final String message;

        private HomePromptOffer(String bundledName, String title, String message) {
            this.bundledName = bundledName;
            this.title = title;
            this.message = message;
        }
    }

    @Nullable
    private HomePromptOffer evaluateHomePrompt(@NonNull MainActivity activity) {
        if (activity.isFinishing()) {
            return null;
        }
        if (awaitingBundledResult || dialogVisible || FirmwareUpgradeCoordinator.isBusy()) {
            return null;
        }
        if (isProbablyEmulator()) {
            Log.i(TAG, "skip bundled firmware check on emulator");
            return null;
        }
        if (!ModbusStartupState.isAvailable()) {
            return null;
        }
        DeviceStatus deviceStatus = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        if (deviceStatus == null
                || deviceStatus.getHardwareVersion() == null
                || deviceStatus.getSoftwareVersion() == null) {
            return null;
        }
        String bundledName = discoverBundledFirmwareFileName(activity);
        if (bundledName == null) {
            return null;
        }
        if (!BundledFirmwareVersionGate.isUpgradeCandidate(
                bundledName,
                deviceStatus.getHardwareVersion(),
                deviceStatus.getSoftwareVersion())) {
            return null;
        }
        Integer bundledSw = UpgradeFileReaderUtils.getFileSoftwareVersion(bundledName);
        Integer deviceSw = deviceStatus.getSoftwareVersion();
        String message = activity.getString(
                R.string.bundled_firmware_dialog_message,
                String.valueOf(deviceSw),
                String.valueOf(bundledSw));
        return new HomePromptOffer(
                bundledName,
                activity.getString(R.string.bundled_firmware_dialog_title),
                message);
    }

    private boolean presentHomePrompt(
            @NonNull MainActivity activity,
            @NonNull HomePromptOffer offer,
            @NonNull Runnable onSessionComplete) {
        hostActivity = activity;
        bindSessionComplete(onSessionComplete);
        dialogVisible = true;
        boolean shown = GlobalDialogUtil.showBundledFirmwareUpgradeDialog(
                activity,
                offer.title,
                offer.message,
                activity.getString(R.string.ok_text),
                activity.getString(R.string.cancel_text),
                () -> {
                    dialogVisible = false;
                    deliverSessionComplete();
                },
                () -> {
                    dialogVisible = false;
                    startBundledUpgrade(activity, offer.bundledName);
                },
                null);
        if (!shown) {
            dialogVisible = false;
            deliverSessionComplete();
        }
        return shown;
    }

    private void bindSessionComplete(@NonNull Runnable onSessionComplete) {
        sessionCompleteCallback = onSessionComplete;
        sessionCompleteDelivered = false;
    }

    private void deliverSessionComplete() {
        if (sessionCompleteDelivered) {
            return;
        }
        Runnable callback = sessionCompleteCallback;
        if (callback == null) {
            return;
        }
        sessionCompleteDelivered = true;
        sessionCompleteCallback = null;
        callback.run();
    }

    private void startBundledUpgrade(MainActivity activity, String bundledAssetName) {
        if (!FirmwareUpgradeCoordinator.canStartFirmwareUpgrade()) {
            Log.w(TAG, "startBundledUpgrade: coordinator busy");
            deliverSessionComplete();
            return;
        }
        File tempFile;
        try {
            tempFile = copyBundledFirmwareToCache(activity, bundledAssetName);
        } catch (IOException e) {
            Log.e(TAG, "copy bundled firmware failed", e);
            deliverSessionComplete();
            return;
        }
        startFirmwareUpgrade(activity, tempFile, bundledAssetName, false, true);
    }

    private void startFirmwareUpgrade(
            @NonNull Activity activity,
            @NonNull File firmwareFile,
            @NonNull String displayFileName,
            boolean skipSameVersionCheck,
            boolean deleteFileOnCleanup) {
        if (!FirmwareUpgradeCoordinator.canStartFirmwareUpgrade()) {
            Log.w(TAG, "startFirmwareUpgrade: coordinator busy");
            if (deleteFileOnCleanup) {
                deleteFileQuietly(firmwareFile);
            }
            deliverSessionComplete();
            return;
        }
        hostActivity = activity;
        activeBundledFileName = displayFileName;
        activeTempFirmwareFile = deleteFileOnCleanup ? firmwareFile : null;
        awaitingBundledResult = true;
        FirmwareUpgradeCoordinator.markBundledUpgradeStarted();
        if (!EventBus.getDefault().isRegistered(this)) {
            EventBus.getDefault().register(this);
        }
        GlobalDialogUtil.showStatusDialog(
                activity,
                3,
                activity.getString(R.string.bundled_firmware_upgrading_title),
                activity.getString(R.string.bundled_firmware_upgrading_message));
        Log.i(TAG, "start firmware upgrade file=" + displayFileName
                + " path=" + firmwareFile.getAbsolutePath()
                + " skipSameVersionCheck=" + skipSameVersionCheck);
        BinUtil.binFileConvert(firmwareFile, skipSameVersionCheck);
    }

    private static void deleteFileQuietly(@Nullable File file) {
        if (file != null && file.exists() && !file.delete()) {
            Log.w(TAG, "failed to delete temp firmware file: " + file.getAbsolutePath());
        }
    }

    @Subscribe(threadMode = ThreadMode.MAIN_ORDERED)
    public void onDeviceUpgradeEvent(DeviceUpgradeEvent event) {
        if (!awaitingBundledResult) {
            return;
        }
        if (event == null || event.getEventType() != DeviceUpgradeEventTypeEnum.CONTROLLER_UPGRADE) {
            return;
        }
        UpgradeStatusEnum status = event.getUpgradeStatus();
        if (UpgradeStatusEnum.UPGRADE_ING.equals(status)) {
            GlobalDialogUtil.updateFirmwareUpgradeProgress(0);
            return;
        }
        if (UpgradeStatusEnum.UPGRADE_FAIL.equals(status) || UpgradeStatusEnum.UPGRADE_TIME_OUT.equals(status)) {
            Integer err = event.getErrorCode();
            if (Objects.equals(err, DeviceUpgradeConstant.VERSION_SAME_NOT_NEED_UPGRADE_ERROR)) {
                dismissUpgradeProgress();
                finishBundledUpgradeSession(false);
                deliverSessionComplete();
                return;
            }
            if (isProbablyEmulator()) {
                DeviceStatusTaskHandler.controllerUpgradeEnd();
                dismissUpgradeProgress();
                finishBundledUpgradeSession(false);
                deliverSessionComplete();
                return;
            }
            DeviceStatusTaskHandler.controllerUpgradeEnd();
            showUpgradeFailed(hostActivity, this::deliverSessionComplete);
            finishBundledUpgradeSession(false);
            return;
        }
        if (UpgradeStatusEnum.UPGRADE_SUCCESS.equals(status)) {
            GlobalDialogUtil.updateFirmwareUpgradeProgress(100);
            persistFirmwareVersionAfterSuccess(hostActivity);
            if (hostActivity != null && !hostActivity.isFinishing()) {
                showUpgradeResult(
                        hostActivity,
                        1,
                        hostActivity.getString(R.string.bundled_firmware_success_title),
                        hostActivity.getString(R.string.bundled_firmware_success_message),
                        this::deliverSessionComplete);
            } else {
                dismissUpgradeProgress();
                deliverSessionComplete();
            }
            finishBundledUpgradeSession(true);
        }
    }

    private static void dismissUpgradeProgress() {
        GlobalDialogUtil.closeDialog();
    }

    private void showUpgradeFailed(@Nullable Activity activity, @Nullable Runnable onDismissed) {
        if (activity == null) {
            if (onDismissed != null) {
                onDismissed.run();
            }
            return;
        }
        showUpgradeResult(
                activity,
                0,
                activity.getString(R.string.bundled_firmware_failed_title),
                activity.getString(R.string.bundled_firmware_failed_message),
                onDismissed);
    }

    /**
     * Reuse the in-flight progress dialog when possible (see {@link GlobalDialogUtil#showStatusDialog}).
     */
    private static void showUpgradeResult(
            Activity activity,
            int statusKind,
            String title,
            String message,
            @Nullable Runnable onDismissed) {
        if (activity != null && !activity.isFinishing()) {
            GlobalDialogUtil.dismissBlockingStatusAndShowResult(
                    activity, statusKind, title, message, onDismissed);
        } else {
            dismissUpgradeProgress();
            if (onDismissed != null) {
                onDismissed.run();
            }
        }
    }

    private void persistFirmwareVersionAfterSuccess(@Nullable Activity activity) {
        Integer targetSw = UpgradeFileReaderUtils.getFileSoftwareVersion(activeBundledFileName);
        if (targetSw == null) {
            return;
        }
        DeviceStatus deviceStatus = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        String firmwareVersion = String.valueOf(targetSw);
        if (deviceStatus != null && deviceStatus.getSoftwareVersion() != null
                && deviceStatus.getSoftwareVersion() >= targetSw) {
            firmwareVersion = String.valueOf(deviceStatus.getSoftwareVersion());
        }
        DeviceInfo deviceInfo = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_INFO_KEY);
        if (deviceInfo == null) {
            deviceInfo = new DeviceInfo();
        }
        deviceInfo.setFirmwareVersion(firmwareVersion);
        MemoryCacheManager.getInstance().putSerializableNoNotice(CacheKey.DEVICE_INFO_KEY, deviceInfo);
        if (activity != null && !activity.isFinishing() && activity instanceof ViewModelStoreOwner) {
            ViewModelStoreOwner owner = (ViewModelStoreOwner) activity;
            DeviceInfoViewModel viewModel = new ViewModelProvider(owner).get(DeviceInfoViewModel.class);
            viewModel.init(activity);
            viewModel.updateOrAddInfo(deviceInfo, activity);
            viewModel.requestData();
        }
    }

    private void finishBundledUpgradeSession(boolean success) {
        awaitingBundledResult = false;
        activeBundledFileName = null;
        hostActivity = null;
        FirmwareUpgradeCoordinator.markBundledUpgradeEnded();
        if (EventBus.getDefault().isRegistered(this)) {
            EventBus.getDefault().unregister(this);
        }
        deleteTempFirmwareFile();
        Log.i(TAG, "bundled firmware session ended success=" + success);
    }

    private void deleteTempFirmwareFile() {
        File file = activeTempFirmwareFile;
        activeTempFirmwareFile = null;
        if (file != null && file.exists() && !file.delete()) {
            Log.w(TAG, "failed to delete temp firmware file: " + file.getAbsolutePath());
        }
    }

    static String discoverBundledFirmwareFileName(Context context) {
        try {
            String[] names = context.getAssets().list(ASSET_DIR);
            if (names == null || names.length == 0) {
                return null;
            }
            String match = null;
        for (String name : names) {
            if (name == null || !BundledFirmwareVersionGate.isValidFirmwareFileName(name)) {
                continue;
            }
            if (match != null && !match.equals(name)) {
                Log.w(TAG, "multiple bundled firmware assets; refusing");
                return null;
            }
            match = name;
        }
            return match;
        } catch (IOException e) {
            Log.w(TAG, "list bundled firmware assets failed", e);
            return null;
        }
    }

    private static File copyBundledFirmwareToCache(Context context, String assetFileName) throws IOException {
        // Keep original LSW01H####S####.bin name — ControllerUpgradeHandler parses HW/SW from file.getName().
        File dest = new File(context.getCacheDir(), assetFileName);
        try (InputStream in = context.getAssets().open(ASSET_DIR + "/" + assetFileName);
             FileOutputStream out = new FileOutputStream(dest)) {
            byte[] buffer = new byte[8192];
            int read;
            while ((read = in.read(buffer)) != -1) {
                out.write(buffer, 0, read);
            }
            out.flush();
        }
        return dest;
    }

    static boolean isProbablyEmulator() {
        String fp = Build.FINGERPRINT != null ? Build.FINGERPRINT : "";
        String model = Build.MODEL != null ? Build.MODEL : "";
        String manu = Build.MANUFACTURER != null ? Build.MANUFACTURER : "";
        String brand = Build.BRAND != null ? Build.BRAND : "";
        String device = Build.DEVICE != null ? Build.DEVICE : "";
        String hw = Build.HARDWARE != null ? Build.HARDWARE : "";
        String product = Build.PRODUCT != null ? Build.PRODUCT : "";
        return fp.startsWith("generic")
                || fp.startsWith("unknown")
                || model.contains("google_sdk")
                || model.contains("Emulator")
                || model.contains("Android SDK built for x86")
                || model.contains("sdk_gphone")
                || manu.contains("Genymotion")
                || (brand.startsWith("generic") && device.startsWith("generic"))
                || "google_sdk".equals(Build.PRODUCT)
                || "goldfish".equals(hw)
                || "ranchu".equals(hw)
                || product.contains("sdk_gphone")
                || product.contains("emulator")
                || product.contains("simulator");
    }
}
