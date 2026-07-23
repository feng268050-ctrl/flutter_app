package com.lasercyber.lws.ui.activitys.other;

import static com.xuexiang.xutil.XUtil.getContext;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Environment;
import android.os.SystemClock;
import android.util.Log;
import android.view.View;

import androidx.lifecycle.ViewModelProvider;

import com.innohi.YNHAPI;
import com.lasercyber.lws.ui.BuildConfig;
import com.lasercyber.lws.ui.MainActivity;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseActivity;
import com.lasercyber.lws.ui.activitys.setting.model.DeviceInfoViewModel;
import com.lasercyber.lws.ui.bean.entity.DeviceInfo;
import com.lasercyber.lws.ui.bean.event.DeviceUpgradeEvent;
import com.lasercyber.lws.ui.common.constant.DeviceUpgradeConstant;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.SystemSettingConstant;
import com.lasercyber.lws.ui.common.enums.UpgradeStatusEnum;
import com.lasercyber.lws.ui.common.handler.DeviceStatusTaskHandler;
import com.lasercyber.lws.ui.common.upgrade.BinUtil;
import com.lasercyber.lws.ui.common.upgrade.FirmwareUpgradeCoordinator;
import com.lasercyber.lws.ui.common.upgrade.FirmwareUpgradeProgressReporter;
import com.lasercyber.lws.ui.common.upgrade.OtaPackageSha512Verifier;
import com.lasercyber.lws.ui.network.mediamtx.MediaMtxOtaInstaller;
import com.lasercyber.lws.ui.common.upgrade.OtaWsProgressOutbound;
import com.lasercyber.lws.ui.common.upgrade.OtaWsProgressThrottler;
import com.lasercyber.lws.ui.common.utils.UpgradeFileReaderUtils;
import com.lasercyber.lws.ui.common.version.LibraryVersionFilename;
import com.lasercyber.lws.ui.common.version.SemanticVersionHelper;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.component.EquipmentStatusBar;
import com.lasercyber.lws.ui.component.dialog.GlobalDialogUtil;
import com.lasercyber.lws.ui.databinding.ActivityUpgradeBinding;
import com.lasercyber.lws.ui.common.network.proxy.ClientPurpose;
import com.lasercyber.lws.ui.common.network.proxy.NetworkHttpClientProvider;
import com.lasercyber.lws.ui.common.network.proxy.NetworkRoutePolicy;
import com.lasercyber.lws.ui.network.ws.DeviceWebSocketConnectionManager;

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;
import org.greenrobot.eventbus.ThreadMode;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.Charset;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

import cn.hutool.core.util.ObjectUtil;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.ResponseBody;

public class UpgradeActivity extends BaseActivity<ActivityUpgradeBinding> {

    private static final String TAG = LogTAGConstant.UpgradeActivity;
    private static final long SUCCESS_RESTART_DELAY_MS = 3000L;
    /**
     * Average cap for OTA ZIP HTTP→disk throughput so {@code device.update_progress} can be emitted
     * between reads (upstream/coordinator may drop bursty progress). {@code 0} disables throttling.
     */
    private static final long OTA_DOWNLOAD_MAX_BYTES_PER_SECOND = 4L * 1024L * 1024L;
    /** Cap how often we block the download worker retrying {@code download} 0% when WS is offline. */
    private static final int DOWNLOAD_STAGE_ZERO_WS_MAX_TRIES = 5;
    private static final String WS_STAGE_DOWNLOAD = "download";
    private static final String WS_STAGE_PREPARING = "preparing";
    private static final String WS_STAGE_INSTALL_FIRMWARE = "install-firmware";
    private static final String WS_STAGE_INSTALL_APP = "install-app";
    private static final String WS_STAGE_COMPLETED = "completed";
    private static final String WS_STAGE_FAILED = "failed";
    private static String ZIP_PATH = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)+"";

    private static final String UNZIP_DIR = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)+"/update_unzip/";
    // 记录文件总大小（用于计算下载进度）
    private long totalFileSize = 0;
    private final OtaWsProgressOutbound otaWsOutbound = new OtaWsProgressOutbound();
    private final OtaWsProgressThrottler downloadProgressThrottler = new OtaWsProgressThrottler();
    private final OtaWsProgressThrottler firmwareProgressThrottler = new OtaWsProgressThrottler();
    /** Guards download throttler + WS outbound from the download worker thread (same pattern as video upload). */
    private final Object downloadWsProgressLock = new Object();
    /** Posted after silent APK install success; removed in {@link #onDestroy}. */
    private Runnable pendingSuccessRestart;
    /**
     * Deferred {@link #UNZIP_DIR} removal after silent install reads the APK; cleared in {@link #end()}, {@link #onDestroy}.
     */
    private Runnable pendingDelayedOtaUnzipDirCleanup;
    /** Queued after verify + {@link #beginPhaseSystemUpgradeUi()}; removed in {@link #end()} / {@link #onDestroy()}. */
    private Runnable pendingPostVerifyInstall;
    /* 状态：true  升级中，其他操作全部禁止！*/
    private volatile boolean upStatus = false;
    private DeviceInfo deviceInfo;
    private volatile boolean upSucceed = false;
    /** {@code true} only after {@code download} 0% was accepted by the WS layer. */
    private volatile boolean downloadStageZeroWsDelivered = false;
    private int downloadStageZeroWsTries = 0;
    private volatile boolean preparingStageZeroWsDelivered = false;
    private volatile boolean firmwareStageZeroWsDelivered = false;
    private volatile boolean appInstallStageZeroWsDelivered = false;

    private static final long TIMEOUT_MS = 1200000; // 20分钟超时
    private File[] files;
    private Context context;

    private String versionCode;

    private DeviceInfoViewModel devModel;
    private String binFileName;

    /** HTTP(S) ZIP URL from Workers manifest ({@code lws-app} view). */
    private String downloadUrl;

    /** Expected SHA-512 of the downloaded ZIP (128 hex chars); optional extra {@code sha512}. */
    private String expectedPackageSha512;

    private void end(){
        if (pendingPostVerifyInstall != null && handler != null) {
            handler.removeCallbacks(pendingPostVerifyInstall);
            pendingPostVerifyInstall = null;
        }
        cancelPendingDelayedOtaUnzipDirCleanup();
        binding.linearUpgradeBt.setVisibility(View.VISIBLE);
        binding.linearUpgradeSchedule.setVisibility(View.GONE);
        this.upStatus = false;
        this.upSucceed = false;
        FirmwareUpgradeCoordinator.setOtaUpgradeInProgress(false);
        FirmwareUpgradeProgressReporter.setOtaListener(null);
        this.downloadStageZeroWsDelivered = false;
        this.downloadStageZeroWsTries = 0;
        this.preparingStageZeroWsDelivered = false;
        this.firmwareStageZeroWsDelivered = false;
        this.appInstallStageZeroWsDelivered = false;
        otaWsOutbound.resetSession();
        downloadProgressThrottler.reset();
        firmwareProgressThrottler.reset();
        DeviceWebSocketConnectionManager.getInstance().markRemoteUpdateFlowFinished();
    }

    // 超时逻辑Runnable
    private Runnable timeoutRunnable = new Runnable() {
        @Override
        public void run() {
            GlobalDialogUtil.showStatusDialog(context, 0, "Upgrade Timeout", "Upgrade for more than 20 minutes");
            end();
        }
    };

    @Override
    protected void initView() {
        cleanTempFiles();
        if (!EventBus.getDefault().isRegistered(this)) {
            EventBus.getDefault().register(this);
        }
        devModel = new ViewModelProvider(this).get(DeviceInfoViewModel.class);
        context = this;
        FirmwareUpgradeProgressReporter.setOtaListener(this::applyFirmwareTransferProgress);
        //直接跳转到首页
        binding.engineerEquipmentStatus.setOnCallBackListener(new EquipmentStatusBar.OnCallBackListener() {
            @Override
            public void onCallBack() {

                if ( upStatus ) {
                    return;
                }
                Intent intent = new Intent(getContext(), MainActivity.class);
                // 核心：复用目标Activity，清除其上方的所有Activity
                intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
                startActivity(intent);
                // 可选：销毁当前Activity
                finish();
            }
        });
        Intent intent = getIntent();
        String title = SemanticVersionHelper.resolveOtaUpgradeTitle(
                intent.getStringExtra("title"),
                intent.getStringExtra("version"));
        binding.tvTitle.setText(title);
        String content = intent.getStringExtra("content");
        binding.tvUpdate1.setText(content);
        downloadUrl = intent.getStringExtra("downloadUrl");
        expectedPackageSha512 = intent.getStringExtra("sha512");

        /*绑定按钮*/
        binding.btnLater.setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            finish();
        });

        GlobalDialogUtil.closeDialog();
        binding.btnUpdateNow.setOnClickListener(v -> {
            if (upStatus) {
                return;
            }
            //设置超时时间
            handler.postDelayed(timeoutRunnable, TIMEOUT_MS);
            /* 1、提示*/
            upStatus = true;
            FirmwareUpgradeCoordinator.setOtaUpgradeInProgress(true);
            GlobalSoundManager.playClickSound();

            handler.postDelayed(new Runnable() {
                @Override
                public void run() {
                    GlobalDialogUtil.closeDialog();
                }
            }, 3000);
            GlobalDialogUtil.showStatusDialog(context, 2, "Upgrade Has Begun", "Keep the power connected and do not operate.");

            /*2、开始下载解压*/
            ZIP_PATH = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS) + "";
            upgradeSystem();
        });
        boolean remoteAutoStart = intent.getBooleanExtra("remoteAutoStart", false);
        if (remoteAutoStart && !upStatus) {
            handler.post(() -> binding.btnUpdateNow.performClick());
        }
        goToUpPage();
    }

    private void upgradeSystem() {
        binding.linearUpgradeBt.setVisibility(View.GONE);
        binding.linearUpgradeSchedule.setVisibility(View.VISIBLE);
        otaWsOutbound.resetSession();
        downloadProgressThrottler.reset();
        firmwareProgressThrottler.reset();
        downloadStageZeroWsDelivered = false;
        downloadStageZeroWsTries = 0;
        preparingStageZeroWsDelivered = false;
        firmwareStageZeroWsDelivered = false;
        appInstallStageZeroWsDelivered = false;
        beginPhaseDownloadUi();

        Intent intent = getIntent();
        versionCode = intent.getStringExtra("version");
        expectedPackageSha512 = intent.getStringExtra("sha512");
        this.upSucceed = false;

        if (downloadUrl == null || downloadUrl.isEmpty()) {
            GlobalDialogUtil.showStatusDialog(context, 0, "Upgrade Failed", "Missing download URL.");
            reportWsUpdateProgress(WS_STAGE_FAILED, 100, "failed", "Missing download URL", "missing_download_url");
            handler.removeCallbacks(timeoutRunnable);
            end();
            return;
        }

        String verForFile = versionCode != null ? versionCode.trim() : "";
        String zipBase = verForFile.isEmpty() ? "ota" : verForFile.replaceAll("[^a-zA-Z0-9._-]", "_");
        String zipName = zipBase + ".zip";
        ZIP_PATH = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS) + "/" + zipName;

        ThreadPoolManager.getExecutor().execute(() -> {
            ensureDownloadStageZeroWsBeforeHttp();
            try {
                Log.i(TAG, "OTA download start url=" + downloadUrl + " dest=" + ZIP_PATH
                        + " sha512=" + (OtaPackageSha512Verifier.shouldVerify(expectedPackageSha512) ? "required" : "skipped"));
                OkHttpClient client = NetworkHttpClientProvider.getInstance().getClient(
                        ClientPurpose.OTA_DOWNLOAD,
                        NetworkRoutePolicy.INTERNET_PROXY_AWARE,
                        null);
                Request request = new Request.Builder().url(downloadUrl).get().build();
                try (Response response = client.newCall(request).execute()) {
                    if (!response.isSuccessful() || response.body() == null) {
                        throw new IOException("HTTP " + response.code());
                    }
                    ResponseBody body = response.body();
                    long len = body.contentLength();
                    final long downloadTotalBytes = len > 0 ? len : -1L;
                    Log.i(TAG, "OTA download HTTP ok code=" + response.code() + " contentLength=" + len);
                    totalFileSize = len > 0 ? len : 0;
                    try (InputStream inputStream = body.byteStream()) {
                        boolean isWriteSuccess = writeZipToLocal(inputStream, ZIP_PATH, downloadTotalBytes);
                        if (!isWriteSuccess) {
                            throw new IOException("ZIP write failed");
                        }
                    }
                }
                File zipFile = new File(ZIP_PATH);
                try {
                    if (OtaPackageSha512Verifier.shouldVerify(expectedPackageSha512)) {
                        Log.i(TAG, "OTA sha512 verify starting path=" + zipFile.getAbsolutePath()
                                + " size=" + zipFile.length());
                        OtaPackageSha512Verifier.verifyFileMatchesSha512Hex(zipFile, expectedPackageSha512);
                        Log.i(TAG, "OTA sha512 verify OK");
                    } else {
                        Log.i(TAG, "OTA sha512 verify skipped (no manifest sha512)");
                    }
                } catch (IOException verifyEx) {
                    Log.e(TAG, "OTA sha512 verification failed", verifyEx);
                    final String errCode = classifySha512ErrorCode(verifyEx);
                    handler.post(() -> {
                        GlobalDialogUtil.showStatusDialog(context, 0, "Upgrade Failed", "Package integrity check failed.");
                        reportWsUpdateProgress(WS_STAGE_FAILED, 100, "failed", verifyEx.getMessage(), errCode);
                        handler.removeCallbacks(timeoutRunnable);
                        end();
                        cleanTempFiles();
                    });
                    return;
                }
                handler.post(() -> {
                    ensureDownloadStageCompleteWs();
                    beginPhaseSystemUpgradeUi();
                    if (pendingPostVerifyInstall != null && handler != null) {
                        handler.removeCallbacks(pendingPostVerifyInstall);
                    }
                    Log.i(TAG, "OTA install scheduling unzip after preparing stage");
                    pendingPostVerifyInstall = () -> {
                        pendingPostVerifyInstall = null;
                        if (!upStatus || isFinishing()) {
                            return;
                        }
                        // Next frame: unzip/parse can block the main thread; without this pass the status text may never paint.
                        handler.post(() -> {
                            boolean upgradeFlowOwnsUi = false;
                            try {
                                ensurePreparingStageZeroWs();
                                Log.i(TAG, "OTA install unzip start zip=" + ZIP_PATH + " dir=" + UNZIP_DIR);
                                boolean isUnzipSuccess = unzipFile(ZIP_PATH, UNZIP_DIR);
                                if (!isUnzipSuccess) {
                                    throw new IOException("unzip failed");
                                }
                                completePreparingPhase();
                                upgradeFlowOwnsUi = parseUnzipFiles(UNZIP_DIR);
                            } catch (Exception e) {
                                Log.e(TAG, "OTA install unzip/parse failed", e);
                                GlobalDialogUtil.showStatusDialog(context, 0, "Upgrade Failed", "This is the latest version at present.");
                                reportWsUpdateProgress(WS_STAGE_FAILED, 100, "failed", "install preparation failed", "parse_failed");
                                upSucceed = false;
                                end();
                                cleanTempFiles();
                            } finally {
                                handler.removeCallbacks(timeoutRunnable);
                                if (!upgradeFlowOwnsUi) {
                                    end();
                                    if (upSucceed) {
                                        cleanTempFiles();
                                    }
                                }
                            }
                        });
                    };
                    handler.post(pendingPostVerifyInstall);
                });
            } catch (Exception e) {
                Log.e(TAG, "OTA download failed", e);
                handler.post(() -> {
                    GlobalDialogUtil.showStatusDialog(context, 0, "Upgrade Failed", "This is the latest version at present.");
                    reportWsUpdateProgress(WS_STAGE_FAILED, 100, "failed", "HTTP download failed", "download_failed");
                    handler.removeCallbacks(timeoutRunnable);
                    end();
                    cleanTempFiles();
                });
            }
        });
    }

    private void beginPhaseDownloadUi() {
        ensureDownloadStageZeroWs();
        if (binding == null) {
            return;
        }
        binding.updatingStartPower.setProgress(0);
        binding.tvUpgradeStatus.setText(R.string.ota_upgrade_status_downloading);
    }

    /** Last chance on the download worker immediately before HTTP download starts. */
    private void ensureDownloadStageZeroWsBeforeHttp() {
        if (downloadStageZeroWsDelivered) {
            return;
        }
        ensureDownloadStageZeroWs();
        if (!downloadStageZeroWsDelivered) {
            Log.w(TAG, "OTA download 0% WS not delivered before HTTP; starting download anyway");
        }
    }

    /**
     * Sends {@code download} 0% once WS accepts it. Limited tries; never holds
     * {@link #downloadWsProgressLock} during WS I/O. Must complete before the HTTP download starts.
     */
    private boolean ensureDownloadStageZeroWs() {
        if (downloadStageZeroWsDelivered) {
            return true;
        }
        synchronized (downloadWsProgressLock) {
            if (downloadStageZeroWsDelivered) {
                return true;
            }
            if (downloadStageZeroWsTries >= DOWNLOAD_STAGE_ZERO_WS_MAX_TRIES) {
                return false;
            }
            downloadStageZeroWsTries++;
        }
        if (otaWsOutbound.sendMandatory(WS_STAGE_DOWNLOAD, 0, "running", null, null)) {
            synchronized (downloadWsProgressLock) {
                downloadProgressThrottler.markPosted(0);
                downloadStageZeroWsDelivered = true;
            }
            return true;
        }
        Log.w(TAG, "OTA download stage 0% WS not delivered (try " + downloadStageZeroWsTries + ")");
        return false;
    }

    private static String classifySha512ErrorCode(IOException ex) {
        String msg = ex.getMessage();
        if (msg == null) {
            return "sha512_verify_failed";
        }
        if (msg.contains("mismatch")) {
            return "sha512_mismatch";
        }
        if (msg.contains("invalid sha512")) {
            return "sha512_invalid";
        }
        if (msg.contains("package file missing")) {
            return "sha512_package_missing";
        }
        return "sha512_verify_failed";
    }

    private void beginPhaseSystemUpgradeUi() {
        if (binding == null) {
            return;
        }
        binding.updatingStartPower.setProgress(0);
        binding.tvUpgradeStatus.setText(R.string.ota_upgrade_status_preparing);
    }

    /** Immediately before unzip/parse ({@code preparing} work). */
    private boolean ensurePreparingStageZeroWs() {
        if (preparingStageZeroWsDelivered) {
            return true;
        }
        String message = getString(R.string.ota_upgrade_status_preparing);
        if (otaWsOutbound.sendMandatory(WS_STAGE_PREPARING, 0, "running", message, null)) {
            preparingStageZeroWsDelivered = true;
            return true;
        }
        Log.w(TAG, "OTA preparing stage 0% WS not delivered");
        return false;
    }

    private void completePreparingPhase() {
        if (binding != null) {
            binding.updatingStartPower.setProgress(100);
        }
        reportWsUpdateProgressMandatory(
                WS_STAGE_PREPARING,
                100,
                "success",
                getString(R.string.ota_upgrade_status_preparing),
                null
        );
    }

    /** UI + {@code install-firmware} 0% immediately before {@link #controlUp} / BinUtil. */
    private void beginPhaseFirmwareUiIfNeeded() {
        if (!ensureFirmwareStageZeroWs()) {
            return;
        }
        if (binding != null) {
            binding.updatingStartPower.setProgress(0);
            binding.tvUpgradeStatus.setText(getString(R.string.ota_upgrade_status_firmware, 0));
        }
    }

    private boolean ensureFirmwareStageZeroWs() {
        if (firmwareStageZeroWsDelivered) {
            return true;
        }
        String message = getString(R.string.ota_upgrade_status_firmware, 0);
        if (otaWsOutbound.sendMandatory(WS_STAGE_INSTALL_FIRMWARE, 0, "running", message, null)) {
            firmwareProgressThrottler.reset();
            firmwareProgressThrottler.markPosted(0);
            firmwareStageZeroWsDelivered = true;
            return true;
        }
        Log.w(TAG, "OTA install-firmware stage 0% WS not delivered");
        return false;
    }

    /** UI + {@code install-app} 0% immediately before silent APK install. */
    private void beginPhaseAppInstallUiIfNeeded() {
        if (!ensureAppInstallStageZeroWs()) {
            return;
        }
        if (binding != null) {
            binding.updatingStartPower.setProgress(0);
            binding.tvUpgradeStatus.setText(R.string.ota_upgrade_status_apk);
        }
    }

    private boolean ensureAppInstallStageZeroWs() {
        if (appInstallStageZeroWsDelivered) {
            return true;
        }
        String message = getString(R.string.ota_upgrade_status_apk);
        if (otaWsOutbound.sendMandatory(WS_STAGE_INSTALL_APP, 0, "running", message, null)) {
            appInstallStageZeroWsDelivered = true;
            return true;
        }
        Log.w(TAG, "OTA install-app stage 0% WS not delivered");
        return false;
    }

    private void applyFirmwareTransferProgress(int firmwareFilePercent) {
        if (!firmwareProgressThrottler.shouldPost(firmwareFilePercent)) {
            return;
        }
        String message = getString(R.string.ota_upgrade_status_firmware, firmwareFilePercent);
        if (!otaWsOutbound.trySend(WS_STAGE_INSTALL_FIRMWARE, firmwareFilePercent, "running", message, null)) {
            return;
        }
        firmwareProgressThrottler.markPosted(firmwareFilePercent);
        if (binding != null) {
            binding.updatingStartPower.setProgress(firmwareFilePercent);
            binding.tvUpgradeStatus.setText(message);
        }
    }

    /**
     * Sleeps when disk write is ahead of {@link #OTA_DOWNLOAD_MAX_BYTES_PER_SECOND} so progress WS
     * is not starved by a tight read loop on fast networks.
     */
    private static void throttleDownloadWritePace(long bytesWritten, long downloadStartMs) {
        if (OTA_DOWNLOAD_MAX_BYTES_PER_SECOND <= 0 || bytesWritten <= 0) {
            return;
        }
        long expectedElapsedMs = (bytesWritten * 1000L) / OTA_DOWNLOAD_MAX_BYTES_PER_SECOND;
        long actualElapsedMs = SystemClock.uptimeMillis() - downloadStartMs;
        if (expectedElapsedMs > actualElapsedMs) {
            try {
                Thread.sleep(expectedElapsedMs - actualElapsedMs);
            } catch (InterruptedException ex) {
                Thread.currentThread().interrupt();
            }
        }
    }

    /**
     * Called from the download worker while reading the ZIP stream (like video {@code ByteProgress}).
     * WS sends run on the worker; UI updates are posted to the main thread.
     */
    private void emitDownloadProgressFromWorker(int percent) {
        synchronized (downloadWsProgressLock) {
            if (downloadProgressThrottler.shouldPost(percent)) {
                if (otaWsOutbound.trySend(WS_STAGE_DOWNLOAD, percent, "running", null, null)) {
                    downloadProgressThrottler.markPosted(percent);
                }
            }
        }
        if (binding != null && handler != null) {
            final int uiPercent = percent;
            handler.post(() -> {
                if (binding != null) {
                    binding.updatingStartPower.setProgress(uiPercent);
                }
            });
        }
    }

    /** End download stage for remote observers before {@code preparing}. */
    private void ensureDownloadStageCompleteWs() {
        if (otaWsOutbound.sendMandatory(WS_STAGE_DOWNLOAD, 100, "success", null, null)) {
            downloadProgressThrottler.markPosted(100);
        }
        if (binding != null) {
            binding.updatingStartPower.setProgress(100);
        }
    }

    private void restartAppAfterOta() {
        Intent i = new Intent();
        i.setComponent(new ComponentName(SystemSettingConstant.APP_PACKAGE_NAME, SystemSettingConstant.APP_MAIN_ACTIVITY));
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        startActivity(i);
    }

    /* UI升级*/
    private void UIUp( File file, String version ){
        //ApkUtil apk = new ApkUtil();
        //apk.UIUp( file,context );
        YNHAPI.getInstance().installApkSilently(file.getPath(), SystemSettingConstant.APP_PACKAGE_NAME,SystemSettingConstant.APP_MAIN_ACTIVITY);
        Log.i(TAG, "OTA install APK silent path=" + file.getPath() + " targetVersion=" + version
                + " (installApkSilently called; reboot may follow)");
    }

    /* 控制器升级*/
    private void controlUp( File file,String fileName ){
        if (!FirmwareUpgradeCoordinator.canStartOtaFirmwareTransfer()) {
            Log.w(TAG, "controlUp: bundled firmware upgrade in progress, skipping");
            controllerBardUpgradeEnd(false);
            return;
        }
        if (isProbablyEmulator()) {
            emulateInstallFirmwareWsZeroToFullForEmulator(fileName);
            return;
        }
        //1、调用控制器升级
        BinUtil.binFileConvert( file );

        //记录文件名称，回调时记录版本号
        binFileName = fileName;
    }

    /**
     * AVD：不跑 Modbus 刷写；{@link #beginPhaseFirmwareUiIfNeeded()} 已推 install-firmware 0%，此处补推 100% success，
     * 再进入 APK 阶段（与真实设备固件跳过到 APK 的语义对齐，避免误发 Modbus fail）。
     */
    private void emulateInstallFirmwareWsZeroToFullForEmulator(String fileName) {
        Log.i(TAG, "OTA install firmware: emulator — skip BinUtil; install-firmware WS 0% (prior) -> 100%");
        if (firmwareStageZeroWsDelivered) {
            String firmwareDoneMsg = getString(R.string.ota_upgrade_status_firmware, 100);
            if (otaWsOutbound.sendMandatory(WS_STAGE_INSTALL_FIRMWARE, 100, "success", firmwareDoneMsg, null)) {
                firmwareProgressThrottler.markPosted(100);
                if (binding != null) {
                    binding.updatingStartPower.setProgress(100);
                    binding.tvUpgradeStatus.setText(firmwareDoneMsg);
                }
            }
        }
        binFileName = fileName;
        DeviceStatusTaskHandler.controllerUpgradeEnd();
        controllerBardUpgradeEnd(false);
    }

    /**
     * 将OSS返回的ZIP输入流写入本地临时文件（适配大文件）
     * @param inputStream OSS获取的文件输入流
     * @param zipPath 本地ZIP保存路径
     * @return 是否写入成功*/
    /**
     * @param downloadTotalBytes positive HTTP Content-Length when known; otherwise no byte-based progress
     */
    private boolean writeZipToLocal(InputStream inputStream, String zipPath, long downloadTotalBytes) {
        File zipFile = new File(zipPath);
        Log.i(TAG, "OTA download write start path=" + zipPath + " expectedBytes=" + downloadTotalBytes);
        // 创建父目录（如果不存在）
        File parentDir = zipFile.getParentFile();
        if ( !parentDir.exists() && !parentDir.mkdirs() ) {
            Log.e(TAG, "OTA download write aborted: parent mkdir failed " + parentDir.getAbsolutePath());
            return false;
        }

        // 大文件优化：使用Buffered流提升写入效率
        BufferedOutputStream bos = null;
        BufferedInputStream bis = null;
        long written = 0;
        long downloadStartMs = SystemClock.uptimeMillis();
        try {
            if (OTA_DOWNLOAD_MAX_BYTES_PER_SECOND > 0 && downloadTotalBytes > 0) {
                Log.i(TAG, "OTA download rate cap bytesPerSec=" + OTA_DOWNLOAD_MAX_BYTES_PER_SECOND);
            }
            bis = new BufferedInputStream(inputStream);
            bos = new BufferedOutputStream(new FileOutputStream(zipFile));
            byte[] buffer = new byte[8192]; // 8KB缓冲区（大文件推荐8-16KB）
            int len;
            while ((len = bis.read(buffer)) != -1) {
                bos.write(buffer, 0, len);
                written += len;
                throttleDownloadWritePace(written, downloadStartMs);
                if (downloadTotalBytes > 0) {
                    int p = (int) Math.min(100, (written * 100L) / downloadTotalBytes);
                    emitDownloadProgressFromWorker(p);
                }
            }
            bos.flush();
            if (downloadTotalBytes > 0) {
                emitDownloadProgressFromWorker(100);
            }
            boolean sizeOk = totalFileSize <= 0 || zipFile.length() == totalFileSize;
            boolean ok = zipFile.exists() && zipFile.length() > 0 && sizeOk;
            Log.i(TAG, "OTA download write end path=" + zipPath + " written=" + written + " ok=" + ok);
            return ok;
        } catch (IOException e) {
            Log.e(TAG, "OTA download write failed", e);
            return false;
        }  finally {
            // 关闭流资源（大文件必须确保流关闭，否则文件被占用）
            try {
                if (bis != null) bis.close();
                if (bos != null) bos.close();
                if (inputStream != null) inputStream.close();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }

    /**
     * 解压ZIP文件到指定目录（适配大文件，避免内存溢出）
     * @param zipPath 本地ZIP文件路径
     * @param unzipDir 解压目标目录
     * @return 是否解压成功
     */
    private boolean unzipFile(String zipPath, String unzipDir) {
        File zipFile = new File(zipPath);
        boolean sizeOk = totalFileSize <= 0 || zipFile.length() == totalFileSize;
        if (!zipFile.exists() || zipFile.length() == 0 || !sizeOk) {
            Log.e(TAG, "OTA install unzip failed: zip missing empty or size mismatch path=" + zipPath);
            return false;
        }

        // 先删除旧解压目录（避免残留文件）
        deleteDir(new File(unzipDir));
        if (!new File(unzipDir).mkdirs()) {
            Log.e(TAG, "OTA install unzip failed: mkdir " + unzipDir);
            return false;
        }

        // 大文件解压：使用Buffered流+逐条目解压
        ZipInputStream zis = null;
        try {
            zis = new ZipInputStream( new BufferedInputStream(new FileInputStream(zipFile)), Charset.forName("GBK"));
            ZipEntry entry;
            while ((entry = zis.getNextEntry()) != null) {
                File entryFile = new File(unzipDir, entry.getName());
                // 处理目录
                if (entry.isDirectory()) {
                    entryFile.mkdirs();
                    continue;
                }
                // 处理文件（大文件逐块写入）
                BufferedOutputStream bos = new BufferedOutputStream(new FileOutputStream(entryFile));
                byte[] buffer = new byte[8192];
                int len;
                while ((len = zis.read(buffer)) != -1) {
                    bos.write(buffer, 0, len);
                }
                bos.flush();
                bos.close();
                zis.closeEntry(); // 关闭当前条目，释放资源
            }
            Log.i(TAG, "OTA install unzip success dir=" + unzipDir);
            return true;
        } catch (IOException e) {
            Log.e(TAG, "OTA install unzip IO error", e);
            return false;
        } finally {
            try {
                if (zis != null) zis.close();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }

    /**
     * 解析解压后的文件（示例：遍历文件、读取文本/JSON等）
     * 你可根据业务修改（如读取配置文件、安装APK、解析更新日志等）
     */
    /**
     * @return {@code true} if the upgrade schedule must stay visible: either a {@code .bin} was queued (async firmware) or
     *         {@link #controllerBardUpgradeEnd} was run synchronously (e.g. APK-only zip). {@code false} if parsing aborted (caller should {@link #end()}).
     */
    private boolean parseUnzipFiles(String unzipDir) {
        Log.i(TAG, "OTA install parse start dir=" + unzipDir);
        File dir = new File(unzipDir);
        if (!dir.exists()) {
            Log.e(TAG, "OTA install parse failed: unzip dir missing " + unzipDir);
            files = null;
            return false;
        }

        files = sortApkToLast(dir.listFiles());
        if ( files == null || files.length == 0 ) {
            Log.e(TAG, "OTA install parse failed: no files under " + unzipDir);
            files = null;
            return false;
        }

        /*获取升级版本信息*/
        Intent intent = getIntent();
        deviceInfo = (DeviceInfo) intent.getSerializableExtra("info");
        if (deviceInfo == null) {
            deviceInfo = new DeviceInfo();
        }
        if (deviceInfo.getId() == null) {
            DeviceInfo fromVm = devModel.getLiveData().getValue();
            if (fromVm != null) {
                deviceInfo = fromVm;
            }
        }
        syncInstalledSystemVersionFromPackage();

        boolean startedBin = false;
        for ( File file : files ) {
            if (!file.isFile()) {
                continue;
            }
            /*开始升级  .apk留在最后调用，等.bin升级完成后*/
            if (!file.getName().endsWith(".apk") ) {
                if (file.getName().toLowerCase().endsWith(".bin")) {
                    startedBin = true;
                }
                this.upgradeType(file);
            }
        }
        Log.i(TAG, "OTA install parse done entries=" + files.length + " firmwareBinQueued=" + startedBin);
        if (!startedBin) {
            controllerBardUpgradeEnd(false);
        }
        return true;
    }

    public File[] sortApkToLast(File[] files) {
        // 空值校验
        if ( files == null || files.length == 0 ) {return files;}

        // 分离非apk文件和apk文件
        List<File> nonApkFiles = new ArrayList<>();
        List<File> binFiles = new ArrayList<>();

        for ( File file : files ) {
            if( file.isFile() && file.getName().toLowerCase().endsWith(".bin") ){
                binFiles.add( 0, file );
            }
            else {
                // 非apk文件，加入普通列表
                nonApkFiles.add( file );
            }
        }

        // 合并列表：非apk文件在前，apk文件在后
        nonApkFiles.addAll( binFiles );

        // 转换为数组返回
        return nonApkFiles.toArray( new File[0] );
    }

    /* 分类升级：固件 .bin、可选 MediaMTX 原生件、后续 APK；AI/工艺库由 APK 内置 assets 在启动时导入 */
    private void upgradeType(File file) {
        String fileName = file.getName();
        String beginVersion = getBeginVersion(fileName);
        if (fileName.endsWith(".bin")) {
            beginPhaseFirmwareUiIfNeeded();
            Log.i(TAG, "OTA install firmware bin path=" + file.getAbsolutePath() + " name=" + fileName
                    + " beginVersion=" + beginVersion);
            controlUp(file, fileName);
        } else if (MediaMtxOtaInstaller.tryStageFromOtaFile(context, file)) {
            Log.i(TAG, "OTA install mediamtx staged name=" + fileName + " beginVersion=" + beginVersion);
        } else {
            Log.d(TAG, "OTA install non-apk non-bin skipped name=" + fileName + " beginVersion=" + beginVersion);
        }
    }

    /**
     * 固件 {@code .bin}：文件名中 {@code S} 后四位软件版本（十进制，非 SemVer）；
     * 其它文件：{@code *_v*} 段（如 APK / 工艺库命名）。
     */
    private String getBeginVersion(String fileName) {
        if (fileName != null && fileName.toLowerCase().endsWith(".bin")) {
            Integer sw = UpgradeFileReaderUtils.getFileSoftwareVersion(fileName);
            return sw != null ? String.valueOf(sw) : "";
        }
        String v = LibraryVersionFilename.extractVersionSegment(fileName);
        return v != null ? v : "";
    }

    /** Installed APK {@code versionName} for semver compare (not read from Room). */
    private String getInstalledApkVersionForCompare() {
        try {
            PackageInfo pi = context.getPackageManager().getPackageInfo(context.getPackageName(), 0);
            if (pi.versionName != null && !pi.versionName.trim().isEmpty()) {
                return pi.versionName.trim();
            }
        } catch (PackageManager.NameNotFoundException ignored) {
        }
        return BuildConfig.VERSION_NAME != null ? BuildConfig.VERSION_NAME : "";
    }

    private void syncInstalledSystemVersionFromPackage() {
        if (deviceInfo == null) {
            deviceInfo = new DeviceInfo();
        }
        deviceInfo.setSystemVersion(getInstalledApkVersionForCompare());
    }

    /** 清理所有临时文件：删除下载目录松散文件/ZIP压缩包 + 递归删除解压目录 */
    private void cleanTempFiles() {
        cancelPendingDelayedOtaUnzipDirCleanup();
        cleanOtaDownloadLooseFilesAndZip();
        deleteOtaUnzipStagingDirectory();
    }

    /** 顶层 Download 松散文件（不删子目录如 {@code update_unzip/}）+ 当前 ZIP 路径。 */
    private void cleanOtaDownloadLooseFilesAndZip() {
        File downloads = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS) + "");
        File[] listing = downloads.listFiles();
        if (listing == null) {
            return;
        }
        for (File file : listing) {
            if (file.isFile()) {
                boolean deleted = file.delete();
                if (deleted) {
                    Log.d(TAG, "删除文件成功：" + file.getAbsolutePath());
                } else {
                    Log.w(TAG, "删除文件失败：" + file.getAbsolutePath());
                }
            }
        }

        File zipFile = new File(ZIP_PATH);
        if (zipFile.exists()) {
            boolean isZipDeleted = zipFile.delete();
            Log.d("OSS_CLEAN", "ZIP文件删除" + (isZipDeleted ? "成功" : "失败"));
        }
    }

    private void cancelPendingDelayedOtaUnzipDirCleanup() {
        if (pendingDelayedOtaUnzipDirCleanup != null && handler != null) {
            handler.removeCallbacks(pendingDelayedOtaUnzipDirCleanup);
            pendingDelayedOtaUnzipDirCleanup = null;
        }
    }

    private void deleteOtaUnzipStagingDirectory() {
        File unzipDir = new File(UNZIP_DIR);
        boolean isDirDeleted = deleteDir(unzipDir);
        Log.d("OSS_CLEAN", "解压目录删除" + (isDirDeleted ? "成功" : "失败"));
    }

    /** 递归删除目录（适配大目录，确保所有文件都被删除）
     * @param dir 要删除的目录
     * @return 是否删除成功*/
    private boolean deleteDir(File dir) {
        if (dir == null || !dir.exists()) {
            return true;
        }
        // 如果是文件，直接删除
        if (dir.isFile()) {
            return dir.delete();
        }
        // 如果是目录，遍历删除所有子文件/子目录
        File[] files = dir.listFiles();
        if (files != null) {
            for (File file : files) {
                deleteDir(file); // 递归删除
            }
        }
        // 最后删除空目录
        return dir.delete();
    }

    /*删除下载的升级文件*/
    private void deleteUpFile(){}

    private void goToUpPage(){
        binding.goToUpPage.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                if( upStatus ){
                    return;
                }
                GlobalSoundManager.playClickSound();
                finish();
            }
        });
    }

    @Override
    protected void initData() {}

    @Override
    protected void onDestroy() {
        FirmwareUpgradeCoordinator.setOtaUpgradeInProgress(false);
        FirmwareUpgradeProgressReporter.setOtaListener(null);
        if (pendingPostVerifyInstall != null && handler != null) {
            handler.removeCallbacks(pendingPostVerifyInstall);
            pendingPostVerifyInstall = null;
        }
        if (pendingSuccessRestart != null && handler != null) {
            handler.removeCallbacks(pendingSuccessRestart);
            pendingSuccessRestart = null;
        }
        cancelPendingDelayedOtaUnzipDirCleanup();
        if (EventBus.getDefault().isRegistered(this)) {
            EventBus.getDefault().unregister(this);
        }
        super.onDestroy();
        totalFileSize = 0;
        upStatus = false;
        upSucceed = false;
        files = null;
    }


    @Override
    protected int getLayoutId() {
        return R.layout.activity_upgrade;
    }

    /**
     * 控制卡升级结果.
     * <p>Use {@link ThreadMode#MAIN_ORDERED}: with {@link ThreadMode#MAIN}, {@code post()} on the main thread
     * invokes this subscriber <strong>synchronously</strong> while still inside {@link #parseUnzipFiles} / the post-download
     * {@link Handler} runnable — failure paths call {@link #end()} and hide &quot;升级系统&quot; before that runnable finishes.</p>
     */
    @Subscribe(threadMode = ThreadMode.MAIN_ORDERED)
    public void controllerBardUpgradeResult(DeviceUpgradeEvent deviceUpgradeEvent) {
        UpgradeStatusEnum st = deviceUpgradeEvent.getUpgradeStatus();
        Integer err = deviceUpgradeEvent.getErrorCode();
        Log.d(TAG, "controllerBardUpgradeResult: status=" + st + " errorCode=" + err
                + " event=" + deviceUpgradeEvent);

        if (UpgradeStatusEnum.UPGRADE_ING.equals(st)) {
            beginPhaseFirmwareUiIfNeeded();
            return;
        }

        if (UpgradeStatusEnum.UPGRADE_FAIL.equals(st) || UpgradeStatusEnum.UPGRADE_TIME_OUT.equals(st)) {
            Log.e(TAG, "OTA install firmware FAIL/TIMEOUT errorCode=" + err
                    + " (606=same firmware skip to APK; 605=Modbus/request fail common on emulator)");
            if (Objects.equals(err, DeviceUpgradeConstant.VERSION_SAME_NOT_NEED_UPGRADE_ERROR)) {
                Log.i(TAG, "OTA install firmware skipped (same version), continuing to APK step");
                controllerBardUpgradeEnd(false);
                return;
            }
            // Emulator / AVD: no real control card — any firmware failure or timeout is treated like 606 (skip to APK OTA UI).
            if (isProbablyEmulator()) {
                Log.w(TAG, "OTA install firmware: emulator skip to APK path (errorCode=" + err + ")");
                DeviceStatusTaskHandler.controllerUpgradeEnd();
                controllerBardUpgradeEnd(false);
                return;
            }
            DeviceStatusTaskHandler.controllerUpgradeEnd();
            GlobalDialogUtil.showStatusDialog(context, 0, "Control Card Upgrade Failed", "Firmware Version upgrade failed.");
            reportWsUpdateProgress(WS_STAGE_FAILED, 100, "failed", "Control card upgrade failed", "firmware_upgrade_failed");
            handler.removeCallbacks(timeoutRunnable);
            upStatus = false;
            cleanTempFiles();
            handler.post(this::end);
            upSucceed = false;
            return;
        }

        if (UpgradeStatusEnum.UPGRADE_SUCCESS.equals(st)) {
            Integer version = UpgradeFileReaderUtils.getFileSoftwareVersion(binFileName);
            deviceInfo.setFirmwareVersion(version != null ? version + "" : deviceInfo.getFirmwareVersion());
            Log.i(TAG, "OTA install firmware SUCCESS bin=" + binFileName + " reportedSw=" + version);
            controllerBardUpgradeEnd(true);
        }
    }

    /**
     * Typical AVD / emulator images (no real control card / Modbus).
     */
    private static boolean isProbablyEmulator() {
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

    /**
     * SemVer for APK compare: {@code *_vX.Y.Z*} segment in filename when present, else OTA manifest {@link #versionCode}.
     */
    private String resolveApkTargetVersion(String apkFileName) {
        String fromFile = getBeginVersion(apkFileName);
        if (fromFile != null && !fromFile.trim().isEmpty()) {
            return fromFile.trim();
        }
        if (versionCode != null && !versionCode.trim().isEmpty()) {
            return versionCode.trim();
        }
        return "";
    }

    /**
     * @param firmwareActuallyUpgraded {@code true} only when controller reported {@link UpgradeStatusEnum#UPGRADE_SUCCESS};
     *        {@code false} when firmware was skipped as already current (e.g. error 606).
     */
    public void controllerBardUpgradeEnd(boolean firmwareActuallyUpgraded){
        boolean apkInstallStarted = false;
        boolean successOutcome = false;
        if (files == null) {
            Log.e(TAG, "controllerBardUpgradeEnd: files is null");
            upStatus = false;
            cleanTempFiles();
            if (handler != null) {
                handler.post(this::end);
            }
            return;
        }
        try {
            Log.i(TAG, "OTA install finalize before APK step deviceInfo=" + deviceInfo);
            devModel.updateOrAddInfo(deviceInfo, context);

            if (firmwareStageZeroWsDelivered && firmwareProgressThrottler.shouldPost(100)) {
                String firmwareDoneMsg = getString(R.string.ota_upgrade_status_firmware, 100);
                if (otaWsOutbound.sendMandatory(WS_STAGE_INSTALL_FIRMWARE, 100, "success", firmwareDoneMsg, null)) {
                    firmwareProgressThrottler.markPosted(100);
                    if (binding != null) {
                        binding.updatingStartPower.setProgress(100);
                    }
                }
            }
            for ( File file : files ) {
                //最后升级APK
                if ( file.getName().endsWith(".apk") ) {

                    String fileName = file.getName();
                    String apkTarget = resolveApkTargetVersion(fileName);
                    String installed = getInstalledApkVersionForCompare();
                    Log.i(TAG, "OTA install APK candidate file=" + fileName + " targetVersion=" + apkTarget
                            + " installed=" + installed);
                    if (SemanticVersionHelper.isNewerThan(apkTarget, installed)) {
                        beginPhaseAppInstallUiIfNeeded();
                        UIUp( file, apkTarget );
                        apkInstallStarted = true;
                    } else {
                        Log.w(TAG, "APK install skipped: targetVersion=\"" + apkTarget + "\" installed=\"" + installed + "\" file=" + fileName);
                        devModel.updateOrAddInfo(deviceInfo, context);
                    }
                }
            }
            if (appInstallStageZeroWsDelivered) {
                String apkDoneMsg = getString(R.string.ota_upgrade_status_apk);
                if (otaWsOutbound.sendMandatory(WS_STAGE_INSTALL_APP, 100, "success", apkDoneMsg, null)) {
                    if (binding != null) {
                        binding.updatingStartPower.setProgress(100);
                    }
                }
            }
            if (firmwareActuallyUpgraded || apkInstallStarted) {
                Log.i(TAG, "OTA install outcome success firmwareUpgraded=" + firmwareActuallyUpgraded
                        + " apkStarted=" + apkInstallStarted);
                GlobalDialogUtil.showStatusDialog(context, 1, "Upgrade Completed", "Upgrade successful.");
                reportWsUpdateProgressMandatory(WS_STAGE_COMPLETED, 100, "success", "Upgrade successful", null);
                upSucceed = true;
                successOutcome = true;
            } else {
                Log.i(TAG, "OTA install outcome no package applied (firmware current, APK not newer)");
                GlobalDialogUtil.showStatusDialog(context, 2, "No Updates Installed",
                        "Firmware is already current and no newer app package was installed.");
                reportWsUpdateProgressMandatory(WS_STAGE_COMPLETED, 100, "success", "No updates installed", null);
                upSucceed = false;
                successOutcome = false;
            }
        }catch (Exception e) {
            Log.e(TAG, "controllerBardUpgradeEnd failed", e);
            GlobalDialogUtil.showStatusDialog(context, 0, "Upgrade Failed", "This is the latest version at present.");
            reportWsUpdateProgress(WS_STAGE_FAILED, 100, "failed", "install failed", "upgrade_end_failed");
            upSucceed = false;
            successOutcome = false;
        }
        finally {
            final boolean delayedRestart = successOutcome && apkInstallStarted;
            upStatus = false;
            cancelPendingDelayedOtaUnzipDirCleanup();
            cleanOtaDownloadLooseFilesAndZip();
            if (apkInstallStarted && !delayedRestart) {
                pendingDelayedOtaUnzipDirCleanup = () -> {
                    pendingDelayedOtaUnzipDirCleanup = null;
                    deleteOtaUnzipStagingDirectory();
                };
                if (handler != null) {
                    handler.postDelayed(pendingDelayedOtaUnzipDirCleanup, SUCCESS_RESTART_DELAY_MS);
                } else {
                    deleteOtaUnzipStagingDirectory();
                }
            } else if (!apkInstallStarted) {
                deleteOtaUnzipStagingDirectory();
            }
            devModel.updateOrAddInfo( deviceInfo, context );
            if (handler != null) {
                handler.post(() -> {
                    if (!delayedRestart) {
                        end();
                        if (upSucceed && binding != null && binding.btnLater != null) {
                            binding.btnLater.setVisibility(View.VISIBLE);
                            binding.btnUpdateNow.setVisibility(View.GONE);
                        }
                    } else {
                        if (binding != null) {
                            binding.linearUpgradeSchedule.setVisibility(View.VISIBLE);
                            binding.linearUpgradeBt.setVisibility(View.GONE);
                        }
                        pendingSuccessRestart = () -> {
                            pendingSuccessRestart = null;
                            deleteOtaUnzipStagingDirectory();
                            restartAppAfterOta();
                            finish();
                        };
                        handler.postDelayed(pendingSuccessRestart, SUCCESS_RESTART_DELAY_MS);
                    }
                });
            }
        }
    }

    private void reportWsUpdateProgress(
            String stage,
            int progress,
            String status,
            String message,
            String errorCode
    ) {
        if (!otaWsOutbound.trySend(stage, progress, status, message, errorCode)) {
            Log.w(TAG, "OTA WS progress deferred (gap) stage=" + stage + " progress=" + progress + " status=" + status);
        }
    }

    private void reportWsUpdateProgressMandatory(
            String stage,
            int progress,
            String status,
            String message,
            String errorCode
    ) {
        otaWsOutbound.sendMandatory(stage, progress, status, message, errorCode);
    }
}
