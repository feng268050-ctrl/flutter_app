package com.lasercyber.lws.ai;
import com.lasercyber.lws.ai.Nv12FrameUtil;
import com.lasercyber.lws.ai.model.AiStainDetectResult;
import com.lasercyber.lws.ai.stream.StreamDetectNativeCallback;

import android.content.Context;
import android.os.Process;
import android.util.Log;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ai.bridge.AiLibraryDirectory;
import com.lasercyber.lws.ai.bridge.AiNativeRuntime;
import com.lasercyber.lws.ui.common.config.DeviceModelConfig;

import java.io.File;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.Locale;
import java.util.concurrent.Callable;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;
import java.util.concurrent.locks.ReentrantLock;

/**
 * JNI bridge to the native COREDEX lens-guard detection engine (libai.so).
 * <p>
 * The engine does NOT open a camera itself. The machine-side app must push decoded
 * NV12 frames via {@link #nativeRknnStainDetectFromStream}. Legacy decoder callbacks that
 * emit planar I420 MUST convert at ingress with {@link Nv12FrameUtil#i420DirectToNv12Direct}.
 * <p>
 * <b>Typical usage from an Activity or Service:</b>
 * <pre>
 *   // 1. Create engine
 *   long handle = NativeBridge.nativeCreate(configPath, projectRoot);
 *   NativeBridge.nativeSetListener(handle, myListener);
 *   NativeBridge.nativeStart(handle);
 *
 *   // 2. Push frames (NV12 direct buffer)
 *   //      NativeBridge.nativeRknnStainDetectFromStream(handle, nv12, width, height, cameraType);
 *
 *   // 3. Push laser state from DeviceStatus
 *   //    NativeBridge.nativeSetLaserOn(handle, deviceStatus.isLaserOn());
 *
 *   // 4. Shutdown
 *   NativeBridge.nativeStop(handle);
 *   NativeBridge.nativeDestroy(handle);
 * </pre>
 */
public class NativeBridge {

    private static final String TAG = "NativeBridge";
    private static volatile boolean LIBS_LOADED = false;
    private static final ConcurrentHashMap<Long, GuardedSession> SESSIONS = new ConcurrentHashMap<>();
    private static final AtomicLong CALL_SEQ = new AtomicLong(0L);
    private static final AtomicReference<String> LAST_STAGE_MARKER = new AtomicReference<>("none");
    private static final ThreadLocal<Boolean> IS_RKNN_THREAD = new ThreadLocal<>();
    private static final ExecutorService RKNN_EXECUTOR = Executors.newSingleThreadExecutor(r -> {
        Thread thread = new Thread(r, "mj-laser-thread-rknn");
        thread.setDaemon(true);
        return thread;
    });

    /** ROM {@code camera_type} passed to native stain JNI; native ignores until RED_LIGHT path ships. */
    public static int nativeCameraTypeValue() {
        return DeviceModelConfig.getCameraType().getValue();
    }

    enum SessionState {
        NEW,
        INITIALIZED,
        RUNNING,
        DESTROYED
    }

    private enum ErrorCategory {
        OK,
        INVALID_ARGUMENT,
        INVALID_STATE,
        CONCURRENT_ACCESS,
        NATIVE_ERROR
    }

    private static final class GuardedSession {
        final long handle;
        final ReentrantLock lock = new ReentrantLock();
        volatile SessionState state;

        GuardedSession(long handle) {
            this.handle = handle;
            this.state = SessionState.NEW;
        }
    }

    /**
     * 按 APK {@code jniLibs} 路径加载 so（{@code make ai} 后随 APK 安装）。
     * 与 YOLO 端约定一致：先依赖库，再加载 libai.so。
     */
    public static void ensureLoaded(Context context) {
        runOnRknnThreadUnchecked("init", 0L, () -> ensureLoadedOnRknnThread(context));
    }

    /** Whether {@link #ensureLoaded} has successfully loaded APK jniLibs (including {@code libai.so}). */
    public static boolean areLibrariesLoaded() {
        return LIBS_LOADED;
    }

    private static void ensureLoadedOnRknnThread(Context context) {
        if (LIBS_LOADED) {
            return;
        }
        synchronized (NativeBridge.class) {
            if (LIBS_LOADED) {
                return;
            }
            File libDir = AiLibraryDirectory.resolveNativeLibDir(context);
            if (libDir == null) {
                throw new UnsatisfiedLinkError("AI native libs missing. Run 'make ai' before 'make build', "
                        + "then install or upgrade the APK.");
            }
            Log.i(TAG, "ensureLoaded using ai lib dir=" + libDir.getAbsolutePath()
                    + " variant=" + AiLibraryDirectory.buildTimeVariant());

            loadRequiredSo(libDir, "libc++_shared.so");
            loadRequiredSo(libDir, "librknnrt.so");
            File mppSo = new File(libDir, "libmpp.so");
            if (mppSo.isFile()) {
                loadRequiredSo(libDir, "libmpp.so");
            }
            loadRequiredSo(libDir, "libai.so");

            verifyRknnStainDetectSymbolsOrThrow(new File(libDir, "libai.so"));
            resetNativeRknnStainDetectLinkCache();
            resetNativeRknnStainDetectFromVideoAndSaveLinkCache();
            LIBS_LOADED = true;
        }
    }

    private static void loadRequiredSo(File libDir, String soName) {
        File soFile = new File(libDir, soName);
        if (!soFile.isFile()) {
            throw new UnsatisfiedLinkError("Missing required so: " + soFile.getAbsolutePath());
        }
        Log.i(TAG, "System.load target so=" + soFile.getAbsolutePath());
        System.load(soFile.getAbsolutePath());
    }

    // ── Lifecycle ───────────────────────────────────────────

    /**
     * Create the native scheduler.
     *
     * @param configPath  absolute path to config.yaml on device
     * @param projectRoot absolute path to the engine working directory on device
     * @return opaque native handle (0 on failure)
     */
    public static native long nativeCreate(String configPath, String projectRoot, int cameraType);

    /** Start the scheduler main loop on a background thread. */
    public static native void nativeStart(long handle);

    /** Stop the scheduler and wait for the worker thread to finish. */
    public static native void nativeStop(long handle);

    /** Release all native resources. Call after nativeStop. */
    public static native void nativeDestroy(long handle);

    // ── Frame injection (NV12 direct buffer) ─

    /**
     * Push a decoded NV12 direct buffer to the native detection engine.
     * <p>
     * <b>Format:</b> NV12 (Y + interleaved UV), size = width * height * 3 / 2.
     * Legacy I420 decoder callbacks MUST convert via {@link Nv12FrameUtil#i420DirectToNv12Direct}
     * before calling this method.
     */
    public static native void nativeRknnStainDetectFromStream(long handle, ByteBuffer nv12, int width, int height,
                                                              int cameraType);

    /**
     * Run one-shot inference by JPEG file path and save the rendered result image.
     * <p>
     * This entry is intended for offline testing workflows where the caller already has
     * a sample image file (for example, `/sdcard/lws/picture/input.jpg`) and needs a
     * persistent result artifact for upload/download validation.
     *
     * @param handle     native engine handle from {@link #nativeCreate}
     * @param imagePath  absolute path to source JPEG image
     * @param outputPath absolute path where result JPEG should be written
     * @return 0 for success, non-zero native error code on failure
     */
    public static native int nativeRknnStainDetectFromJpgAndSave(long handle, String imagePath, String outputPath,
                                                                 int cameraType);

    /** One-shot RKNN stain detect by JPEG path; fills {@link StainInferOutcome} directly. */
    public static native StainInferOutcome nativeRknnStainDetectFromJpg(long handle, String imagePath, int cameraType);

    /** One-shot RKNN stain infer by direct RGBA {@link ByteBuffer}. */
    public static native StainInferOutcome nativeRknnStainDetectFromRgb(
            long handle,
            ByteBuffer rgb,
            int width,
            int height,
            int rowStrideBytes,
            int cameraType);

    /** One-shot RKNN stain infer by direct NV12 {@link ByteBuffer}. */
    public static native StainInferOutcome nativeRknnStainDetectFromNv12(
            long handle,
            ByteBuffer nv12,
            int width,
            int height,
            int cameraType);

    /**
     * Run stain detection on a saved video file and write an annotated MP4.
     * <p>
     * The native side owns frame decode, inference, box drawing, and output encode.
     * Call through {@link #guardedRknnStainDetectFromVideoAndSave(long, String, String)} so the
     * work is serialized on the RKNN thread with the rest of the engine calls.
     *
     * @return 0 on success, negative native error code on failure
     */
    public static native int nativeRknnStainDetectFromVideoAndSave(long handle, String inputVideoPath,
                                                                   String outputVideoPath, int cameraType);

    // ── Laser state (from DeviceStatus.isLaserOn) ──────────

    /**
     * Push laser on/off state from the machine-side app to the native detection engine.
     * <p>
     * The app should monitor {@code CacheKey.DEVICE_STATUS_KEY} via
     * {@code MemoryCacheManager} and invoke this whenever {@code DeviceStatus.isLaserOn()}
     * changes. The native engine uses this to switch between IDLE and MONITORING modes.
     *
     * @param on true if laser is firing, false otherwise
     */
    public static native void nativeSetLaserOn(long handle, boolean on);

    // ── Native RTSP stream detect pipeline (MediaMTX PR1) ──

    /** Start independent C++ detect decode pipeline; returns false when RTSP/demux unavailable. */
    public static native boolean nativeStartStreamDetect(String rtspUrl);

    public static native void nativeStopStreamDetect();

    public static native void nativeSetStreamDetectLaserOn(boolean on);

    public static native void nativeSetStreamDetectBurstMode(boolean burst);

    public static native boolean nativeIsStreamDetectRunning();

    public static native void nativeSetStreamDetectListener(@Nullable StreamDetectNativeCallback listener);

    public static native void nativeConfigureStreamDetect(long opencvStainHandle,
                                                          String outputDir,
                                                          int cameraType,
                                                          boolean lensDetEnabled,
                                                          boolean rknnStreamEnabled,
                                                          long rknnSessionHandle,
                                                          long zeroPointHandle,
                                                          boolean zeroPointEnabled,
                                                          long edgeDrawingHandle,
                                                          boolean edgeDrawingEnabled,
                                                          String sessionSource);

    public static native void nativeSetStreamDetectZeroPointTargetMode(int targetMode);

    /**
     * Enable AI Vision preview classification while the real laser is off.
     * Native updates only the classification cache and does not enter MONITORING.
     */
    public static native void nativeSetAiVisionPreviewClassificationEnabled(long handle, boolean enabled);

    /**
     * Enable low-rate AI Vision preview detection while the real laser is off.
     * Native emits side-effect-free check results with message.source=preview_det.
     */
    public static native void nativeSetAiVisionPreviewDetectionEnabled(long handle, boolean enabled);

    // ── OpenCV stain detect (valid-region bright blob; same goal as RKNN, different method) ──

    /**
     * Creates an independent OpenCV stain-detect session from deployed {@code config.yaml}.
     * Does not require an RKNN engine handle (emulator-safe).
     */
    public static native long nativeCreateOpencvStainDetectSession(String configYamlPath,
                                                               String projectRoot,
                                                               int cameraType);

    public static native void nativeDestroyOpencvStainDetectSession(long opencvStainDetectHandle);

    /**
     * OpenCV valid-region stain detect. Each target is written to {@code outputDir/target.json}
     * with only {@code name}, {@code x}, {@code y}. Returns summary JSON listing file paths.
     *
     * @param opencvStainDetectHandle session from {@link #nativeCreateOpencvStainDetectSession}
     */
    public static native String nativeOpencvStainDetectFromJpg(long opencvStainDetectHandle,
                                                             String imagePath,
                                                             String outputDir,
                                                             int cameraType);

    public static native String nativeOpencvStainDetectFromRgb(long opencvStainDetectHandle,
                                                           ByteBuffer rgba,
                                                           int width,
                                                           int height,
                                                           int rowStrideBytes,
                                                           String outputDir,
                                                           int cameraType);

    public static native String nativeOpencvStainDetectFromNv12(long opencvStainDetectHandle,
                                                           ByteBuffer nv12,
                                                           int width,
                                                           int height,
                                                           String outputDir,
                                                           int cameraType);

    // ── Zero-point (single-frame detect; App owns temporal logic) ──

    public static native long nativeCreateOpencvZeroPointDetector(String roiJsonPath,
                                                            float tolerancePx);

    public static native void nativeDestroyOpencvZeroPointDetector(long zpHandle);

    public static native void nativeSetOpencvZeroPointDetectTargetMode(long zpHandle, int mode);

    public static native String nativeOpencvZeroPointDetectFromJpg(long zpHandle, String imagePath);

    public static native String nativeOpencvZeroPointDetectFromRgb(long zpHandle,
                                                       ByteBuffer rgba,
                                                       int width,
                                                       int height,
                                                       int rowStrideBytes);

    public static native String nativeOpencvZeroPointDetectFromNv12(long zpHandle,
                                                          ByteBuffer nv12,
                                                          int width,
                                                          int height);

    // ── EdgeDrawing zero-point (single-frame detect; App owns temporal logic) ──

    public static native long nativeCreateOpencvEdgeDrawingDetector(String roiJsonPath,
                                                            float tolerancePx);

    public static native void nativeDestroyOpencvEdgeDrawingDetector(long edHandle);

    public static native String nativeOpencvEdgeDrawingDetectFromJpg(long edHandle, String imagePath);

    public static native String nativeOpencvEdgeDrawingDetectFromRgb(long edHandle,
                                                       ByteBuffer rgba,
                                                       int width,
                                                       int height,
                                                       int rowStrideBytes);

    public static native String nativeOpencvEdgeDrawingDetectFromNv12(long edHandle,
                                                          ByteBuffer nv12,
                                                          int width,
                                                          int height);

    // ── State queries ───────────────────────────────────────

    /** @return 0 = IDLE, 1 = MONITORING, 2 = LOCKED, -1 = invalid handle */
    public static native int nativeGetState(long handle);

    /** @return contamination level: 0 (clean), 1 (mild), 2 (heavy) */
    public static native int nativeGetStainLevel(long handle);

    /** @return true if the lens is flagged as dirty (level >= 2) */
    public static native boolean nativeIsLensDirty(long handle);

    /**
     * Read the latest classification snapshot from native.
     * <p>
     * The native side owns inference, TopK, labels, thresholds, and result caching.
     * App code must treat this as a read-only UTF-8 JSON snapshot.
     */
    public static native String nativeGetLastClsResult(long handle);

    // ── Callback listener ───────────────────────────────────

    /**
     * Set a listener to receive asynchronous events from the native engine.
     * Pass null to remove the listener.
     * <p>
     * Callbacks may arrive on native worker threads; post to the main looper
     * if you need to update the UI.
     */
    public static native void nativeSetListener(long handle, NativeListener listener);

    public static String latestStageMarker() {
        return LAST_STAGE_MARKER.get();
    }

    public static long guardedCreate(String configPath, String projectRoot) {
        return runOnRknnThread("init", 0L, 0L, () -> guardedCreateOnRknnThread(configPath, projectRoot));
    }

    private static long guardedCreateOnRknnThread(String configPath, String projectRoot) {
        if (AiNativeRuntime.blocksRknnSession()) {
            emitStage("init", 0L, ErrorCategory.INVALID_STATE, AiNativeRuntime.CODE_RKNN_UNAVAILABLE,
                    "RKNN session blocked: " + AiNativeRuntime.rknnUnavailableMessage());
            return 0L;
        }
        if (configPath == null || configPath.trim().isEmpty()
                || projectRoot == null || projectRoot.trim().isEmpty()) {
            emitStage("init", 0L, ErrorCategory.INVALID_ARGUMENT, -1, "empty configPath or projectRoot");
            return 0L;
        }
        long handle = traceNativeCall("init", 0L, "nativeCreate",
                () -> nativeCreate(configPath, projectRoot, nativeCameraTypeValue()), 0L);
        if (handle == 0L) {
            emitStage("init", 0L, ErrorCategory.NATIVE_ERROR, -1, "nativeCreate returned 0");
            return 0L;
        }
        GuardedSession session = new GuardedSession(handle);
        session.state = SessionState.INITIALIZED;
        SESSIONS.put(handle, session);
        emitStage("init", handle, ErrorCategory.OK, 0, "session created");
        return handle;
    }

    public static boolean guardedStart(long handle) {
        if (AiNativeRuntime.blocksRknnSession()) {
            return false;
        }
        return runOnRknnThread("query", handle, false, () -> guardedStartOnRknnThread(handle));
    }

    private static boolean guardedStartOnRknnThread(long handle) {
        GuardedSession session = SESSIONS.get(handle);
        if (session == null) {
            emitStage("query", handle, ErrorCategory.INVALID_STATE, -1, "missing session at start");
            return false;
        }
        session.lock.lock();
        try {
            if (session.state != SessionState.INITIALIZED) {
                emitStage("query", handle, ErrorCategory.INVALID_STATE, -1, "start requires INITIALIZED state");
                return false;
            }
            traceNativeCall("query", handle, "nativeStart", () -> {
                nativeStart(handle);
                return null;
            }, null);
            session.state = SessionState.RUNNING;
            emitStage("query", handle, ErrorCategory.OK, 0, "session started");
            return true;
        } catch (Throwable t) {
            emitStage("query", handle, ErrorCategory.NATIVE_ERROR, -1, "nativeStart failed: " + t.getMessage());
            return false;
        } finally {
            session.lock.unlock();
        }
    }

    public static void guardedSetListener(long handle, NativeListener listener) {
        runOnRknnThread("query", handle, null, () -> {
            guardedSetListenerOnRknnThread(handle, listener);
            return null;
        });
    }

    private static void guardedSetListenerOnRknnThread(long handle, NativeListener listener) {
        GuardedSession session = SESSIONS.get(handle);
        if (session == null) {
            emitStage("query", handle, ErrorCategory.INVALID_STATE, -1, "missing session at setListener");
            return;
        }
        session.lock.lock();
        try {
            if (session.state == SessionState.DESTROYED) {
                emitStage("query", handle, ErrorCategory.INVALID_STATE, -1, "session destroyed at setListener");
                return;
            }
            traceNativeCall("query", handle, "nativeSetListener", () -> {
                nativeSetListener(handle, listener);
                return null;
            }, null);
            emitStage("query", handle, ErrorCategory.OK, 0, "listener attached");
        } catch (Throwable t) {
            emitStage("query", handle, ErrorCategory.NATIVE_ERROR, -1, "nativeSetListener failed: " + t.getMessage());
        } finally {
            session.lock.unlock();
        }
    }

    public static void guardedStopAndDestroy(long handle) {
        runOnRknnThread("destroy", handle, null, () -> {
            guardedStopAndDestroyOnRknnThread(handle);
            return null;
        });
    }

    private static void guardedStopAndDestroyOnRknnThread(long handle) {
        GuardedSession session = SESSIONS.get(handle);
        if (session == null) {
            emitStage("destroy", handle, ErrorCategory.INVALID_STATE, -1, "missing session at stopDestroy");
            return;
        }
        session.lock.lock();
        try {
            if (session.state == SessionState.DESTROYED) {
                emitStage("destroy", handle, ErrorCategory.INVALID_STATE, -1, "already destroyed");
                return;
            }
            if (session.state == SessionState.RUNNING) {
                traceNativeCall("destroy", handle, "nativeStop", () -> {
                    nativeStop(handle);
                    return null;
                }, null);
                session.state = SessionState.INITIALIZED;
                emitStage("destroy", handle, ErrorCategory.OK, 0, "nativeStop complete");
            }
            traceNativeCall("destroy", handle, "nativeDestroy", () -> {
                nativeDestroy(handle);
                return null;
            }, null);
            session.state = SessionState.DESTROYED;
            SESSIONS.remove(handle);
            emitStage("destroy", handle, ErrorCategory.OK, 0, "nativeDestroy complete");
        } catch (Throwable t) {
            emitStage("destroy", handle, ErrorCategory.NATIVE_ERROR, -1, "stopDestroy failed: " + t.getMessage());
        } finally {
            session.lock.unlock();
        }
    }

    public static boolean guardedRknnStainDetectFromStream(long handle, ByteBuffer nv12, int width, int height) {
        if (AiNativeRuntime.blocksRknnSession()) {
            return false;
        }
        return runOnRknnThread("input", handle, false, () -> guardedRknnStainDetectFromStreamOnRknnThread(handle, nv12, width, height));
    }

    private static boolean guardedRknnStainDetectFromStreamOnRknnThread(long handle, ByteBuffer nv12, int width, int height) {
        GuardedSession session = SESSIONS.get(handle);
        if (session == null) {
            emitStage("input", handle, ErrorCategory.INVALID_STATE, -1, "missing session at pushFrame");
            return false;
        }
        String validationError = validateFrameInput(nv12, width, height, session.state);
        if (validationError != null) {
            emitStage("input", handle, ErrorCategory.INVALID_ARGUMENT, -1, validationError);
            return false;
        }
        if (!session.lock.tryLock()) {
            emitStage("input", handle, ErrorCategory.CONCURRENT_ACCESS, -1, "concurrent pushFrame access");
            return false;
        }
        try {
            if (session.state != SessionState.RUNNING) {
                emitStage("input", handle, ErrorCategory.INVALID_STATE, -1, "pushFrame requires RUNNING state");
                return false;
            }
            ByteBuffer prepared = prepareDirectNv12ForNative(nv12, width, height);
            traceNativeCall("input", handle, "nativeRknnStainDetectFromStream", () -> {
                nativeRknnStainDetectFromStream(handle, prepared, width, height, nativeCameraTypeValue());
                return null;
            }, null);
            emitStage("input", handle, ErrorCategory.OK, 0, "frame pushed");
            return true;
        } catch (Throwable t) {
            emitStage("input", handle, ErrorCategory.NATIVE_ERROR, -1, "nativeRknnStainDetectFromStream failed: " + t.getMessage());
            return false;
        } finally {
            session.lock.unlock();
        }
    }

    public static int guardedRknnStainDetectFromJpgAndSave(long handle, String imagePath, String outputPath) {
        if (AiNativeRuntime.blocksRknnSession()) {
            return AiNativeRuntime.CODE_RKNN_UNAVAILABLE;
        }
        return runOnRknnThread("run", handle, -1006, () -> guardedRknnStainDetectFromJpgAndSaveOnRknnThread(handle, imagePath, outputPath));
    }

    private static int guardedRknnStainDetectFromJpgAndSaveOnRknnThread(long handle, String imagePath, String outputPath) {
        GuardedSession session = SESSIONS.get(handle);
        if (session == null) {
            emitStage("run", handle, ErrorCategory.INVALID_STATE, -1, "missing session at infer");
            return -1001;
        }
        if (imagePath == null || imagePath.trim().isEmpty() || outputPath == null || outputPath.trim().isEmpty()) {
            emitStage("run", handle, ErrorCategory.INVALID_ARGUMENT, -1, "invalid imagePath/outputPath");
            return -1002;
        }
        if (!session.lock.tryLock()) {
            emitStage("run", handle, ErrorCategory.CONCURRENT_ACCESS, -1, "concurrent infer access");
            return -1003;
        }
        try {
            if (session.state != SessionState.RUNNING) {
                emitStage("run", handle, ErrorCategory.INVALID_STATE, -1, "infer requires RUNNING state");
                return -1004;
            }
            int code = traceNativeCall("run", handle, "nativeRknnStainDetectFromJpgAndSave",
                    () -> nativeRknnStainDetectFromJpgAndSave(handle, imagePath, outputPath, nativeCameraTypeValue()), -1007);
            emitStage("run", handle, code == 0 ? ErrorCategory.OK : ErrorCategory.NATIVE_ERROR,
                    code, nativeInferStageDetail(code));
            return code;
        } catch (Throwable t) {
            emitStage("run", handle, ErrorCategory.NATIVE_ERROR, -1, "nativeRknnStainDetectFromJpgAndSave failed: " + t.getMessage());
            return -1005;
        } finally {
            session.lock.unlock();
        }
    }

    /**
     * Whether {@link #nativeRknnStainDetectFromVideoAndSave} is exported by the loaded {@code libai.so}.
     * Cached for the process after the first probe on the RKNN thread (requires {@link #ensureLoaded}).
     */
    public static boolean isNativeRknnStainDetectFromVideoAndSaveLinked() {
        Boolean cached = NATIVE_RKNN_STAIN_DETECT_FROM_VIDEO_AND_SAVE_LINKED;
        if (cached != null) {
            return cached;
        }
        if (!LIBS_LOADED) {
            return false;
        }
        boolean linked = runOnRknnThread("query", 0L, false, () -> probeNativeRknnStainDetectFromVideoAndSaveLinkedOnRknnThread());
        NATIVE_RKNN_STAIN_DETECT_FROM_VIDEO_AND_SAVE_LINKED = linked;
        return linked;
    }

    static void resetNativeRknnStainDetectFromVideoAndSaveLinkCache() {
        NATIVE_RKNN_STAIN_DETECT_FROM_VIDEO_AND_SAVE_LINKED = null;
    }

    private static volatile Boolean NATIVE_RKNN_STAIN_DETECT_FROM_VIDEO_AND_SAVE_LINKED;

    private static boolean probeNativeRknnStainDetectFromVideoAndSaveLinkedOnRknnThread() {
        try {
            nativeRknnStainDetectFromVideoAndSave(0L, null, null, nativeCameraTypeValue());
            return true;
        } catch (UnsatisfiedLinkError e) {
            Log.w(TAG, "nativeRknnStainDetectFromVideoAndSave is not exported by libai.so; "
                    + "rebuild with 'make ai' and verify with: nm -D libai.so | grep nativeRknnStainDetectFromVideoAndSave", e);
            return false;
        }
    }

    private static volatile Boolean NATIVE_RKNN_STAIN_DETECT_LINKED;
    private static volatile Boolean NATIVE_RKNN_STAIN_DETECT_FROM_JPG_LINKED;
    private static volatile Boolean NATIVE_RKNN_STAIN_DETECT_FROM_RGB_LINKED;
    private static volatile Boolean NATIVE_RKNN_STAIN_DETECT_FROM_NV12_LINKED;

    static void resetNativeRknnStainDetectLinkCache() {
        NATIVE_RKNN_STAIN_DETECT_LINKED = null;
        NATIVE_RKNN_STAIN_DETECT_FROM_JPG_LINKED = null;
        NATIVE_RKNN_STAIN_DETECT_FROM_RGB_LINKED = null;
        NATIVE_RKNN_STAIN_DETECT_FROM_NV12_LINKED = null;
    }

    public static boolean isNativeRknnStainDetectLinked() {
        return isNativeRknnStainDetectFromJpgLinked() && isNativeRknnStainDetectFromRgbLinked() && isNativeRknnStainDetectFromNv12Linked();
    }

    public static boolean isNativeRknnStainDetectFromJpgLinked() {
        Boolean cached = NATIVE_RKNN_STAIN_DETECT_FROM_JPG_LINKED;
        return cached != null && cached;
    }

    public static boolean isNativeRknnStainDetectFromRgbLinked() {
        Boolean cached = NATIVE_RKNN_STAIN_DETECT_FROM_RGB_LINKED;
        return cached != null && cached;
    }

    public static boolean isNativeRknnStainDetectFromNv12Linked() {
        Boolean cached = NATIVE_RKNN_STAIN_DETECT_FROM_NV12_LINKED;
        return cached != null && cached;
    }

    private static void verifyRknnStainDetectSymbolsOrThrow(File libaiSo) {
        String path = libaiSo.getAbsolutePath();
        String hint = "Rebuild with 'make ai' and verify: bash scripts/verify_libai_jni.sh " + path;
        if (!libaiSo.isFile()) {
            throw new UnsatisfiedLinkError("libai.so missing: " + path + ". " + hint);
        }
        try {
            byte[] image = Files.readAllBytes(libaiSo.toPath());
            verifySoContainsRknnStainDetectSymbols(image, path, hint);
        } catch (UnsatisfiedLinkError e) {
            throw e;
        } catch (IOException e) {
            throw new UnsatisfiedLinkError("Failed to read libai.so for symbol verification: "
                    + e.getMessage() + ". " + hint);
        }
        NATIVE_RKNN_STAIN_DETECT_FROM_JPG_LINKED = true;
        NATIVE_RKNN_STAIN_DETECT_FROM_RGB_LINKED = true;
        NATIVE_RKNN_STAIN_DETECT_FROM_NV12_LINKED = true;
        NATIVE_RKNN_STAIN_DETECT_LINKED = true;
        Log.i(TAG, "typed stain infer JNI verified in " + path);
    }

    private static void verifySoContainsRknnStainDetectSymbols(byte[] image, String path, String hint) {
        String[] required = {
                "nativeRknnStainDetectFromJpg",
                "nativeRknnStainDetectFromRgb",
                "nativeRknnStainDetectFromNv12"
        };
        for (String symbol : required) {
            String jni = "Java_com_lasercyber_lws_ai_NativeBridge_" + symbol;
            if (!containsAscii(image, jni)) {
                throw new UnsatisfiedLinkError("libai.so missing " + symbol + " in " + path + ". " + hint);
            }
        }
    }

    private static boolean containsAscii(byte[] haystack, String needle) {
        byte[] n = needle.getBytes(StandardCharsets.US_ASCII);
        if (n.length == 0 || haystack.length < n.length) {
            return false;
        }
        search:
        for (int i = 0; i <= haystack.length - n.length; i++) {
            for (int j = 0; j < n.length; j++) {
                if (haystack[i + j] != n[j]) {
                    continue search;
                }
            }
            return true;
        }
        return false;
    }

    public static StainInferOutcome guardedRknnStainDetectFromJpg(long handle, String imagePath) {
        if (AiNativeRuntime.blocksRknnSession()) {
            return stainInferEmulatorBlocked();
        }
        return runOnRknnThread("run", handle,
                stainInferError(-1006, "RKNN task failed before nativeRknnStainDetectFromJpg"),
                () -> guardedRknnStainDetectFromJpgOnRknnThread(handle, imagePath));
    }

    private static StainInferOutcome guardedRknnStainDetectFromJpgOnRknnThread(long handle, String imagePath) {
        GuardedSession session = SESSIONS.get(handle);
        if (session == null) {
            emitStage("run", handle, ErrorCategory.INVALID_STATE, -1, "missing session at infer image");
            return stainInferError(-1001, "missing session");
        }
        if (imagePath == null || imagePath.trim().isEmpty()) {
            emitStage("run", handle, ErrorCategory.INVALID_ARGUMENT, -1, "invalid imagePath");
            return stainInferError(-1002, "invalid imagePath");
        }
        if (!session.lock.tryLock()) {
            emitStage("run", handle, ErrorCategory.CONCURRENT_ACCESS, -1, "concurrent infer image access");
            return stainInferError(-1003, "concurrent infer image access");
        }
        try {
            if (session.state != SessionState.RUNNING) {
                emitStage("run", handle, ErrorCategory.INVALID_STATE, -1, "infer image requires RUNNING state");
                return stainInferError(-1004, "infer image requires RUNNING state");
            }
            StainInferOutcome fallback = stainInferError(-1007, "nativeRknnStainDetectFromJpg failed or unavailable");
            StainInferOutcome outcome = traceNativeCall("run", handle, "nativeRknnStainDetectFromJpg",
                    () -> nativeRknnStainDetectFromJpg(handle, imagePath, nativeCameraTypeValue()), fallback);
            emitStage("run", handle,
                    outcome != null && outcome.isSuccess() ? ErrorCategory.OK : ErrorCategory.NATIVE_ERROR,
                    outcome == null ? -1 : outcome.code,
                    "typed image infer returned");
            return outcome == null ? fallback : outcome;
        } finally {
            session.lock.unlock();
        }
    }

    public static StainInferOutcome guardedRknnStainDetectFromRgb(long handle, ByteBuffer rgb, int width, int height, int rowStrideBytes) {
        if (AiNativeRuntime.blocksRknnSession()) {
            return stainInferEmulatorBlocked();
        }
        return runOnRknnThread("run", handle,
                stainInferError(-1006, "RKNN task failed before nativeRknnStainDetectFromRgb"),
                () -> guardedRknnStainDetectFromRgbOnRknnThread(handle, rgb, width, height, rowStrideBytes));
    }

    private static StainInferOutcome guardedRknnStainDetectFromRgbOnRknnThread(long handle,
                                                                 ByteBuffer rgb,
                                                                 int width,
                                                                 int height,
                                                                 int rowStrideBytes) {
        GuardedSession session = SESSIONS.get(handle);
        if (session == null) {
            emitStage("run", handle, ErrorCategory.INVALID_STATE, -1, "missing session at infer rgb");
            return stainInferError(-1001, "missing session");
        }
        String validationError = validateDirectRgbBuffer(rgb, width, height, rowStrideBytes, session.state);
        if (validationError != null) {
            emitStage("run", handle, ErrorCategory.INVALID_ARGUMENT, -1, validationError);
            return stainInferError(-1, validationError);
        }
        if (!session.lock.tryLock()) {
            emitStage("run", handle, ErrorCategory.CONCURRENT_ACCESS, -1, "concurrent infer rgb access");
            return stainInferError(-1003, "concurrent infer rgb access");
        }
        try {
            if (session.state != SessionState.RUNNING) {
                emitStage("run", handle, ErrorCategory.INVALID_STATE, -1, "infer rgb requires RUNNING state");
                return stainInferError(-1004, "infer rgb requires RUNNING state");
            }
            StainInferOutcome fallback = stainInferError(-1007, "nativeRknnStainDetectFromRgb failed or unavailable");
            ByteBuffer prepared = prepareDirectRgbForNative(rgb, width, height, rowStrideBytes);
            StainInferOutcome outcome = traceNativeCall("run", handle, "nativeRknnStainDetectFromRgb",
                    () -> nativeRknnStainDetectFromRgb(handle, prepared, width, height, rowStrideBytes,
                            nativeCameraTypeValue()), fallback);
            emitStage("run", handle,
                    outcome != null && outcome.isSuccess() ? ErrorCategory.OK : ErrorCategory.NATIVE_ERROR,
                    outcome == null ? -1 : outcome.code,
                    "typed rgb infer returned");
            return outcome == null ? fallback : outcome;
        } finally {
            session.lock.unlock();
        }
    }

    public static StainInferOutcome guardedRknnStainDetectFromNv12(long handle, ByteBuffer nv12, int width, int height) {
        if (AiNativeRuntime.blocksRknnSession()) {
            return stainInferEmulatorBlocked();
        }
        return runOnRknnThread("run", handle,
                stainInferError(-1006, "RKNN task failed before nativeRknnStainDetectFromNv12"),
                () -> guardedRknnStainDetectFromNv12OnRknnThread(handle, nv12, width, height));
    }

    private static StainInferOutcome guardedRknnStainDetectFromNv12OnRknnThread(long handle, ByteBuffer nv12, int width, int height) {
        GuardedSession session = SESSIONS.get(handle);
        if (session == null) {
            emitStage("run", handle, ErrorCategory.INVALID_STATE, -1, "missing session at infer nv12");
            return stainInferError(-1001, "missing session");
        }
        String validationError = validateDirectNv12Buffer(nv12, width, height, session.state);
        if (validationError != null) {
            emitStage("run", handle, ErrorCategory.INVALID_ARGUMENT, -1, validationError);
            return stainInferError(-1, validationError);
        }
        if (!session.lock.tryLock()) {
            emitStage("run", handle, ErrorCategory.CONCURRENT_ACCESS, -1, "concurrent infer nv12 access");
            return stainInferError(-1003, "concurrent infer nv12 access");
        }
        try {
            if (session.state != SessionState.RUNNING) {
                emitStage("run", handle, ErrorCategory.INVALID_STATE, -1, "infer nv12 requires RUNNING state");
                return stainInferError(-1004, "infer nv12 requires RUNNING state");
            }
            StainInferOutcome fallback = stainInferError(-1007, "nativeRknnStainDetectFromNv12 failed or unavailable");
            ByteBuffer prepared = prepareDirectNv12ForNative(nv12, width, height);
            StainInferOutcome outcome = traceNativeCall("run", handle, "nativeRknnStainDetectFromNv12",
                    () -> nativeRknnStainDetectFromNv12(handle, prepared, width, height, nativeCameraTypeValue()), fallback);
            emitStage("run", handle,
                    outcome != null && outcome.isSuccess() ? ErrorCategory.OK : ErrorCategory.NATIVE_ERROR,
                    outcome == null ? -1 : outcome.code,
                    "typed nv12 infer returned");
            return outcome == null ? fallback : outcome;
        } finally {
            session.lock.unlock();
        }
    }

    static StainInferOutcome stainInferError(int code, String errorMessage) {
        String msg = errorMessage == null ? "" : errorMessage;
        return new StainInferOutcome(code, msg, "", AiStainDetectResult.LEVEL_ERROR, "ERROR", msg,
                0, 0, new StainBox[0], false, 0);
    }

    private static StainInferOutcome stainInferEmulatorBlocked() {
        return stainInferError(AiNativeRuntime.CODE_RKNN_UNAVAILABLE, AiNativeRuntime.rknnUnavailableMessage());
    }

    static String validateDirectNv12Buffer(ByteBuffer nv12, int width, int height, SessionState state) {
        if (state == SessionState.DESTROYED || state == SessionState.NEW) {
            return "session state invalid for typed infer: " + state;
        }
        if (width <= 0 || height <= 0) {
            return "invalid frame width/height";
        }
        if (nv12 == null || !nv12.isDirect()) {
            return "NV12 buffer must be direct ByteBuffer";
        }
        long expected = (long) width * (long) height * 3L / 2L;
        if (expected <= 0 || expected > Integer.MAX_VALUE) {
            return "expected NV12 size overflow";
        }
        if (nv12.capacity() < (int) expected) {
            return String.format(Locale.US, "NV12 capacity mismatch expected=%d actual=%d",
                    expected, nv12.capacity());
        }
        return null;
    }

    static String validateDirectRgbBuffer(ByteBuffer rgb, int width, int height, int rowStrideBytes, SessionState state) {
        if (state == SessionState.DESTROYED || state == SessionState.NEW) {
            return "session state invalid for typed infer: " + state;
        }
        if (width <= 0 || height <= 0 || rowStrideBytes <= 0) {
            return "invalid RGB frame dimensions";
        }
        if (rgb == null || !rgb.isDirect()) {
            return "RGB buffer must be direct ByteBuffer";
        }
        long minCapacity = (long) rowStrideBytes * (long) height;
        if (minCapacity > rgb.capacity()) {
            return String.format(Locale.US, "RGB capacity mismatch need=%d actual=%d",
                    minCapacity, rgb.capacity());
        }
        return null;
    }

    private static ByteBuffer prepareDirectNv12ForNative(ByteBuffer nv12, int width, int height) {
        long expected = (long) width * (long) height * 3L / 2L;
        ByteBuffer view = nv12.duplicate();
        view.clear();
        view.limit((int) expected);
        return view;
    }

    private static ByteBuffer prepareDirectRgbForNative(ByteBuffer rgb, int width, int height, int rowStrideBytes) {
        long minCapacity = (long) rowStrideBytes * (long) height;
        ByteBuffer view = rgb.duplicate();
        view.clear();
        view.limit((int) Math.min(minCapacity, view.capacity()));
        return view;
    }

    public static int guardedRknnStainDetectFromVideoAndSave(long handle, String inputVideoPath, String outputVideoPath) {
        if (AiNativeRuntime.blocksRknnSession()) {
            return AiNativeRuntime.CODE_RKNN_UNAVAILABLE;
        }
        return runOnRknnThread("run", handle, -1006,
                () -> guardedRknnStainDetectFromVideoAndSaveOnRknnThread(handle, inputVideoPath, outputVideoPath));
    }

    private static int guardedRknnStainDetectFromVideoAndSaveOnRknnThread(long handle,
                                                            String inputVideoPath,
                                                            String outputVideoPath) {
        GuardedSession session = SESSIONS.get(handle);
        if (session == null) {
            emitStage("run", handle, ErrorCategory.INVALID_STATE, -1, "missing session at infer video");
            return -1001;
        }
        if (inputVideoPath == null || inputVideoPath.trim().isEmpty()
                || outputVideoPath == null || outputVideoPath.trim().isEmpty()) {
            emitStage("run", handle, ErrorCategory.INVALID_ARGUMENT, -1, "invalid video paths");
            return -1002;
        }
        if (!session.lock.tryLock()) {
            emitStage("run", handle, ErrorCategory.CONCURRENT_ACCESS, -1, "concurrent infer video access");
            return -1003;
        }
        try {
            if (session.state != SessionState.RUNNING) {
                emitStage("run", handle, ErrorCategory.INVALID_STATE, -1, "infer video requires RUNNING state");
                return -1004;
            }
            int code = traceNativeCall("run", handle, "nativeRknnStainDetectFromVideoAndSave",
                    () -> nativeRknnStainDetectFromVideoAndSave(handle, inputVideoPath, outputVideoPath,
                            nativeCameraTypeValue()), -1007);
            emitStage("run", handle, code == 0 ? ErrorCategory.OK : ErrorCategory.NATIVE_ERROR,
                    code, nativeInferVideoStageDetail(code));
            return code;
        } catch (Throwable t) {
            emitStage("run", handle, ErrorCategory.NATIVE_ERROR, -1,
                    "nativeRknnStainDetectFromVideoAndSave failed: " + t.getMessage());
            return -1005;
        } finally {
            session.lock.unlock();
        }
    }

    private static String nativeInferStageDetail(int code) {
        switch (code) {
            case 0:
                return "infer completed";
            case -1:
                return "infer failed: invalid argument";
            case -2:
                return "infer failed: image read failed";
            case -3:
                return "infer failed: model inference failed";
            case -4:
                return "infer failed: result image save failed";
            default:
                return "infer failed: native code " + code;
        }
    }

    private static String nativeInferVideoStageDetail(int code) {
        switch (code) {
            case 0:
                return "video infer completed";
            case -1:
                return "video infer failed: invalid argument";
            case -2:
                return "video infer failed: input open or frame size invalid";
            case -3:
                return "video infer failed: model inference failed";
            case -4:
                return "video infer failed: output video create failed";
            case -5:
                return "video infer failed: no readable frames";
            default:
                return "video infer failed: native code " + code;
        }
    }

    public static String guardedGetLastClsResult(long handle) {
        return runOnRknnThread("query", handle,
                invalidClsSnapshotJson("guardedGetLastClsResult fallback"),
                () -> guardedGetLastClsResultOnRknnThread(handle));
    }

    private static String guardedGetLastClsResultOnRknnThread(long handle) {
        GuardedSession session = SESSIONS.get(handle);
        if (session == null) {
            emitStage("query", handle, ErrorCategory.INVALID_STATE, -1, "missing session at getLastClsResult");
            return invalidClsSnapshotJson("missing session");
        }
        if (!session.lock.tryLock()) {
            emitStage("query", handle, ErrorCategory.CONCURRENT_ACCESS, -1, "concurrent getLastClsResult access");
            return invalidClsSnapshotJson("concurrent access");
        }
        try {
            if (session.state != SessionState.RUNNING && session.state != SessionState.INITIALIZED) {
                emitStage("query", handle, ErrorCategory.INVALID_STATE, -1,
                        "getLastClsResult requires active session state=" + session.state);
                return invalidClsSnapshotJson("invalid session state");
            }
            String json = traceNativeCall("query", handle, "nativeGetLastClsResult",
                    () -> nativeGetLastClsResult(handle), null);
            if (json == null || json.trim().isEmpty()) {
                emitStage("query", handle, ErrorCategory.NATIVE_ERROR, -1,
                        "nativeGetLastClsResult returned empty snapshot");
                return invalidClsSnapshotJson("empty native snapshot");
            }
            emitStage("query", handle, ErrorCategory.OK, 0, "cls snapshot read");
            return json;
        } finally {
            session.lock.unlock();
        }
    }

    private static String invalidClsSnapshotJson(String error) {
        return "{\"valid\":false,\"classId\":-1,\"className\":\"\",\"score\":0.0,"
                + "\"topk\":[],\"timestampMs\":0,\"modelVersion\":\"\",\"source\":\"focus_cls\","
                + "\"errorMessage\":\"" + jsonEscape(error) + "\"}";
    }

    private static String jsonEscape(String value) {
        if (value == null) {
            return "";
        }
        return value.replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\n", "\\n")
                .replace("\r", "\\r");
    }

    public static void guardedSetLaserOn(long handle, boolean on) {
        runOnRknnThread("query", handle, null, () -> {
            guardedSetLaserOnOnRknnThread(handle, on);
            return null;
        });
    }

    private static void guardedSetLaserOnOnRknnThread(long handle, boolean on) {
        GuardedSession session = SESSIONS.get(handle);
        if (session == null) {
            emitStage("query", handle, ErrorCategory.INVALID_STATE, -1, "missing session at setLaserOn");
            return;
        }
        if (!session.lock.tryLock()) {
            emitStage("query", handle, ErrorCategory.CONCURRENT_ACCESS, -1, "concurrent setLaserOn access");
            return;
        }
        try {
            if (session.state != SessionState.RUNNING) {
                emitStage("query", handle, ErrorCategory.INVALID_STATE, -1, "setLaserOn requires RUNNING state");
                return;
            }
            traceNativeCall("query", handle, "nativeSetLaserOn", () -> {
                nativeSetLaserOn(handle, on);
                return null;
            }, null);
            emitStage("query", handle, ErrorCategory.OK, 0, "laser state pushed");
        } catch (Throwable t) {
            emitStage("query", handle, ErrorCategory.NATIVE_ERROR, -1, "nativeSetLaserOn failed: " + t.getMessage());
        } finally {
            session.lock.unlock();
        }
    }

    public static boolean guardedSetAiVisionPreviewClassificationEnabled(long handle, boolean enabled) {
        return runOnRknnThread("query", handle, false,
                () -> guardedSetAiVisionPreviewClassificationEnabledOnRknnThread(handle, enabled));
    }

    private static boolean guardedSetAiVisionPreviewClassificationEnabledOnRknnThread(long handle,
                                                                                     boolean enabled) {
        GuardedSession session = SESSIONS.get(handle);
        if (session == null) {
            emitStage("query", handle, ErrorCategory.INVALID_STATE, -1,
                    "missing session at setAiVisionPreviewClassificationEnabled");
            return false;
        }
        if (!session.lock.tryLock()) {
            emitStage("query", handle, ErrorCategory.CONCURRENT_ACCESS, -1,
                    "concurrent setAiVisionPreviewClassificationEnabled access");
            return false;
        }
        try {
            if (session.state != SessionState.RUNNING) {
                emitStage("query", handle, ErrorCategory.INVALID_STATE, -1,
                        "setAiVisionPreviewClassificationEnabled requires RUNNING state");
                return false;
            }
            traceNativeCall("query", handle, "nativeSetAiVisionPreviewClassificationEnabled", () -> {
                nativeSetAiVisionPreviewClassificationEnabled(handle, enabled);
                return null;
            }, null);
            emitStage("query", handle, ErrorCategory.OK, 0,
                    "AI Vision preview classification mode pushed");
            return true;
        } catch (Throwable t) {
            emitStage("query", handle, ErrorCategory.NATIVE_ERROR, -1,
                    "nativeSetAiVisionPreviewClassificationEnabled failed: " + t.getMessage());
            return false;
        } finally {
            session.lock.unlock();
        }
    }

    public static boolean guardedSetAiVisionPreviewDetectionEnabled(long handle, boolean enabled) {
        return runOnRknnThread("query", handle, false,
                () -> guardedSetAiVisionPreviewDetectionEnabledOnRknnThread(handle, enabled));
    }

    private static boolean guardedSetAiVisionPreviewDetectionEnabledOnRknnThread(long handle,
                                                                                boolean enabled) {
        GuardedSession session = SESSIONS.get(handle);
        if (session == null) {
            emitStage("query", handle, ErrorCategory.INVALID_STATE, -1,
                    "missing session at setAiVisionPreviewDetectionEnabled");
            return false;
        }
        if (!session.lock.tryLock()) {
            emitStage("query", handle, ErrorCategory.CONCURRENT_ACCESS, -1,
                    "concurrent setAiVisionPreviewDetectionEnabled access");
            return false;
        }
        try {
            if (session.state != SessionState.RUNNING) {
                emitStage("query", handle, ErrorCategory.INVALID_STATE, -1,
                        "setAiVisionPreviewDetectionEnabled requires RUNNING state");
                return false;
            }
            traceNativeCall("query", handle, "nativeSetAiVisionPreviewDetectionEnabled", () -> {
                nativeSetAiVisionPreviewDetectionEnabled(handle, enabled);
                return null;
            }, null);
            emitStage("query", handle, ErrorCategory.OK, 0,
                    "AI Vision preview detection mode pushed");
            return true;
        } catch (Throwable t) {
            emitStage("query", handle, ErrorCategory.NATIVE_ERROR, -1,
                    "nativeSetAiVisionPreviewDetectionEnabled failed: " + t.getMessage());
            return false;
        } finally {
            session.lock.unlock();
        }
    }

    private static <T> T runOnRknnThread(String stage, long handle, T fallback, Callable<T> task) {
        if (Boolean.TRUE.equals(IS_RKNN_THREAD.get())) {
            try {
                return task.call();
            } catch (Throwable t) {
                emitStage(stage, handle, ErrorCategory.NATIVE_ERROR, -1, "RKNN task failed: " + t.getMessage());
                return fallback;
            }
        }
        Future<T> future = RKNN_EXECUTOR.submit(() -> {
            IS_RKNN_THREAD.set(Boolean.TRUE);
            try {
                return task.call();
            } finally {
                IS_RKNN_THREAD.remove();
            }
        });
        try {
            return future.get();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            emitStage(stage, handle, ErrorCategory.NATIVE_ERROR, -1, "RKNN task interrupted");
            return fallback;
        } catch (ExecutionException e) {
            Throwable cause = e.getCause() != null ? e.getCause() : e;
            emitStage(stage, handle, ErrorCategory.NATIVE_ERROR, -1, "RKNN task failed: " + cause.getMessage());
            return fallback;
        }
    }

    private static void runOnRknnThreadUnchecked(String stage, long handle, Runnable task) {
        if (Boolean.TRUE.equals(IS_RKNN_THREAD.get())) {
            task.run();
            return;
        }
        Future<?> future = RKNN_EXECUTOR.submit(() -> {
            IS_RKNN_THREAD.set(Boolean.TRUE);
            try {
                task.run();
            } finally {
                IS_RKNN_THREAD.remove();
            }
        });
        try {
            future.get();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            emitStage(stage, handle, ErrorCategory.NATIVE_ERROR, -1, "RKNN task interrupted");
            throw new IllegalStateException("RKNN task interrupted", e);
        } catch (ExecutionException e) {
            Throwable cause = e.getCause() != null ? e.getCause() : e;
            emitStage(stage, handle, ErrorCategory.NATIVE_ERROR, -1, "RKNN task failed: " + cause.getMessage());
            if (cause instanceof RuntimeException) {
                throw (RuntimeException) cause;
            }
            if (cause instanceof Error) {
                throw (Error) cause;
            }
            throw new IllegalStateException("RKNN task failed", cause);
        }
    }

    private static <T> T traceNativeCall(String stage, long handle, String method, Callable<T> call, T fallback) {
        long seq = CALL_SEQ.incrementAndGet();
        long startNs = System.nanoTime();
        Log.i(TAG, "RKNN_THREAD_TRACE " + buildTidMarker(stage, handle, "NATIVE_CALL_BEGIN", method, seq, 0L));
        try {
            T result = call.call();
            long elapsedUs = (System.nanoTime() - startNs) / 1_000L;
            Log.i(TAG, "RKNN_THREAD_TRACE " + buildTidMarker(stage, handle, "NATIVE_CALL_END", method, seq, elapsedUs));
            return result;
        } catch (Throwable t) {
            long elapsedUs = (System.nanoTime() - startNs) / 1_000L;
            Log.e(TAG, "RKNN_THREAD_TRACE " + buildTidMarker(stage, handle, "NATIVE_CALL_FAIL", method, seq, elapsedUs)
                    + " err=" + t.getClass().getSimpleName() + ":" + t.getMessage());
            return fallback;
        }
    }

    private static String buildTidMarker(String stage, long handle, String phase, String method, long seq, long elapsedUs) {
        Thread current = Thread.currentThread();
        return "phase=" + phase
                + " method=" + method
                + " seq=" + seq
                + " stage=" + stage
                + " handle=" + handle
                + " pid=" + Process.myPid()
                + " tid=" + Process.myTid()
                + " thread=" + current.getName()
                + " threadId=" + current.getId()
                + " elapsedUs=" + elapsedUs;
    }

    static String validateFrameInput(ByteBuffer nv12, int width, int height, SessionState state) {
        if (state == SessionState.DESTROYED || state == SessionState.NEW) {
            return "session state invalid for frame push: " + state;
        }
        if (width <= 0 || height <= 0) {
            return "invalid frame width/height";
        }
        if (nv12 == null || !nv12.isDirect()) {
            return "NV12 buffer must be direct ByteBuffer";
        }
        long expected = (long) width * (long) height * 3L / 2L;
        if (expected <= 0 || expected > Integer.MAX_VALUE) {
            return "expected frame size overflow";
        }
        if (nv12.capacity() < (int) expected) {
            return String.format(Locale.US, "frame size mismatch expected=%d actual=%d", expected, nv12.capacity());
        }
        return null;
    }

    private static void emitStage(String stage, long handle, ErrorCategory category, int nativeCode, String detail) {
        String thread = Thread.currentThread().getName();
        long javaThreadId = Thread.currentThread().getId();
        int linuxTid = Process.myTid();
        int pid = Process.myPid();
        String marker = "stage=" + stage + " handle=" + handle
                + " pid=" + pid + " tid=" + linuxTid
                + " thread=" + thread + " threadId=" + javaThreadId
                + " category=" + category + " nativeCode=" + nativeCode + " detail=" + detail;
        LAST_STAGE_MARKER.set(marker);
        if (category == ErrorCategory.OK) {
            Log.i(TAG, "RKNN_DIAG " + marker);
        } else {
            Log.e(TAG, "RKNN_DIAG " + marker);
        }
    }

    /** Native detection box (xyxy pixel coords). */
    public static final class StainBox {
        public final float x1;
        public final float y1;
        public final float x2;
        public final float y2;
        public final int classId;
        public final float score;

        public StainBox(float x1, float y1, float x2, float y2, int classId, float score) {
            this.x1 = x1;
            this.y1 = y1;
            this.x2 = x2;
            this.y2 = y2;
            this.classId = classId;
            this.score = score;
        }
    }

    /** Typed stain inference outcome filled directly by JNI (no JSON string). */
    public static final class StainInferOutcome {
        public final int code;
        public final String errorMessage;
        public final String source;
        public final int level;
        public final String status;
        public final String detailMessage;
        public final int imageWidth;
        public final int imageHeight;
        public final StainBox[] boxes;
        public final boolean boxesTruncated;
        public final int boxesTotal;

        public StainInferOutcome(int code,
                                 String errorMessage,
                                 String source,
                                 int level,
                                 String status,
                                 String detailMessage,
                                 int imageWidth,
                                 int imageHeight,
                                 StainBox[] boxes,
                                 boolean boxesTruncated,
                                 int boxesTotal) {
            this.code = code;
            this.errorMessage = errorMessage == null ? "" : errorMessage;
            this.source = source == null ? "" : source;
            this.level = level;
            this.status = status == null ? "" : status;
            this.detailMessage = detailMessage == null ? "" : detailMessage;
            this.imageWidth = imageWidth;
            this.imageHeight = imageHeight;
            this.boxes = boxes == null ? new StainBox[0] : boxes;
            this.boxesTruncated = boxesTruncated;
            this.boxesTotal = boxesTotal;
        }

        public boolean isSuccess() {
            return code == 0;
        }
    }

    /**
     * Callback interface for native engine events.
     */
    public interface NativeListener {
        /**
         * Called when the system state changes.
         *
         * @param state 0 = IDLE, 1 = MONITORING, 2 = LOCKED
         */
        void onStateChanged(int state);

        /**
         * Called when a lens contamination check completes.
         *
         * @param level   0 = clean, 1 = mild, 2 = heavy
         * @param status  short status tag (e.g. "CLEAN", "STAIN_MILD")
         * @param message human-readable description
         */
        void onCheckResult(int level, String status, String message);

        /**
         * Called when alert level changes (e.g. lens dirty warning).
         *
         * @param alertLevel zero means no alert; positive values mean an active alert
         */
        void onAlert(int alertLevel);
    }
}
