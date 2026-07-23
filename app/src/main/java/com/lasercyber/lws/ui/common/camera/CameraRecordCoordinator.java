package com.lasercyber.lws.ui.common.camera;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.blankj.utilcode.util.ToastUtils;
import com.blankj.utilcode.util.Utils;
import com.innohi.StorageInfo;
import com.innohi.YNHAPI;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.config.CameraConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.utils.CameraUtils;
import com.lasercyber.lws.ui.component.CameraController;
import com.lasercyber.lws.ui.network.http.local.CameraRecordUiBridge;
import com.lasercyber.lws.ui.network.http.remote.CameraRemote;

import java.util.List;
import java.util.Objects;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Shared Fast / Engineer / HTTP recording preflight and start/stop control.
 */
public final class CameraRecordCoordinator {
    public static final String RECORDING_IN_PROGRESS_CODE = "recording_in_progress";

    private static final String TAG = LogTAGConstant.CameraRecordCoordinator;
    private static final long HTTP_APPLY_TIMEOUT_SEC = 90L;
    private static final String RECORDING_IN_PROGRESS_MESSAGE_ZH = "另一个线程正在录制中";

    private static volatile CameraRecordCoordinator instance;

    @Nullable
    @VisibleForTesting
    static Boolean recordingActiveOverrideForTest;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final ExecutorService recordControlExecutor = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "camera-record-control");
        t.setDaemon(true);
        return t;
    });

    private CameraRecordCoordinator() {
    }

    @NonNull
    public static CameraRecordCoordinator getInstance() {
        if (instance == null) {
            synchronized (CameraRecordCoordinator.class) {
                if (instance == null) {
                    CameraRecordSaveHandler.ensureRegistered();
                    instance = new CameraRecordCoordinator();
                }
            }
        }
        return instance;
    }

    @VisibleForTesting
    static void setRecordingActiveOverrideForTest(@Nullable Boolean active) {
        recordingActiveOverrideForTest = active;
    }

    @VisibleForTesting
    static void resetForTest() {
        recordingActiveOverrideForTest = null;
        synchronized (CameraRecordCoordinator.class) {
            instance = null;
        }
    }

    @NonNull
    public static String recordingInProgressMessage() {
        try {
            return Utils.getApp().getString(R.string.camera_record_another_thread_recording);
        } catch (Throwable t) {
            return RECORDING_IN_PROGRESS_MESSAGE_ZH;
        }
    }

    public interface Callback {
        void onResult(@NonNull Result result);
    }

    public static final class Result {
        public final boolean success;
        @NonNull
        public final String effectiveSwitch;
        public final int httpCode;
        @Nullable
        public final String errorMessage;

        private Result(boolean success, @NonNull String effectiveSwitch, int httpCode, @Nullable String errorMessage) {
            this.success = success;
            this.effectiveSwitch = effectiveSwitch;
            this.httpCode = httpCode;
            this.errorMessage = errorMessage;
        }

        @NonNull
        public static Result ok(@NonNull String effectiveSwitch) {
            return new Result(true, effectiveSwitch, 200, null);
        }

        @NonNull
        public static Result fail(int httpCode, @NonNull String errorMessage, @NonNull String effectiveSwitch) {
            return new Result(false, effectiveSwitch, httpCode, errorMessage);
        }
    }

    public boolean isRecordingActive() {
        if (recordingActiveOverrideForTest != null) {
            return recordingActiveOverrideForTest;
        }
        EasyPlayerClientManger manager = EasyPlayerClientManger.getInstance();
        if (manager.isRecordingActive() || manager.isMuxerWriteActive()) {
            return true;
        }
        if (CameraRecordStateStore.isRecording()) {
            return true;
        }
        CameraController controller = CameraRecordUiBridge.get();
        return controller != null && controller.isRecording();
    }

    /**
     * UI tap path: run preflight then invoke {@code onSuccessMain} on the main thread.
     */
    public void runStartPreflight(
            boolean showUserToasts,
            @NonNull Runnable onSuccessMain,
            @NonNull Runnable onFailMain
    ) {
        recordControlExecutor.execute(() -> {
            if (isRecordingActive()) {
                mainHandler.post(() -> {
                    if (showUserToasts) {
                        ToastUtils.showShort(R.string.camera_record_another_thread_recording);
                    }
                    onFailMain.run();
                });
                return;
            }
            PreflightFail fail = runSyncPreflightChecks();
            if (fail != null) {
                mainHandler.post(() -> {
                    if (showUserToasts) {
                        showToastForFail(fail);
                    }
                    onFailMain.run();
                });
                return;
            }
            CameraUtils.checkCamera(new CameraUtils.CheckCameraListener() {
                @Override
                public void success() {
                    recordControlExecutor.execute(() -> {
                        if (isRecordingActive()) {
                            mainHandler.post(() -> {
                                if (showUserToasts) {
                                    ToastUtils.showShort(R.string.camera_record_another_thread_recording);
                                }
                                onFailMain.run();
                            });
                            return;
                        }
                        recordControlExecutor.execute(CameraRemote::updateCameraTime);
                        mainHandler.post(onSuccessMain);
                    });
                }

                @Override
                public void fail() {
                    mainHandler.post(() -> {
                        if (showUserToasts) {
                            ToastUtils.showShort(R.string.unable_to_open_the_camera_title);
                        }
                        onFailMain.run();
                    });
                }
            });
        });
    }

    public void applySwitch(@NonNull String switchValue, @NonNull Callback callback) {
        if ("on".equals(switchValue)) {
            applyOn(callback);
        } else if ("off".equals(switchValue)) {
            applyOff(callback);
        } else {
            callback.onResult(Result.fail(400, "invalid_switch", "off"));
        }
    }

    /**
     * Blocking apply for NanoHTTPD; runs work off the HTTP thread and waits for async preflight.
     */
    @NonNull
    public Result applySwitchBlocking(@NonNull String switchValue) throws InterruptedException {
        CountDownLatch latch = new CountDownLatch(1);
        AtomicReference<Result> ref = new AtomicReference<>();
        applySwitch(switchValue, result -> {
            ref.set(result);
            latch.countDown();
        });
        if (!latch.await(HTTP_APPLY_TIMEOUT_SEC, TimeUnit.SECONDS)) {
            return Result.fail(503, "record_apply_timeout", isRecordingActive() ? "on" : "off");
        }
        Result result = ref.get();
        return result != null ? result : Result.fail(500, "internal_error", isRecordingActive() ? "on" : "off");
    }

    private void applyOn(@NonNull Callback callback) {
        recordControlExecutor.execute(() -> {
            if (isRecordingActive()) {
                callback.onResult(recordingInProgressFailure());
                return;
            }
            PreflightFail fail = runSyncPreflightChecks();
            if (fail != null) {
                callback.onResult(toFailResult(fail, "off"));
                return;
            }
            CameraUtils.checkCamera(new CameraUtils.CheckCameraListener() {
                @Override
                public void success() {
                    recordControlExecutor.execute(CameraRemote::updateCameraTime);
                    recordControlExecutor.execute(() -> finishApplyOn(callback));
                }

                @Override
                public void fail() {
                    callback.onResult(Result.fail(503, "camera_unavailable", "off"));
                }
            });
        });
    }

    private void finishApplyOn(@NonNull Callback callback) {
        if (isRecordingActive()) {
            callback.onResult(recordingInProgressFailure());
            return;
        }
        CameraController controller = CameraRecordUiBridge.get();
        if (controller != null && !postExternalRecordPreparing(controller, callback)) {
            return;
        }
        EasyPlayerClientManger manager = EasyPlayerClientManger.getInstance();
        boolean started;
        try {
            started = manager.start();
        } catch (Throwable t) {
            Log.e(TAG, "record start threw", t);
            started = false;
        }
        if (!started) {
            finishApplyOnStartFailed(controller, callback, "recording_failed");
            return;
        }
        boolean muxerReady;
        try {
            muxerReady = manager.awaitMuxerWriteActive(EasyPlayerClientManger.MUXER_WRITE_AWAIT_MS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            try {
                manager.stop();
            } catch (Throwable t) {
                Log.e(TAG, "record stop after interrupt threw", t);
            }
            finishApplyOnStartFailed(controller, callback, "record_apply_interrupted");
            return;
        }
        if (!muxerReady) {
            Log.e(TAG, "finishApplyOn: muxer not ready within timeout");
            try {
                manager.stop();
            } catch (Throwable t) {
                Log.e(TAG, "record stop after muxer timeout threw", t);
            }
            finishApplyOnStartFailed(controller, callback, "recording_failed");
            return;
        }
        if (controller != null) {
            mainHandler.post(() -> {
                controller.applyExternalRecordMuxerReady();
                callback.onResult(Result.ok("on"));
            });
        } else {
            callback.onResult(Result.ok("on"));
        }
    }

    /**
     * Shows the same preparing visuals as a local tap before RTSP/muxer work begins.
     *
     * @return {@code false} when blocked by an in-flight recording session.
     */
    private boolean postExternalRecordPreparing(
            @NonNull CameraController controller,
            @NonNull Callback callback
    ) {
        CountDownLatch prepUiLatch = new CountDownLatch(1);
        AtomicBoolean blocked = new AtomicBoolean(false);
        mainHandler.post(() -> {
            if (isRecordingActive()) {
                blocked.set(true);
            } else {
                controller.applyExternalRecordPreparing();
            }
            prepUiLatch.countDown();
        });
        try {
            if (!prepUiLatch.await(5L, TimeUnit.SECONDS)) {
                Log.w(TAG, "postExternalRecordPreparing: UI latch timeout");
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            callback.onResult(Result.fail(503, "record_apply_interrupted", "off"));
            return false;
        }
        if (blocked.get()) {
            callback.onResult(recordingInProgressFailure());
            return false;
        }
        return true;
    }

    private void finishApplyOnStartFailed(
            @Nullable CameraController controller,
            @NonNull Callback callback,
            @NonNull String errorMessage
    ) {
        if (controller != null) {
            mainHandler.post(() -> {
                controller.applyExternalRecordStartFailed();
                callback.onResult(Result.fail(503, errorMessage, "off"));
            });
        } else {
            callback.onResult(Result.fail(503, errorMessage, "off"));
        }
    }

    private void applyOff(@NonNull Callback callback) {
        recordControlExecutor.execute(() -> {
            if (!isRecordingActive()) {
                callback.onResult(Result.ok("off"));
                return;
            }
            mainHandler.post(() -> {
                CameraController controller = CameraRecordUiBridge.get();
                if (controller != null && controller.isRecording()) {
                    controller.applyExternalRecordOff();
                    callback.onResult(Result.ok("off"));
                    return;
                }
                recordControlExecutor.execute(() -> {
                    try {
                        EasyPlayerClientManger.getInstance().stop();
                    } catch (Throwable t) {
                        Log.e(TAG, "headless record stop threw", t);
                    }
                    mainHandler.post(() -> callback.onResult(Result.ok("off")));
                });
            });
        });
    }

    @NonNull
    private static Result recordingInProgressFailure() {
        return Result.fail(409, recordingInProgressMessage(), "on");
    }

    @Nullable
    private PreflightFail runSyncPreflightChecks() {
        if (!EasyPlayerClientManger.getInstance().isRecorderReady()) {
            return PreflightFail.CAMERA_NOT_READY;
        }
        List<StorageInfo> storageInfos = null;
        try {
            storageInfos = YNHAPI.getInstance().getStorageInfos();
        } catch (Throwable t) {
            Log.w(TAG, "getStorageInfos skipped (no YNH / emulator)", t);
        }
        if (storageInfos != null) {
            for (StorageInfo storageInfo : storageInfos) {
                if (!Objects.equals(storageInfo.getType(), StorageInfo.TYPE_LOCAL_STORAGE)) {
                    continue;
                }
                if (storageInfo.getFreeSize() * 1024 < CameraConfig.MAX_VIDEO_SIZE) {
                    return PreflightFail.INSUFFICIENT_STORAGE;
                }
            }
        }
        return null;
    }

    @NonNull
    private static Result toFailResult(@NonNull PreflightFail fail, @NonNull String effectiveSwitch) {
        switch (fail) {
            case INSUFFICIENT_STORAGE:
                return Result.fail(503, "insufficient_storage", effectiveSwitch);
            case CAMERA_NOT_READY:
            default:
                return Result.fail(503, "camera_not_ready", effectiveSwitch);
        }
    }

    private static void showToastForFail(@NonNull PreflightFail fail) {
        switch (fail) {
            case INSUFFICIENT_STORAGE:
                ToastUtils.showShort(R.string.insufficient_space_please_delete_videos_first);
                break;
            case CAMERA_NOT_READY:
            default:
                ToastUtils.showShort(R.string.unable_to_open_the_camera_title);
                break;
        }
    }

    private enum PreflightFail {
        CAMERA_NOT_READY,
        INSUFFICIENT_STORAGE
    }
}
