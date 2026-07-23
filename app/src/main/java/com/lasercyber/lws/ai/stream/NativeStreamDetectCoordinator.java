package com.lasercyber.lws.ai.stream;

import com.lasercyber.lws.ai.daemon.AiDaemonSupervisor;
import com.lasercyber.lws.ai.engine.AiManager;
import com.lasercyber.lws.ai.zeropoint.ZeroPointDetectCoordinator;
import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.config.CameraConfig;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.settings.AiAssistanceSettings;
import com.lasercyber.lws.ui.network.mediamtx.MediaMtxRelayCoordinator;
import com.lasercyber.lws.ui.network.mediamtx.MediaMtxRelayUrls;

import java.io.File;
import java.util.HashSet;
import java.util.Set;

/**
 * Java lifecycle wrapper for daemon-hosted {@code StreamDetectPipeline}.
 * Supports weld (laser ON) and AI Vision live preview as independent holders on one session.
 */
public final class NativeStreamDetectCoordinator {

    public static final String HOLDER_WELD = "weld";
    public static final String HOLDER_AI_VISION = "ai_vision";
    public static final String HOLDER_MANUAL_ZERO_POINT = "manual_zero_point";

    private static final String TAG = LogTAGConstant.EasyPlayerClientManger;
    private static final String SOURCE_LIVE_STAIN = "live_stain_detect";
    private static final String SOURCE_AI_VISION_LIVE = "ai_vision_live";

    private static final NativeStreamDetectCoordinator INSTANCE = new NativeStreamDetectCoordinator();

    private final Object lock = new Object();
    private final Set<String> holders = new HashSet<>();
    private Context appContext;
    private volatile boolean attached;
    private volatile boolean running;

    public static NativeStreamDetectCoordinator getInstance() {
        return INSTANCE;
    }

    private NativeStreamDetectCoordinator() {
    }

    public void attach(@NonNull Context context) {
        synchronized (lock) {
            appContext = context.getApplicationContext();
            attached = true;
        }
        // Daemon evt → bus; JNI native callback registration is a no-op on product path.
        StreamDetectResultBus.getInstance().registerNativeCallback();
        StreamDetectOverlayBridge.getInstance().ensureSubscribed();
        Log.i(TAG, "INFER_NATIVE coordinator attached (daemon IPC)");
    }

    public void ensureAttached(@NonNull Context context) {
        synchronized (lock) {
            if (!attached) {
                attach(context);
            }
        }
    }

    public void detach() {
        synchronized (lock) {
            holders.clear();
            stopLocked("detach");
            attached = false;
            appContext = null;
        }
        StreamDetectResultBus.getInstance().unregisterNativeCallback();
        StreamDetectOverlayBridge.getInstance().unsubscribe();
        Log.i(TAG, "INFER_NATIVE coordinator detached");
    }

    public boolean isRunning() {
        return running;
    }

    public boolean isAiVisionLiveActive() {
        synchronized (lock) {
            return holders.contains(HOLDER_AI_VISION);
        }
    }

    /**
     * @return true when native pipeline accepted start
     */
    public boolean onLaserEnableChanged(boolean laserOn) {
        synchronized (lock) {
            if (!attached || appContext == null) {
                return false;
            }
            if (!laserOn) {
                releaseHolderLocked(HOLDER_WELD, "laser_enable_off");
                return true;
            }
            return acquireHolderLocked(HOLDER_WELD, SOURCE_LIVE_STAIN, true);
        }
    }

    /**
     * Start native PR1 detect for AI Vision live preview (parallel to Java playback).
     */
    public boolean acquireAiVisionLive(@NonNull Context context) {
        synchronized (lock) {
            ensureAttachedLocked(context);
            if (!attached || appContext == null) {
                return false;
            }
            return acquireHolderLocked(HOLDER_AI_VISION, SOURCE_AI_VISION_LIVE, false);
        }
    }

    public void releaseAiVisionLive(@NonNull String reason) {
        synchronized (lock) {
            releaseHolderLocked(HOLDER_AI_VISION, reason);
        }
    }

    /**
     * Manual zero-offset auto: temporary native PR1 session while laser is ON.
     */
    public boolean acquireManualZeroPoint(@NonNull Context context) {
        synchronized (lock) {
            ensureAttachedLocked(context);
            if (!attached || appContext == null) {
                return false;
            }
            return acquireHolderLocked(HOLDER_MANUAL_ZERO_POINT, SOURCE_LIVE_STAIN, true);
        }
    }

    public void releaseManualZeroPoint(@NonNull String reason) {
        synchronized (lock) {
            releaseHolderLocked(HOLDER_MANUAL_ZERO_POINT, reason);
        }
    }

    @VisibleForTesting
    static boolean shouldKeepPipelineRunning(@NonNull Set<String> activeHolders) {
        return !activeHolders.isEmpty();
    }

    private void ensureAttachedLocked(@NonNull Context context) {
        if (!attached) {
            appContext = context.getApplicationContext();
            attached = true;
            StreamDetectResultBus.getInstance().registerNativeCallback();
            StreamDetectOverlayBridge.getInstance().ensureSubscribed();
            Log.i(TAG, "INFER_NATIVE coordinator attached (lazy, daemon IPC)");
        }
    }

    private boolean acquireHolderLocked(
            @NonNull String holder,
            @NonNull String sessionSource,
            boolean weldZeroPointEligible) {
        if (!AiDaemonSupervisor.getInstance().isReady()) {
            Log.w(TAG, "INFER_NATIVE skip start holder=" + holder + ": ai daemon not ready");
            return false;
        }
        holders.add(holder);
        if (running) {
            pushActualLaserBit0();
            Log.d(TAG, "INFER_NATIVE holder=" + holder + " joined active daemon session");
            return true;
        }
        return startLocked(sessionSource, weldZeroPointEligible);
    }

    private void pushActualLaserBit0() {
        DeviceStatus status = MemoryCacheManager.getInstance()
                .getSerializable(CacheKey.DEVICE_STATUS_KEY);
        if (status != null) {
            AiDaemonSupervisor.getInstance().pushLaserStateNow(status.isLaserOn());
        }
    }

    private void releaseHolderLocked(@NonNull String holder, @NonNull String reason) {
        if (!holders.remove(holder)) {
            return;
        }
        if (shouldKeepPipelineRunning(holders)) {
            Log.d(TAG, "INFER_NATIVE holder=" + holder + " released reason=" + reason
                    + " remaining=" + holders);
            return;
        }
        stopLocked(reason);
    }

    private boolean startLocked(@NonNull String sessionSource, boolean weldZeroPointEligible) {
        AiDaemonSupervisor supervisor = AiDaemonSupervisor.getInstance();
        AiManager aiManager = AiManager.getInstance();
        File outputDir = aiManager.getOpencvStainDetectLiveOutputDir();
        ZeroPointDetectCoordinator.getInstance().ensureNativeDetectorReady();
        boolean zeroPointEnabled = weldZeroPointEligible
                && AiAssistanceSettings.isZeroPointOffsetDetectionEnabled(appContext);
        boolean configured = supervisor.configureStreamDetect(
                outputDir.getAbsolutePath(),
                com.lasercyber.lws.ai.NativeBridge.nativeCameraTypeValue(),
                true,
                zeroPointEnabled,
                sessionSource);
        if (!configured) {
            holders.clear();
            Log.w(TAG, "INFER_NATIVE configure_session failed source=" + sessionSource);
            return false;
        }
        boolean localRelay = MediaMtxRelayCoordinator.getInstance().isRelayReady();
        String url = MediaMtxRelayUrls.resolvePr1Ingest(localRelay, CameraConfig.getCameraIp());
        boolean started = supervisor.startStreamDetect(url);
        if (started) {
            // Push actual Bit0; do not force sampling on when holders start.
            pushActualLaserBit0();
            running = true;
            Log.i(TAG, "INFER_NATIVE start (daemon) holder=" + holders + " source=" + sessionSource
                    + " url=" + url + " outputDir=" + outputDir.getAbsolutePath());
        } else {
            holders.clear();
            Log.w(TAG, "INFER_NATIVE start failed source=" + sessionSource + " url=" + url);
        }
        return started;
    }

    private void stopLocked(@NonNull String reason) {
        if (!running) {
            return;
        }
        AiDaemonSupervisor.getInstance().stopStreamDetect();
        running = false;
        Log.i(TAG, "INFER_NATIVE stop (daemon) reason=" + reason);
    }
}
