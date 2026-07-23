package com.lasercyber.lws.ai.engine;
import com.lasercyber.lws.ai.NativeBridge;
import com.lasercyber.lws.ai.Nv12FrameUtil;
import com.lasercyber.lws.ai.engine.AiEngineCapabilityProfile;
import com.lasercyber.lws.ai.engine.AiEngineConfigParser;
import com.lasercyber.lws.ai.model.AiStainDetectResult;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ai.model.StainDetectSource;
import com.lasercyber.lws.ai.sampling.AiFrameSamplingGate;
import com.lasercyber.lws.ai.sampling.AiFrameSamplingInterval;
import com.lasercyber.lws.ai.stain.AiStainDetectCoordinator;
import com.lasercyber.lws.ai.stain.AiStainDetectResultMapper;
import com.lasercyber.lws.ai.stain.LensDetConsecutiveOkFilter;
import com.lasercyber.lws.ai.stain.OpencvStainDetectInferCoordinator;
import com.lasercyber.lws.ai.stain.OpencvStainDetectResultMapper;
import android.content.Context;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import android.graphics.Bitmap;
import android.os.SystemClock;
import android.util.Log;

import com.lasercyber.lws.ai.bridge.AiNativeRuntime;
import com.lasercyber.lws.ai.bridge.AssetDeployer;
import com.lasercyber.lws.ai.daemon.AiDaemonSupervisor;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.bean.event.LensCheckResultEvent;
import com.lasercyber.lws.ui.bean.event.LensCheckResultImageEvent;
import com.lasercyber.lws.ui.bean.event.LensClsSnapshotEvent;
import com.lasercyber.lws.ui.bean.event.AiEngineStateEvent;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.config.CameraConfig;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;

import org.greenrobot.eventbus.EventBus;

import java.io.File;
import java.nio.ByteBuffer;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * AI product lifecycle manager. OpenCV/RKNN live infer runs in {@code lws_ai_daemon};
 * App never {@code System.load}s {@code libai.so} on the product path.
 */
public class AiManager implements MemoryCacheManager.OnCacheChangedListener {

    private static final String TAG = "AiManager";
    private static final String RESULT_STATUS_OK = "OK";
    private static final String RESULT_STATUS_ERROR = "ERROR";
    public static final int CODE_INFER_BUSY = -2001;
    public static final int CODE_OPENCV_STAIN_DETECT_DEFERRED = -2002;
    public static final int CODE_RKNN_STAIN_DISABLED = -2003;

    /** Reserved for future RKNN Java push-frame path; live inference uses C++ StreamDetectPipeline. */
    private static final boolean RKNN_STAIN_INFER_ACTIVE = false;

    /**
     * Whether App-layer RKNN stain one-shot APIs call native RKNN.
     * When false, live stain/零点 are driven by native stream detect, not Java frame push.
     */
    public static boolean isRknnStainInferActive() {
        return RKNN_STAIN_INFER_ACTIVE;
    }
    private static final String DEFAULT_RESULT_DIR = "/sdcard/lws/result";
    private static final long CLS_SNAPSHOT_MIN_INTERVAL_MS = 500L;
    /**
     * Engine fixed stain ROI 700×700 @(565,110) on 1920×1080 calibration frame.
     * Frames smaller than this may not cover the ROI (engine returns empty det).
     */
    private static final int MIN_PUSH_FRAME_WIDTH = 1265;
    private static final int MIN_PUSH_FRAME_HEIGHT = 810;
    private static final long SUB_MIN_FRAME_WARN_THROTTLE_MS = 10_000L;
    private static volatile AiManager INSTANCE;

    private long handle = 0;
    /** Config/assets deployed for lens_guard; daemon hosts the actual OpenCV session. */
    private volatile boolean opencvStainDetectActive = false;
    /** {@code true} after a successful product-path {@link #start(Context)} asset deploy. */
    private volatile boolean lensGuardAssetsDeployed = false;
    private Context appContext;
    /** Processes NV12 off the EasyPlayer decode callback thread (copy stays on caller). */
    private ThreadPoolExecutor aiFrameExecutor;
    private volatile int frameWidth = CameraConfig.VIDEO_RESOLUTION_WIDTH;
    private volatile int frameHeight = CameraConfig.VIDEO_RESOLUTION_HEIGHT;
    private volatile long lastClsSnapshotPostElapsedMs = 0L;
    private volatile long lastSubMinFrameWarnElapsedMs = 0L;
    private final AiFrameSamplingGate liveWeldFrameGate =
            new AiFrameSamplingGate(AiFrameSamplingInterval.LIVE_WELD);
    private final AiFrameSamplingGate aiVisionLiveFrameGate =
            new AiFrameSamplingGate(AiFrameSamplingInterval.AI_VISION_LIVE);
    private final AiFrameSamplingGate opencvAiVisionLiveFrameGate =
            new AiFrameSamplingGate(AiFrameSamplingInterval.AI_VISION_LIVE);
    private final AiFrameSamplingGate opencvProcessVideoFrameGate =
            new AiFrameSamplingGate(AiFrameSamplingInterval.AI_VISION_PROCESS_VIDEO);
    private int liveWeldFramesAccepted;
    private volatile Boolean lastLoggedLaserOn;
    private volatile boolean aiVisionPreviewClassificationEnabled;
    private volatile boolean aiVisionPreviewDetectionEnabled;
    private volatile boolean nativePreviewClassificationSupported = true;
    private volatile boolean nativePreviewDetectionSupported = true;
    private volatile AiEngineCapabilityProfile capabilities = inactiveCapabilities();
    private volatile int minConsecutiveOkFrames = LensDetConsecutiveOkFilter.DEFAULT_MIN_CONSECUTIVE_OK_FRAMES;
    private volatile int blueMinConsecutiveOkFrames = 1;


    private final AiStainDetectCoordinator unifiedInferCoordinator = new AiStainDetectCoordinator();
    private final OpencvStainDetectInferCoordinator opencvStainDetectInferCoordinator = new OpencvStainDetectInferCoordinator();

    private AiManager() {
    }

    private static AiEngineCapabilityProfile inactiveCapabilities() {
        return new AiEngineCapabilityProfile(false, true, false, false, false);
    }

    @NonNull
    private static String engineUnavailableMessage() {
        if (AiNativeRuntime.blocksRknnSession()) {
            return AiNativeRuntime.rknnUnavailableMessage();
        }
        return "Engine is not running";
    }

    public static AiManager getInstance() {
        if (INSTANCE == null) {
            synchronized (AiManager.class) {
                if (INSTANCE == null) {
                    INSTANCE = new AiManager();
                }
            }
        }
        return INSTANCE;
    }

    /**
     * Product start: deploy lens_guard assets + parse config. Inference runs in AI daemon (no in-process libai).
     *
     * @return {@code true} when assets deployed; daemon readiness may follow asynchronously.
     */
    public boolean start(Context context) {
        if (lensGuardAssetsDeployed) {
            Log.w(TAG, "Lens det product path already started, skipping start");
            return true;
        }
        appContext = context.getApplicationContext();
        handle = 0;
        capabilities = inactiveCapabilities();

        try {
            AssetDeployer paths = AssetDeployer.deploy(context);
            Log.i(TAG, "Engine config ready configPath=" + paths.getConfigPath()
                    + " projectRoot=" + paths.getProjectRoot());

            minConsecutiveOkFrames = AiEngineConfigParser.parseMinConsecutiveOkFrames(
                    new File(paths.getConfigPath()));
            blueMinConsecutiveOkFrames = AiEngineConfigParser.parseBlueMinConsecutiveOkFrames(
                    new File(paths.getConfigPath()));

            lensGuardAssetsDeployed = true;
            // Assets deployed; daemon may already be up (started first) or follow later.
            opencvStainDetectActive = AiDaemonSupervisor.getInstance().isReady();
            if (opencvStainDetectActive) {
                Log.i(TAG, "Product AI path ready (daemon already up)"
                        + " minConsecutiveOkFrames=" + minConsecutiveOkFrames
                        + " blueMinConsecutiveOkFrames=" + blueMinConsecutiveOkFrames);
            } else {
                Log.i(TAG, "Product AI path assets ready (awaiting daemon)"
                        + " minConsecutiveOkFrames=" + minConsecutiveOkFrames
                        + " blueMinConsecutiveOkFrames=" + blueMinConsecutiveOkFrames);
            }
            return true;
        } catch (Throwable e) {
            Log.e(TAG, "AiManager start failed", e);
            opencvStainDetectActive = false;
            lensGuardAssetsDeployed = false;
            return false;
        }
    }

    /**
     * Called when {@link AiDaemonSupervisor} becomes ready after {@link #start(Context)}
     * (or when daemon was started first and assets deploy completes shortly after).
     */
    public void markDaemonReady() {
        if (lensGuardAssetsDeployed) {
            opencvStainDetectActive = true;
            Log.i(TAG, "markDaemonReady: opencvStainDetectActive=true");
        }
    }

    @NonNull
    private NativeBridge.NativeListener createEngineListener() {
        return new NativeBridge.NativeListener() {
            @Override
            public void onStateChanged(int state) {
                if (isPreviewLaserOverrideActive()) {
                    Log.d(TAG, "Suppress state event during legacy AI Vision preview cls override: " + state);
                    return;
                }
                Log.i(TAG, "State changed: " + state);
                EventBus.getDefault().post(new AiEngineStateEvent(state));
            }

            @Override
            public void onCheckResult(int level, String status, String message) {
                if (isPreviewLaserOverrideActive() && !isPreviewDetectionMessage(message)) {
                    Log.d(TAG, "Suppress check result during legacy AI Vision preview cls override: level="
                            + level + " status=" + status + " " + message);
                    return;
                }
                // level/status/message: see docs/LENS_GUARD_APP_INTEGRATION.md §6; UI alerts (AI Vision) consume EventBus — do not recompute here.
                Log.i(TAG, "Check result: level=" + level + " status=" + status + " " + message);
                EventBus.getDefault().post(new LensCheckResultEvent(level, status, message));
            }

            @Override
            public void onAlert(int alertLevel) {
                if (isPreviewLaserOverrideActive()) {
                    Log.d(TAG, "Suppress alert during legacy AI Vision preview cls override: level=" + alertLevel);
                    GlobalSoundManager.stopWarnSound();
                    return;
                }
                // Single source for heavy alert sound: native drives warnSound here. AI Vision AlertDialog does NOT play audio again.
                Log.i(TAG, "Alert: level=" + alertLevel);
                if (alertLevel > 0) {
                    GlobalSoundManager.warnSound();
                } else if (!com.lasercyber.lws.ui.component.dialog.WarnDialogUtil.shouldDeferNativeAlertSoundStop()) {
                    GlobalSoundManager.stopWarnSound();
                }
            }
        };
    }

    private static void destroyEngineHandle(long engineHandle) {
        if (engineHandle == 0L) {
            return;
        }
        try {
            NativeBridge.guardedStopAndDestroy(engineHandle);
        } catch (Throwable t) {
            Log.w(TAG, "AiManager cleanup after failed start handle=" + engineHandle, t);
        }
    }

    /**
     * Stop product AI path: clear OpenCV readiness flag (daemon stop is separate).
     */
    public void stop() {
        destroyOpencvStainDetectSession();
        if (handle == 0) {
            opencvStainDetectActive = false;
            capabilities = inactiveCapabilities();
            resetOpencvAiVisionLiveFrameSampling();
            resetOpencvProcessVideoFrameSampling();
            Log.i(TAG, "Product AI path stopped");
            return;
        }

        shutdownAiFrameExecutor();

        MemoryCacheManager.getInstance().removeListener(CacheKey.DEVICE_STATUS_KEY, this);

        try {
            NativeBridge.guardedStopAndDestroy(handle);
        } catch (Exception e) {
            Log.e(TAG, "Error stopping engine", e);
        }

        handle = 0;
        capabilities = inactiveCapabilities();
        lastClsSnapshotPostElapsedMs = 0L;
        resetRknnLiveWeldFrameSampling();
        resetRknnAiVisionLiveFrameSampling();
        resetOpencvAiVisionLiveFrameSampling();
        resetOpencvProcessVideoFrameSampling();
        lastLoggedLaserOn = null;
        aiVisionPreviewClassificationEnabled = false;
        aiVisionPreviewDetectionEnabled = false;
        nativePreviewClassificationSupported = true;
        nativePreviewDetectionSupported = true;
        Log.i(TAG, "Engine stopped");
    }

    /** {@code true} when the RKNN LensGuard native engine session is active ({@code handle != 0}). */
    public boolean isRknnEngineRunning() {
        return handle != 0;
    }

    /**
     * {@code true} when lens_guard assets are ready and/or AI daemon can serve OpenCV stain detect.
     */
    public boolean isOpencvStainDetectSessionActive() {
        return opencvStainDetectActive || AiDaemonSupervisor.getInstance().isReady();
    }

    /** Always 0 on product path — OpenCV session lives in the daemon. */
    public long getOpencvStainDetectHandleForNative() {
        return 0L;
    }

    @NonNull
    public File getOpencvStainDetectLiveOutputDir() {
        return createOpencvStainDetectOutputDir(StainDetectSource.LIVE);
    }

    /** Product path: libs are loaded inside the daemon process, not the App. */
    public boolean areNativeLibrariesLoaded() {
        return AiDaemonSupervisor.getInstance().isReady();
    }

    private void destroyOpencvStainDetectSession() {
        opencvStainDetectActive = false;
        lensGuardAssetsDeployed = false;
    }

    @NonNull
    private String opencvStainDetectUnavailableMessage() {
        if (!AiDaemonSupervisor.getInstance().isReady()) {
            return "AI daemon not ready";
        }
        return "OpenCV stain detect session not available";
    }

    /**
     * Current engine capability snapshot. Valid after {@link #start(Context)} succeeds until {@link #stop()}.
     */
    public AiEngineCapabilityProfile getCapabilities() {
        return capabilities;
    }

    /** From deployed {@code opencv_stain_detect.min_consecutive_ok_frames}. */
    public int getMinConsecutiveOkFrames() {
        return minConsecutiveOkFrames;
    }

    public int getBlueMinConsecutiveOkFrames() {
        return blueMinConsecutiveOkFrames;
    }

    /**
     * Whether typed stain infer is available in-process. Product path never loads libai; always false
     * unless a legacy in-process engine handle is active and RKNN infer is enabled.
     */
    public boolean isRknnStainDetectAvailable(@NonNull Context context) {
        if (!isRknnStainInferActive()) {
            return false;
        }
        if (AiNativeRuntime.blocksRknnSession()) {
            return false;
        }
        if (handle != 0) {
            return capabilities.isRknnStainDetectAvailable();
        }
        return false;
    }

    public long getHandle() {
        return handle;
    }

    public boolean isAiVisionPreviewClassificationEnabled() {
        return aiVisionPreviewClassificationEnabled;
    }

    public boolean isAiVisionPreviewDetectionEnabled() {
        return aiVisionPreviewDetectionEnabled;
    }

    public void setAiVisionPreviewClassificationEnabled(boolean enabled) {
        if (aiVisionPreviewClassificationEnabled == enabled) {
            return;
        }
        aiVisionPreviewClassificationEnabled = enabled;
        Log.i(TAG, "AI Vision preview classification mode enabled=" + enabled);
        if (enabled) {
            GlobalSoundManager.stopWarnSound();
        }
        if (handle != 0) {
            pushPreviewClassificationMode();
            pushCurrentLaserState();
        }
    }

    public void setAiVisionPreviewDetectionEnabled(boolean enabled) {
        if (aiVisionPreviewDetectionEnabled == enabled) {
            return;
        }
        aiVisionPreviewDetectionEnabled = enabled;
        Log.i(TAG, "AI Vision preview detection mode enabled=" + enabled);
        if (enabled) {
            GlobalSoundManager.stopWarnSound();
        }
        if (handle != 0) {
            pushPreviewDetectionMode();
        }
    }

    public void updateFrameSize(int width, int height) {
        if (width <= 0 || height <= 0) {
            return;
        }
        if (frameWidth == width && frameHeight == height) {
            return;
        }
        frameWidth = width;
        frameHeight = height;
        Log.i(TAG, "Updated stream frame size to " + width + "x" + height);
    }

    /**
     * Run one-shot image inference by JPG/JPEG path and save a result image file.
     */
    public InferenceImageResult rknnStainDetectFromJpgAndSaveResult(String imagePath) {
        if (!isRknnStainInferActive()) {
            return publishImageResultError(
                    imagePath, null, rknnStainDisabledMessage(), CODE_RKNN_STAIN_DISABLED
            );
        }
        if (handle == 0) {
            return publishImageResultError(
                    imagePath, null, engineUnavailableMessage(), -1
            );
        }

        File sourceFile = validateJpgInput(imagePath);
        if (sourceFile == null) {
            return publishImageResultError(
                    imagePath, null, "Invalid image path or unsupported file type", -2
            );
        }

        String outputPath = buildResultOutputPath(sourceFile.getName());
        if (outputPath == null) {
            return publishImageResultError(
                    imagePath, null, "Failed to create result output directory", -3
            );
        }

        int nativeCode;
        try {
            nativeCode = NativeBridge.guardedRknnStainDetectFromJpgAndSave(handle, sourceFile.getAbsolutePath(), outputPath);
        } catch (UnsatisfiedLinkError e) {
            Log.e(TAG, "nativeRknnStainDetectFromJpgAndSave not available", e);
            return publishImageResultError(
                    imagePath, outputPath, "nativeRknnStainDetectFromJpgAndSave is not available in current libai.so", -4
            );
        } catch (Exception e) {
            Log.e(TAG, "Infer JPG failed", e);
            return publishImageResultError(
                    imagePath, outputPath, "Exception during image inference: " + e.getMessage(), -5
            );
        }

        Log.i(TAG, "rknnStainDetectFromJpgAndSaveResult image=" + imagePath + " output=" + outputPath + " code=" + nativeCode);
        if (nativeCode != 0) {
            return publishImageResultError(
                    imagePath, outputPath, nativeInferErrorMessage(nativeCode), nativeCode
            );
        }
        File outputFile = new File(outputPath);
        if (!outputFile.isFile() || outputFile.length() <= 0) {
            return publishImageResultError(
                    imagePath, outputPath, "Result image file missing or empty after native inference", -6
            );
        }

        InferenceImageResult result = new InferenceImageResult(
                true, 0, "Image inference success", sourceFile.getAbsolutePath(), outputPath
        );
        EventBus.getDefault().post(new LensCheckResultImageEvent(
                0,
                RESULT_STATUS_OK,
                result.getMessage(),
                result.getSourceImagePath(),
                result.getResultImagePath(),
                true,
                null
        ));
        return result;
    }

    /**
     * Unified one-shot offline inference API returning a structured result via {@code nativeRknnStainDetectFromJpg}.
     */
    @NonNull
    public AiStainDetectResult rknnStainDetectFromJpg(@NonNull String imagePath) {
        long now = SystemClock.elapsedRealtime();
        if (!isRknnStainInferActive()) {
            return rknnStainDisabled("rknnStainDetectFromJpg", now, "imagePath=" + imagePath, "offline_infer");
        }
        if (handle == 0) {
            return logInferReturn(
                    "rknnStainDetectFromJpg",
                    AiStainDetectResultMapper.appError(-1, "ERROR", engineUnavailableMessage(), now, "offline_infer"),
                    "imagePath=" + imagePath);
        }
        File sourceFile = validateJpgInput(imagePath);
        if (sourceFile == null) {
            return logInferReturn(
                    "rknnStainDetectFromJpg",
                    AiStainDetectResultMapper.appError(-2, "ERROR", "Invalid image path or unsupported file type", now, "offline_infer"),
                    "imagePath=" + imagePath);
        }
        if (!unifiedInferCoordinator.tryBegin()) {
            return logInferReturn(
                    "rknnStainDetectFromJpg",
                    AiStainDetectResultMapper.appError(CODE_INFER_BUSY, "BUSY", "Inference busy (drop)", now, "offline_infer"),
                    "imagePath=" + imagePath);
        }
        try {
            NativeBridge.StainInferOutcome outcome = NativeBridge.guardedRknnStainDetectFromJpg(
                    handle, sourceFile.getAbsolutePath());
            return logInferReturn(
                    "rknnStainDetectFromJpg",
                    AiStainDetectResultMapper.fromStainInferOutcome(
                            outcome,
                            SystemClock.elapsedRealtime(),
                            "offline_infer"),
                    "imagePath=" + imagePath);
        } catch (Throwable t) {
            Log.e(TAG, "rknnStainDetectFromJpg failed", t);
            return logInferReturn(
                    "rknnStainDetectFromJpg",
                    AiStainDetectResultMapper.appError(-5, "ERROR",
                            "Exception during image inference: " + t.getMessage(),
                            SystemClock.elapsedRealtime(), "offline_infer"),
                    "imagePath=" + imagePath);
        } finally {
            unifiedInferCoordinator.end();
        }
    }

    /**
     * Unified one-shot NV12 inference via {@code nativeRknnStainDetectFromNv12} (direct buffer).
     */
    @NonNull
    public AiStainDetectResult rknnStainDetectFromNv12(@NonNull ByteBuffer nv12, int width, int height) {
        long start = SystemClock.elapsedRealtime();
        String trace = "width=" + width + " height=" + height + " direct=" + (nv12 != null && nv12.isDirect());
        if (!isRknnStainInferActive()) {
            return rknnStainDisabled("rknnStainDetectFromNv12", start, trace, "live_infer");
        }
        if (handle == 0) {
            return logInferReturn(
                    "rknnStainDetectFromNv12",
                    AiStainDetectResultMapper.appError(-1, "ERROR", engineUnavailableMessage(), start, "live_infer"),
                    trace);
        }
        if (width <= 0 || height <= 0 || nv12 == null) {
            return logInferReturn(
                    "rknnStainDetectFromNv12",
                    AiStainDetectResultMapper.appError(-2, "ERROR", "Invalid NV12 frame", start, "live_infer"),
                    trace);
        }
        if (!unifiedInferCoordinator.tryBegin()) {
            return logInferReturn(
                    "rknnStainDetectFromNv12",
                    AiStainDetectResultMapper.appError(CODE_INFER_BUSY, "BUSY", "Inference busy (drop)", start, "live_infer"),
                    trace);
        }
        try {
            NativeBridge.StainInferOutcome outcome = NativeBridge.guardedRknnStainDetectFromNv12(handle, nv12, width, height);
            return logInferReturn(
                    "rknnStainDetectFromNv12",
                    AiStainDetectResultMapper.fromStainInferOutcome(
                            outcome,
                            SystemClock.elapsedRealtime(),
                            "live_infer"),
                    trace);
        } catch (Throwable t) {
            Log.e(TAG, "rknnStainDetectFromNv12 failed", t);
            return logInferReturn(
                    "rknnStainDetectFromNv12",
                    AiStainDetectResultMapper.appError(-5, "ERROR", "Inference failed: " + t.getMessage(),
                            SystemClock.elapsedRealtime(), "live_infer"),
                    trace);
        } finally {
            unifiedInferCoordinator.end();
        }
    }

    /**
     * Unified one-shot RGBA inference via {@code nativeRknnStainDetectFromRgb} (skips YUV conversion).
     */
    @NonNull
    public AiStainDetectResult rknnStainDetectFromRgb(@NonNull ByteBuffer rgba,
                                                 int width,
                                                 int height,
                                                 int rowStrideBytes) {
        long start = SystemClock.elapsedRealtime();
        String trace = "width=" + width + " height=" + height + " stride=" + rowStrideBytes;
        if (!isRknnStainInferActive()) {
            return rknnStainDisabled("rknnStainDetectFromRgb", start, trace, "offline_infer");
        }
        if (handle == 0) {
            return logInferReturn(
                    "rknnStainDetectFromRgb",
                    AiStainDetectResultMapper.appError(-1, "ERROR", engineUnavailableMessage(), start, "offline_infer"),
                    trace);
        }
        if (width <= 0 || height <= 0 || rowStrideBytes <= 0 || rgba == null) {
            return logInferReturn(
                    "rknnStainDetectFromRgb",
                    AiStainDetectResultMapper.appError(-2, "ERROR", "Invalid RGB frame", start, "offline_infer"),
                    trace);
        }
        if (!unifiedInferCoordinator.tryBegin()) {
            return logInferReturn(
                    "rknnStainDetectFromRgb",
                    AiStainDetectResultMapper.appError(CODE_INFER_BUSY, "BUSY", "Inference busy (drop)", start, "offline_infer"),
                    trace);
        }
        try {
            NativeBridge.StainInferOutcome outcome = NativeBridge.guardedRknnStainDetectFromRgb(
                    handle, rgba, width, height, rowStrideBytes);
            return logInferReturn(
                    "rknnStainDetectFromRgb",
                    AiStainDetectResultMapper.fromStainInferOutcome(
                            outcome,
                            SystemClock.elapsedRealtime(),
                            "offline_infer"),
                    trace);
        } catch (Throwable t) {
            Log.e(TAG, "rknnStainDetectFromRgb failed", t);
            return logInferReturn(
                    "rknnStainDetectFromRgb",
                    AiStainDetectResultMapper.appError(-5, "ERROR", "Inference failed: " + t.getMessage(),
                            SystemClock.elapsedRealtime(), "offline_infer"),
                    trace);
        } finally {
            unifiedInferCoordinator.end();
        }
    }

    /**
     * Run native whole-video inference and save an annotated MP4.
     */
    public int rknnStainDetectFromVideoAndSave(String inputVideoPath, String outputVideoPath) {
        if (!isRknnStainInferActive()) {
            return CODE_RKNN_STAIN_DISABLED;
        }
        if (handle == 0) {
            return -1001;
        }
        File sourceFile = validateVideoInput(inputVideoPath);
        if (sourceFile == null || outputVideoPath == null || outputVideoPath.trim().isEmpty()) {
            return -1002;
        }
        try {
            if (!NativeBridge.isNativeRknnStainDetectFromVideoAndSaveLinked()) {
                Log.e(TAG, "nativeRknnStainDetectFromVideoAndSave not available in current libai.so; "
                        + "verify with: nm -D libai.so | grep nativeRknnStainDetectFromVideoAndSave");
                return -1008;
            }
            int code = NativeBridge.guardedRknnStainDetectFromVideoAndSave(
                    handle,
                    sourceFile.getAbsolutePath(),
                    outputVideoPath.trim());
            Log.i(TAG, "rknnStainDetectFromVideoAndSave input=" + sourceFile.getAbsolutePath()
                    + " output=" + outputVideoPath.trim()
                    + " code=" + code);
            return code;
        } catch (UnsatisfiedLinkError e) {
            Log.e(TAG, "nativeRknnStainDetectFromVideoAndSave not available in current libai.so; "
                    + "rebuild with 'make ai' and verify: nm -D libai.so | grep nativeRknnStainDetectFromVideoAndSave", e);
            return -1008;
        } catch (Exception e) {
            Log.e(TAG, "Infer video and save failed", e);
            return -1009;
        }
    }

    /**
     * @deprecated Legacy TextureView bitmap push path; live inference uses C++ StreamDetectPipeline.
     *             No production callers; retained only while RKNN_STAIN_INFER_ACTIVE may be re-enabled.
     */
    @Deprecated
    public void onBitmapFrame(Bitmap bitmap) {
        if (!isRknnStainInferActive()) {
            return;
        }
        if (handle == 0 || bitmap == null || bitmap.isRecycled()) {
            return;
        }
        if (!aiVisionLiveFrameGate.tryAccept(SystemClock.elapsedRealtime())) {
            return;
        }
        ThreadPoolExecutor ex = aiFrameExecutor;
        if (ex == null || ex.isShutdown()) {
            return;
        }
        Nv12FrameUtil.Frame frame = Nv12FrameUtil.fromBitmap(bitmap);
        if (frame == null) {
            return;
        }
        ByteBuffer data = frame.toDirectBuffer();
        int width = frame.width;
        int height = frame.height;
        try {
            ex.execute(() -> deliverNv12Payload(data, width, height));
        } catch (RejectedExecutionException e) {
            Log.w(TAG, "AI bitmap frame task rejected (executor shutting down)");
        }
    }

    private static ThreadPoolExecutor createAiFrameExecutor() {
        return new ThreadPoolExecutor(
                1,
                1,
                0L,
                TimeUnit.MILLISECONDS,
                new ArrayBlockingQueue<>(4),
                r -> {
                    Thread t = new Thread(r, "Ai-NV12");
                    t.setPriority(Thread.NORM_PRIORITY - 1);
                    return t;
                },
                new ThreadPoolExecutor.DiscardOldestPolicy() {
                    @Override
                    public void rejectedExecution(Runnable r, ThreadPoolExecutor e) {
                        Log.w(TAG, "AI frame queue saturated; discarding oldest pending frame");
                        super.rejectedExecution(r, e);
                    }
                });
    }

    private void shutdownAiFrameExecutor() {
        ThreadPoolExecutor ex = aiFrameExecutor;
        aiFrameExecutor = null;
        if (ex == null) {
            return;
        }
        ex.shutdown();
        try {
            if (!ex.awaitTermination(3, TimeUnit.SECONDS)) {
                ex.shutdownNow();
                ex.awaitTermination(1, TimeUnit.SECONDS);
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            ex.shutdownNow();
        }
    }

    private void deliverNv12Payload(ByteBuffer nv12, int width, int height) {
        if (!isRknnStainInferActive()) {
            return;
        }
        if (handle == 0) {
            return;
        }
        Nv12FrameUtil.Dimensions dims = Nv12FrameUtil.resolvePayloadDimensions(nv12, width, height);
        int w = dims.width;
        int h = dims.height;
        if (width != w || height != h) {
            updateFrameSize(w, h);
        }
        if (w < MIN_PUSH_FRAME_WIDTH || h < MIN_PUSH_FRAME_HEIGHT) {
            warnSubMinimumFrameSkipped(w, h);
            return;
        }
        boolean accepted = NativeBridge.guardedRknnStainDetectFromStream(handle, nv12, w, h);
        if (!accepted) {
            Log.w(TAG, "guardedRknnStainDetectFromStream rejected frame, marker=" + NativeBridge.latestStageMarker());
            return;
        }
        publishLastClsSnapshotIfDue();
    }

    public LensClsSnapshotEvent publishLastClsSnapshot() {
        if (handle == 0) {
            LensClsSnapshotEvent event = LensClsSnapshotEvent.invalid(null, "engine is not running");
            EventBus.getDefault().post(event);
            return event;
        }
        String rawJson = NativeBridge.guardedGetLastClsResult(handle);
        LensClsSnapshotEvent event = LensClsSnapshotEvent.fromJson(rawJson);
        if (event.isValid()) {
            Log.i(TAG, "Cls snapshot: classId=" + event.getClassId()
                    + " className=" + event.getClassName()
                    + " score=" + event.getScore()
                    + " source=" + event.getSource());
        } else {
            Log.d(TAG, "Cls snapshot not valid: error=" + event.getErrorMessage()
                    + " raw=" + event.getRawJson());
        }
        EventBus.getDefault().post(event);
        return event;
    }

    /** Resets live-weld sub-stream sampling after inference RTSP stops. */
    public void resetRknnLiveWeldFrameSampling() {
        liveWeldFrameGate.reset();
        liveWeldFramesAccepted = 0;
    }

    /**
     * @deprecated Live PR1 RKNN sampling moved to C++ StreamDetectPipeline; no production callers.
     */
    @Deprecated
    public boolean tryAcceptRknnLiveWeldInferSample() {
        if (!isRknnStainInferActive()) {
            return false;
        }
        if (handle == 0) {
            return false;
        }
        if (!liveWeldFrameGate.tryAccept(SystemClock.elapsedRealtime())) {
            return false;
        }
        logLiveWeldFrameAccepted();
        return true;
    }

    /** True while unified stain infer holds the native session (zero-point should defer). */
    public boolean isRknnStainInferBusy() {
        return unifiedInferCoordinator.isInFlight();
    }

    /** True while OpenCV stain-detect one-shot infer is in flight. */
    public boolean isOpencvStainDetectBusy() {
        return opencvStainDetectInferCoordinator.isInFlight();
    }

    /** Resets AI Vision live TextureView sampling gate. */
    public void resetRknnAiVisionLiveFrameSampling() {
        aiVisionLiveFrameGate.reset();
    }

    /** Resets OpenCV AI Vision live sampling gate. */
    public void resetOpencvAiVisionLiveFrameSampling() {
        opencvAiVisionLiveFrameGate.reset();
    }

    /** Resets OpenCV process-video sampling gate. */
    public void resetOpencvProcessVideoFrameSampling() {
        opencvProcessVideoFrameGate.reset();
    }

    /** @deprecated Live AI Vision OpenCV sampling moved to C++ StreamDetectPipeline; no production callers. */
    @Deprecated
    public boolean tryAcceptOpencvAiVisionLiveInferSample() {
        if (!isOpencvStainDetectSessionActive()) {
            return false;
        }
        return opencvAiVisionLiveFrameGate.tryAccept(SystemClock.elapsedRealtime());
    }

    /** @deprecated Process-video uses session-internal sampling; no production callers. */
    @Deprecated
    public boolean tryAcceptOpencvProcessVideoInferSample() {
        if (!isOpencvStainDetectSessionActive()) {
            return false;
        }
        return opencvProcessVideoFrameGate.tryAccept(SystemClock.elapsedRealtime());
    }

    /**
     * One-shot OpenCV stain detect on NV12. Native writes {@code target.json} under a session output dir.
     */
    @NonNull
    public OpencvStainDetectResult opencvStainDetectFromNv12(@NonNull ByteBuffer nv12,
                                                    int width,
                                                    int height,
                                                    @NonNull String source) {
        return opencvStainDetectFromNv12(nv12, width, height, source, SystemClock.elapsedRealtime());
    }

    @NonNull
    OpencvStainDetectResult opencvStainDetectFromNv12(@NonNull ByteBuffer nv12,
                                             int width,
                                             int height,
                                             @NonNull String source,
                                             long timestampMs) {
        String trace = "width=" + width + " height=" + height + " source=" + source;
        if (!isOpencvStainDetectSessionActive()) {
            return logOpencvStainDetectReturn(
                    "opencvStainDetectFromNv12",
                    OpencvStainDetectResultMapper.appError(-1, opencvStainDetectUnavailableMessage(), timestampMs, source),
                    trace);
        }
        if (width <= 0 || height <= 0 || nv12 == null) {
            return logOpencvStainDetectReturn(
                    "opencvStainDetectFromNv12",
                    OpencvStainDetectResultMapper.appError(-2, "Invalid NV12 frame", timestampMs, source),
                    trace);
        }
        if (isRknnStainInferBusy()) {
            return logOpencvStainDetectReturn(
                    "opencvStainDetectFromNv12",
                    OpencvStainDetectResultMapper.appError(
                            CODE_OPENCV_STAIN_DETECT_DEFERRED, "Deferred (RKNN infer busy)", timestampMs, source),
                    trace + " reason=stain_infer_busy");
        }
        if (!opencvStainDetectInferCoordinator.tryBegin()) {
            return logOpencvStainDetectReturn(
                    "opencvStainDetectFromNv12",
                    OpencvStainDetectResultMapper.appError(CODE_INFER_BUSY, "Lens det busy (drop)", timestampMs, source),
                    trace);
        }
        try {
            File outputDir = createOpencvStainDetectOutputDir(source);
            Nv12FrameUtil.Payload payload = Nv12FrameUtil.preparePayload(nv12, width, height);
            long inferStartNs = System.nanoTime();
            String summary;
            if (AiDaemonSupervisor.getInstance().isReady()) {
                summary = AiDaemonSupervisor.getInstance().offlineOpencvStainFromNv12(
                        payload.buffer, payload.width, payload.height, outputDir.getAbsolutePath());
                if (summary == null) {
                    return logOpencvStainDetectReturn(
                            "opencvStainDetectFromNv12",
                            OpencvStainDetectResultMapper.appError(
                                    -5, "Daemon offline_infer_opencv_stain_nv12 failed",
                                    SystemClock.elapsedRealtime(), source),
                            trace + " outputDir=" + outputDir.getAbsolutePath());
                }
            } else {
                return logOpencvStainDetectReturn(
                        "opencvStainDetectFromNv12",
                        OpencvStainDetectResultMapper.appError(
                                -1, "AI daemon not ready", SystemClock.elapsedRealtime(), source),
                        trace);
            }
            long inferMs = (System.nanoTime() - inferStartNs) / 1_000_000L;
            return logOpencvStainDetectReturn(
                    "opencvStainDetectFromNv12",
                    OpencvStainDetectResultMapper.fromNativeSummary(
                            summary, payload.width, payload.height, SystemClock.elapsedRealtime(), source),
                    trace + " outputDir=" + outputDir.getAbsolutePath(),
                    inferMs);
        } catch (Throwable t) {
            Log.e(TAG, "opencvStainDetectFromNv12 failed", t);
            return logOpencvStainDetectReturn(
                    "opencvStainDetectFromNv12",
                    OpencvStainDetectResultMapper.appError(-5, "Lens det failed: " + t.getMessage(),
                            SystemClock.elapsedRealtime(), source),
                    trace);
        } finally {
            opencvStainDetectInferCoordinator.end();
        }
    }

    /**
     * One-shot OpenCV stain detect on a JPEG file path.
     */
    @NonNull
    public OpencvStainDetectResult opencvStainDetectFromJpg(@NonNull String imagePath) {
        long timestampMs = SystemClock.elapsedRealtime();
        if (!isOpencvStainDetectSessionActive()) {
            return logOpencvStainDetectReturn(
                    "opencvStainDetectFromJpg",
                    OpencvStainDetectResultMapper.appError(-1, opencvStainDetectUnavailableMessage(), timestampMs, StainDetectSource.OFFLINE),
                    "imagePath=" + imagePath);
        }
        File sourceFile = validateJpgInput(imagePath);
        if (sourceFile == null) {
            return logOpencvStainDetectReturn(
                    "opencvStainDetectFromJpg",
                    OpencvStainDetectResultMapper.appError(-2, "Invalid image path or unsupported file type",
                            timestampMs, StainDetectSource.OFFLINE),
                    "imagePath=" + imagePath);
        }
        if (isRknnStainInferBusy()) {
            return logOpencvStainDetectReturn(
                    "opencvStainDetectFromJpg",
                    OpencvStainDetectResultMapper.appError(
                            CODE_OPENCV_STAIN_DETECT_DEFERRED, "Deferred (RKNN infer busy)", timestampMs, StainDetectSource.OFFLINE),
                    "imagePath=" + imagePath + " reason=stain_infer_busy");
        }
        if (!opencvStainDetectInferCoordinator.tryBegin()) {
            return logOpencvStainDetectReturn(
                    "opencvStainDetectFromJpg",
                    OpencvStainDetectResultMapper.appError(CODE_INFER_BUSY, "Lens det busy (drop)", timestampMs, StainDetectSource.OFFLINE),
                    "imagePath=" + imagePath);
        }
        try {
            File outputDir = createOpencvStainDetectOutputDir(StainDetectSource.OFFLINE);
            long inferStartNs = System.nanoTime();
            String summary = AiDaemonSupervisor.getInstance().offlineOpencvStainFromJpg(
                    sourceFile.getAbsolutePath(), outputDir.getAbsolutePath());
            if (summary == null) {
                return logOpencvStainDetectReturn(
                        "opencvStainDetectFromJpg",
                        OpencvStainDetectResultMapper.appError(
                                -5, "Daemon offline_infer_opencv_stain_jpg failed",
                                SystemClock.elapsedRealtime(), StainDetectSource.OFFLINE),
                        "imagePath=" + imagePath + " outputDir=" + outputDir.getAbsolutePath());
            }
            long inferMs = (System.nanoTime() - inferStartNs) / 1_000_000L;
            return logOpencvStainDetectReturn(
                    "opencvStainDetectFromJpg",
                    OpencvStainDetectResultMapper.fromNativeSummary(
                            summary, 0, 0, SystemClock.elapsedRealtime(), StainDetectSource.OFFLINE),
                    "imagePath=" + imagePath + " outputDir=" + outputDir.getAbsolutePath(),
                    inferMs);
        } catch (Throwable t) {
            Log.e(TAG, "opencvStainDetectFromJpg failed", t);
            return logOpencvStainDetectReturn(
                    "opencvStainDetectFromJpg",
                    OpencvStainDetectResultMapper.appError(-5, "Lens det failed: " + t.getMessage(),
                            SystemClock.elapsedRealtime(), StainDetectSource.OFFLINE),
                    "imagePath=" + imagePath);
        } finally {
            opencvStainDetectInferCoordinator.end();
        }
    }

    private void logLiveWeldFrameAccepted() {
        int count = ++liveWeldFramesAccepted;
        if (count == 1 || count % 10 == 0) {
            Log.d(TAG, "Frame sample accept profile=LIVE_WELD intervalMs="
                    + liveWeldFrameGate.getSampleIntervalMs() + " count=" + count);
        }
    }

    private void publishLastClsSnapshotIfDue() {
        if (!capabilities.isClassificationEnabled()) {
            return;
        }
        long now = SystemClock.elapsedRealtime();
        long last = lastClsSnapshotPostElapsedMs;
        if (last > 0 && now - last < CLS_SNAPSHOT_MIN_INTERVAL_MS) {
            return;
        }
        lastClsSnapshotPostElapsedMs = now;
        publishLastClsSnapshot();
    }

    private void warnSubMinimumFrameSkipped(int width, int height) {
        long now = SystemClock.elapsedRealtime();
        if (now - lastSubMinFrameWarnElapsedMs < SUB_MIN_FRAME_WARN_THROTTLE_MS) {
            return;
        }
        lastSubMinFrameWarnElapsedMs = now;
        Log.w(TAG, "Skip nativeRknnStainDetectFromStream: " + width + "x" + height
                + " (minimum " + MIN_PUSH_FRAME_WIDTH + "x" + MIN_PUSH_FRAME_HEIGHT
                + " for engine stain ROI 700@(565,110); use 1920x1080 when possible)");
    }

    private AiEngineCapabilityProfile buildCapabilityProfile(String configPath) {
        File configFile = configPath == null ? null : new File(configPath);
        AiEngineConfigParser.warnStainScoreMode(configFile);
        AiEngineConfigParser.ModelFlags flags = AiEngineConfigParser.parseModelFlags(configFile);
        minConsecutiveOkFrames = AiEngineConfigParser.parseMinConsecutiveOkFrames(configFile);
        blueMinConsecutiveOkFrames = AiEngineConfigParser.parseBlueMinConsecutiveOkFrames(configFile);
        // Product path: live/offline OpenCV via daemon; in-process RKNN JNI stays off.
        boolean rknnEnabled = isRknnStainInferActive();
        return new AiEngineCapabilityProfile(
                flags.classificationEnabled,
                flags.detectionEnabled,
                rknnEnabled,
                rknnEnabled,
                true);
    }

    // --- MemoryCacheManager.OnCacheChangedListener ---

    @Override
    public void onCacheChanged(String key) {
        if (!CacheKey.DEVICE_STATUS_KEY.equals(key) || handle == 0) {
            return;
        }
        pushCurrentLaserState();
    }

    private void pushCurrentLaserState() {
        DeviceStatus status = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        if (status == null) {
            return;
        }
        boolean actualLaserOn = status.isLaserOn();
        boolean legacyPreviewCls = isLegacyPreviewClassificationLaserOverrideActive(status);
        boolean effectiveLaserOn = actualLaserOn || legacyPreviewCls;
        Boolean previous = lastLoggedLaserOn;
        if (previous != null && previous == effectiveLaserOn) {
            return;
        }
        Log.i(TAG, "Push laser state to native: actualOn=" + actualLaserOn
                + " effectiveOn=" + effectiveLaserOn
                + " previewCls=" + aiVisionPreviewClassificationEnabled
                + " previewClsNative=" + nativePreviewClassificationSupported
                + " previewClsLegacy=" + legacyPreviewCls
                + " previewDet=" + aiVisionPreviewDetectionEnabled
                + " previewDetNative=" + nativePreviewDetectionSupported);
        lastLoggedLaserOn = effectiveLaserOn;
        // Live Bit0 is pushed by AiDaemonSupervisor; legacy in-process handle path is unused.
        if (handle != 0) {
            NativeBridge.guardedSetLaserOn(handle, effectiveLaserOn);
        }
    }

    private boolean isPreviewLaserOverrideActive() {
        DeviceStatus status = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        return isLegacyPreviewClassificationLaserOverrideActive(status);
    }

    private boolean isLegacyPreviewClassificationLaserOverrideActive(DeviceStatus status) {
        return aiVisionPreviewClassificationEnabled
                && !nativePreviewClassificationSupported
                && (status == null || !status.isLaserOn());
    }

    private void pushAiVisionPreviewModes() {
        pushPreviewClassificationMode();
        pushPreviewDetectionMode();
    }

    private void pushPreviewClassificationMode() {
        if (handle == 0) {
            nativePreviewClassificationSupported = false;
            return;
        }
        boolean pushed = NativeBridge.guardedSetAiVisionPreviewClassificationEnabled(
                handle,
                aiVisionPreviewClassificationEnabled);
        if (nativePreviewClassificationSupported != pushed) {
            lastLoggedLaserOn = null;
        }
        nativePreviewClassificationSupported = pushed;
        if (!pushed) {
            Log.w(TAG, "Native AI Vision preview classification switch unavailable; legacy laser override fallback may be used");
        }
    }

    private void pushPreviewDetectionMode() {
        if (handle == 0) {
            nativePreviewDetectionSupported = false;
            return;
        }
        boolean pushed = NativeBridge.guardedSetAiVisionPreviewDetectionEnabled(
                handle,
                aiVisionPreviewDetectionEnabled);
        nativePreviewDetectionSupported = pushed;
        if (!pushed) {
            Log.w(TAG, "Native AI Vision preview detection switch unavailable; preview det will wait for updated libai.so");
        }
    }

    private static boolean isPreviewDetectionMessage(String message) {
        return message != null && message.contains("\"source\":\"preview_det\"");
    }

    private File validateJpgInput(String imagePath) {
        if (imagePath == null) {
            return null;
        }
        String trimmedPath = imagePath.trim();
        if (trimmedPath.isEmpty()) {
            return null;
        }
        String lower = trimmedPath.toLowerCase(Locale.ROOT);
        if (!lower.endsWith(".jpg") && !lower.endsWith(".jpeg")) {
            return null;
        }
        File sourceFile = new File(trimmedPath);
        if (!sourceFile.exists() || !sourceFile.isFile() || !sourceFile.canRead() || sourceFile.length() <= 0) {
            return null;
        }
        return sourceFile;
    }

    private File validateVideoInput(String videoPath) {
        if (videoPath == null) {
            return null;
        }
        String trimmedPath = videoPath.trim();
        if (trimmedPath.isEmpty()) {
            return null;
        }
        File sourceFile = new File(trimmedPath).getAbsoluteFile();
        if (!sourceFile.exists() || !sourceFile.isFile() || !sourceFile.canRead() || sourceFile.length() <= 0L) {
            Log.e(TAG, "Invalid video path: " + videoPath);
            return null;
        }
        return sourceFile;
    }

    private String buildResultOutputPath(String sourceFileName) {
        File primaryDir = new File(DEFAULT_RESULT_DIR);
        if (!primaryDir.exists() && !primaryDir.mkdirs()) {
            if (appContext == null) {
                return null;
            }
            File fallback = appContext.getExternalFilesDir("lens_guard/result");
            if (fallback == null) {
                return null;
            }
            if (!fallback.exists() && !fallback.mkdirs()) {
                return null;
            }
            primaryDir = fallback;
        }
        if (!primaryDir.isDirectory() || !primaryDir.canWrite()) {
            return null;
        }
        String baseName = sourceFileName;
        int dotIndex = sourceFileName.lastIndexOf('.');
        if (dotIndex > 0) {
            baseName = sourceFileName.substring(0, dotIndex);
        }
        String stamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(new Date());
        return new File(primaryDir, baseName + "_result_" + stamp + ".jpg").getAbsolutePath();
    }

    private static String nativeInferErrorMessage(int code) {
        switch (code) {
            case -1:
                return "Invalid argument";
            case -2:
                return "Image read failed";
            case -3:
                return "Model inference failed";
            case -4:
                return "Result image save failed";
            default:
                return "Native inference failed with code " + code;
        }
    }

    @NonNull
    private File createOpencvStainDetectOutputDir(@NonNull String sessionKey) {
        Context context = appContext;
        File base;
        if (context != null) {
            try {
                AssetDeployer paths = AssetDeployer.deploy(context);
                base = new File(paths.getProjectRoot(), "opencv_stain_detect");
            } catch (Throwable t) {
                base = context.getExternalFilesDir("lens_guard/opencv_stain_detect");
            }
        } else {
            base = new File(DEFAULT_RESULT_DIR, "opencv_stain_detect");
        }
        File sessionDir = new File(base, sessionKey + "_" + System.currentTimeMillis());
        //noinspection ResultOfMethodCallIgnored
        sessionDir.mkdirs();
        return sessionDir;
    }

    @NonNull
    private AiStainDetectResult rknnStainDisabled(@NonNull String api,
                                                  long start,
                                                  @NonNull String trace,
                                                  @Nullable String source) {
        return logInferReturn(
                api,
                AiStainDetectResultMapper.appError(
                        CODE_RKNN_STAIN_DISABLED,
                        "DISABLED",
                        rknnStainDisabledMessage(),
                        start,
                        source),
                trace);
    }

    @NonNull
    private static String rknnStainDisabledMessage() {
        return "RKNN stain infer inactive (RKNN_STAIN_INFER_ACTIVE=false)";
    }

    @NonNull
    private OpencvStainDetectResult logOpencvStainDetectReturn(@NonNull String api,
                                                 @NonNull OpencvStainDetectResult result,
                                                 @NonNull String request) {
        return logOpencvStainDetectReturn(api, result, request, -1L);
    }

    @NonNull
    private OpencvStainDetectResult logOpencvStainDetectReturn(@NonNull String api,
                                                 @NonNull OpencvStainDetectResult result,
                                                 @NonNull String request,
                                                 long inferMs) {
        StringBuilder line = new StringBuilder(api).append(" return")
                .append(" req={").append(request).append('}')
                .append(" success=").append(result.success)
                .append(" code=").append(result.code)
                .append(" source=").append(result.source)
                .append(" image=").append(result.imageWidth).append('x').append(result.imageHeight)
                .append(" target=(").append(result.targetX).append(',').append(result.targetY).append(')')
                .append(" msg=").append(result.message);
        if (inferMs >= 0L) {
            line.append(" infer_ms=").append(inferMs);
        }
        Log.i(TAG, line.toString());
        return result;
    }

    @NonNull
    private AiStainDetectResult logInferReturn(@NonNull String api,
                                                    @NonNull AiStainDetectResult result,
                                                    @NonNull String request) {
        Log.i(TAG, api + " return"
                + " req={" + request + "}"
                + " success=" + result.success
                + " code=" + result.code
                + " level=" + result.level
                + " status=" + result.status
                + " source=" + result.source
                + " image=" + result.imageWidth + "x" + result.imageHeight
                + " boxes=" + result.boxes.size()
                + " msg=" + result.message);
        return result;
    }

    private InferenceImageResult publishImageResultError(String sourcePath,
                                                         String resultPath,
                                                         String errorMessage,
                                                         int code) {
        Log.e(TAG, "rknnStainDetectFromJpgAndSaveResult failed image=" + sourcePath + " result=" + resultPath + " code=" + code + " error=" + errorMessage);
        InferenceImageResult result = new InferenceImageResult(false, code, errorMessage, sourcePath, resultPath);
        EventBus.getDefault().post(new LensCheckResultImageEvent(
                -1,
                RESULT_STATUS_ERROR,
                errorMessage,
                sourcePath,
                resultPath,
                false,
                errorMessage
        ));
        return result;
    }

    public static class InferenceImageResult {
        private final boolean success;
        private final int code;
        private final String message;
        private final String sourceImagePath;
        private final String resultImagePath;

        public InferenceImageResult(boolean success,
                                    int code,
                                    String message,
                                    String sourceImagePath,
                                    String resultImagePath) {
            this.success = success;
            this.code = code;
            this.message = message;
            this.sourceImagePath = sourceImagePath;
            this.resultImagePath = resultImagePath;
        }

        public boolean isSuccess() {
            return success;
        }

        public int getCode() {
            return code;
        }

        public String getMessage() {
            return message;
        }

        public String getSourceImagePath() {
            return sourceImagePath;
        }

        public String getResultImagePath() {
            return resultImagePath;
        }
    }
}
