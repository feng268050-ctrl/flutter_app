package com.lasercyber.lws.ai.daemon;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ai.engine.AiManager;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.settings.AiAssistanceSettings;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Spawns and supervises {@code lws_ai_daemon}: reconnect, heartbeat watchdog, Bit0 + AI-assist push.
 */
public final class AiDaemonSupervisor implements MemoryCacheManager.OnCacheChangedListener {

    public enum DaemonState {
        STOPPED,
        STARTING,
        RUNNING,
        RESTARTING,
        ERROR
    }

    private static final String TAG = LogTAGConstant.AI_DAEMON;
    private static final long HEARTBEAT_TIMEOUT_MS = 5_000L;
    private static final long CONNECT_RETRY_MS = 200L;
    private static final int CONNECT_ATTEMPTS = 25;
    private static final long BACKOFF_INITIAL_MS = 1_000L;
    private static final long BACKOFF_MAX_MS = 30_000L;
    private static final int MAX_CRASH_BURST = 12;
    private static final int DEFAULT_CMD_TIMEOUT_MS = 15_000;
    private static final int OFFLINE_INFER_TIMEOUT_MS = 120_000;
    /** Must match daemon --abstract PREFIX → @PREFIX_cmd / @PREFIX_evt. */
    private static final String ABSTRACT_PREFIX = "lws_ai";

    private static final AiDaemonSupervisor INSTANCE = new AiDaemonSupervisor();

    private final Object lock = new Object();
    private final AtomicReference<DaemonState> state = new AtomicReference<>(DaemonState.STOPPED);
    private final AtomicBoolean stopRequested = new AtomicBoolean(false);
    private final AtomicBoolean restartInFlight = new AtomicBoolean(false);
    private final AtomicInteger crashBurst = new AtomicInteger(0);
    private final AtomicInteger inFlightLongCmd = new AtomicInteger(0);
    private final AtomicLong lastHeartbeatElapsedMs = new AtomicLong(0);
    private final AtomicReference<Boolean> lastPushedLaser = new AtomicReference<>(null);
    private final ScheduledExecutorService scheduler = Executors.newSingleThreadScheduledExecutor(r -> {
        Thread t = new Thread(r, "ai-daemon-supervisor");
        t.setDaemon(true);
        return t;
    });

    @Nullable
    private Context appContext;
    @Nullable
    private Process process;
    @Nullable
    private Thread stderrDrain;
    @Nullable
    private AiDaemonSocketClient client;
    @Nullable
    private ScheduledFuture<?> watchdogFuture;
    private long nextBackoffMs = BACKOFF_INITIAL_MS;
    @Nullable
    private Boolean desiredLaserOn;
    private boolean desiredLensEnabled = true;
    private boolean desiredZeroPointEnabled = true;

    private volatile boolean streamWantRunning;
    @Nullable
    private volatile String lastRtspUrl;
    @Nullable
    private volatile String lastOutputDir;
    private volatile int lastCameraType;
    private volatile boolean lastLensDet;
    private volatile boolean lastZeroPoint;
    @Nullable
    private volatile String lastSessionSource;

    private AiDaemonSupervisor() {
    }

    @NonNull
    public static AiDaemonSupervisor getInstance() {
        return INSTANCE;
    }

    @NonNull
    public DaemonState getDaemonState() {
        return state.get();
    }

    /**
     * Cold-start entry: extract binary, spawn daemon, connect sockets, push initial state.
     *
     * @return true when daemon is connected and ready
     */
    public boolean start(@NonNull Context context) {
        Context app = context.getApplicationContext();
        synchronized (lock) {
            stopRequested.set(false);
            appContext = app;
            if (state.get() == DaemonState.RUNNING && process != null && process.isAlive()
                    && client != null) {
                Log.w(TAG, "already running");
                return true;
            }
            state.set(DaemonState.STARTING);
            crashBurst.set(0);
            nextBackoffMs = BACKOFF_INITIAL_MS;
        }
        boolean ok = spawnAndConnectLockedPath(app, /*repush=*/true);
        if (ok) {
            MemoryCacheManager.getInstance().addListener(CacheKey.DEVICE_STATUS_KEY, this);
            scheduleWatchdog();
            Log.i(TAG, "startup_phase=ai_daemon, outcome=ok, reason=ready");
        } else {
            state.set(DaemonState.ERROR);
            Log.e(TAG, "startup_phase=ai_daemon, outcome=failed, reason=spawn_or_connect");
        }
        return ok;
    }

    public void stop() {
        stopRequested.set(true);
        restartInFlight.set(false);
        cancelWatchdog();
        MemoryCacheManager.getInstance().removeListener(CacheKey.DEVICE_STATUS_KEY, this);
        synchronized (lock) {
            shutdownClientLocked();
            killProcessLocked();
            Context ctx = appContext;
            if (ctx != null) {
                cleanSocks(sockDir(ctx));
            }
            state.set(DaemonState.STOPPED);
            lastPushedLaser.set(null);
            Log.i(TAG, "supervisor stopped");
        }
    }

    /** Push latest AI assist toggles (call when advanced settings change). */
    public void pushAiAssistConfigNow() {
        Context ctx = appContext;
        if (ctx == null) {
            return;
        }
        desiredLensEnabled = AiAssistanceSettings.isLensContaminationDetectionEnabled(ctx);
        desiredZeroPointEnabled = AiAssistanceSettings.isZeroPointOffsetDetectionEnabled(ctx);
        ThreadPoolManager.getExecutor().execute(this::sendAiAssistConfigSafe);
    }

    public void pushLaserStateNow(boolean laserOn) {
        desiredLaserOn = laserOn;
        ThreadPoolManager.getExecutor().execute(() -> sendLaserStateSafe(laserOn, /*force=*/true));
    }

    @Override
    public void onCacheChanged(String key) {
        if (!CacheKey.DEVICE_STATUS_KEY.equals(key)) {
            return;
        }
        DeviceStatus status = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        if (status == null) {
            return;
        }
        boolean laserOn = status.isLaserOn();
        desiredLaserOn = laserOn;
        Boolean prev = lastPushedLaser.get();
        if (prev != null && prev == laserOn) {
            return;
        }
        ThreadPoolManager.getExecutor().execute(() -> sendLaserStateSafe(laserOn, /*force=*/false));
    }

    private boolean spawnAndConnectLockedPath(@NonNull Context app, boolean repush) {
        synchronized (lock) {
            try {
                AiDaemonBinary.ResolvedBinary resolved = AiDaemonBinary.resolve(app);
                if (resolved == null || !resolved.executable.canExecute()) {
                    Log.e(TAG, "daemon binary missing");
                    return false;
                }
                File workdir = workDir(app);
                if (!workdir.exists() && !workdir.mkdirs()) {
                    Log.e(TAG, "mkdir workdir failed " + workdir);
                    return false;
                }
                killProcessLocked();

                ProcessBuilder pb = new ProcessBuilder(
                        resolved.executable.getAbsolutePath(),
                        "--workdir", workdir.getAbsolutePath(),
                        "--abstract", ABSTRACT_PREFIX);
                pb.redirectErrorStream(true);
                File libDir = resolved.libraryDir;
                pb.directory(libDir);
                StringBuilder ld = new StringBuilder(libDir.getAbsolutePath());
                String nativeLibDir = app.getApplicationInfo().nativeLibraryDir;
                if (nativeLibDir != null && !nativeLibDir.isEmpty()
                        && !nativeLibDir.equals(libDir.getAbsolutePath())) {
                    ld.append(':').append(nativeLibDir);
                }
                Map<String, String> env = pb.environment();
                String existing = env.get("LD_LIBRARY_PATH");
                env.put("LD_LIBRARY_PATH",
                        existing == null || existing.isEmpty()
                                ? ld.toString()
                                : ld + ":" + existing);
                process = pb.start();
                startStderrDrain(process);
                if (!waitProcessAlive(process, 400L)) {
                    Log.e(TAG, "daemon exited immediately");
                    process = null;
                    return false;
                }
                Log.i(TAG, "spawned lws_ai_daemon pid=" + processPid(process)
                        + " version=" + resolved.version
                        + " path=" + resolved.executable.getAbsolutePath());

                String cmdName = ABSTRACT_PREFIX + "_cmd";
                String evtName = ABSTRACT_PREFIX + "_evt";
                AiDaemonSocketClient c = new AiDaemonSocketClient();
                if (!connectWithRetry(c, cmdName, evtName)) {
                    c.close();
                    killProcessLocked();
                    return false;
                }
                client = c;
                c.startEventLoop(this::onDaemonEvent);
                state.set(DaemonState.RUNNING);
                lastHeartbeatElapsedMs.set(android.os.SystemClock.elapsedRealtime());
                crashBurst.set(0);
                nextBackoffMs = BACKOFF_INITIAL_MS;
                com.lasercyber.lws.ai.engine.AiManager.getInstance().markDaemonReady();
            } catch (IOException e) {
                Log.e(TAG, "spawn/connect failed", e);
                shutdownClientLocked();
                killProcessLocked();
                return false;
            }
        }
        if (repush) {
            refreshDesiredFromDevice(app);
            sendLaserStateSafe(desiredLaserOn != null && desiredLaserOn, /*force=*/true);
            sendAiAssistConfigSafe();
            restoreStreamSessionIfNeeded();
        }
        return true;
    }

    private void restoreStreamSessionIfNeeded() {
        if (!streamWantRunning || lastRtspUrl == null) {
            return;
        }
        String outputDir = lastOutputDir;
        String sessionSource = lastSessionSource;
        String rtspUrl = lastRtspUrl;
        if (outputDir == null || sessionSource == null) {
            Log.w(TAG, "stream restore skipped: incomplete last session fields");
            return;
        }
        Log.i(TAG, "restoring stream session after daemon restart url=" + rtspUrl
                + " source=" + sessionSource);
        boolean configured = configureStreamDetect(
                outputDir, lastCameraType, lastLensDet, lastZeroPoint, sessionSource);
        if (!configured) {
            Log.w(TAG, "stream restore configure_session failed");
            return;
        }
        if (!startStreamDetect(rtspUrl)) {
            Log.w(TAG, "stream restore stream_detect_start failed");
        }
    }

    private void refreshDesiredFromDevice(@NonNull Context app) {
        DeviceStatus status = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        if (status != null) {
            desiredLaserOn = status.isLaserOn();
        }
        desiredLensEnabled = AiAssistanceSettings.isLensContaminationDetectionEnabled(app);
        desiredZeroPointEnabled = AiAssistanceSettings.isZeroPointOffsetDetectionEnabled(app);
    }

    private boolean connectWithRetry(@NonNull AiDaemonSocketClient c,
                                     @NonNull String cmdPath,
                                     @NonNull String evtPath) {
        for (int i = 0; i < CONNECT_ATTEMPTS; i++) {
            try {
                c.connect(cmdPath, evtPath);
                return true;
            } catch (IOException e) {
                try {
                    Thread.sleep(CONNECT_RETRY_MS);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    return false;
                }
            }
        }
        Log.e(TAG, "connect timeout cmd=" + cmdPath);
        return false;
    }

    private void onDaemonEvent(@NonNull JSONObject evt) {
        String type = evt.optString("type", "");
        if ("heartbeat".equals(type) || "daemon_ready".equals(type)) {
            lastHeartbeatElapsedMs.set(android.os.SystemClock.elapsedRealtime());
            if ("daemon_ready".equals(type)) {
                Log.i(TAG, "evt daemon_ready");
            }
            return;
        }
        if ("error".equals(type) || "health".equals(type)) {
            Log.w(TAG, "evt " + type + " " + evt);
            return;
        }
        if ("detect_result".equals(type)
                || "combined_frame".equals(type)
                || "session_start".equals(type)
                || "session_stop".equals(type)
                || "pipeline_state".equals(type)) {
            com.lasercyber.lws.ai.stream.StreamDetectResultBus.getInstance()
                    .ingestDaemonEvent(evt.toString());
        }
    }

    public boolean isReady() {
        return state.get() == DaemonState.RUNNING && client != null;
    }

    /** Last successful StreamDetect {@code output_dir} (absolute), or null. */
    @Nullable
    public String getLastStreamDetectOutputDir() {
        return lastOutputDir;
    }

    /**
     * Configure daemon StreamDetect sessions (creates OpenCV/ZP handles inside daemon).
     *
     * @return true when ack ok
     */
    public boolean configureStreamDetect(@NonNull String outputDir,
                                         int cameraType,
                                         boolean lensDetEnabled,
                                         boolean zeroPointEnabled,
                                         @NonNull String sessionSource) {
        try {
            JSONObject fields = new JSONObject();
            fields.put("output_dir", outputDir);
            fields.put("camera_type", cameraType);
            fields.put("lens_det_enabled", lensDetEnabled);
            fields.put("zero_point_enabled", zeroPointEnabled);
            fields.put("session_source", sessionSource);
            fields.put("project_root", ".");
            fields.put("config_yaml", "config.yaml");
            fields.put("roi_json", "zero_point_roi.json");
            fields.put("rknn_stream_enabled", AiManager.isRknnStainInferActive());
            JSONObject resp = requestCmd("configure_session", fields);
            boolean ok = resp != null && resp.optBoolean("ok", false);
            if (ok) {
                lastOutputDir = outputDir;
                lastCameraType = cameraType;
                lastLensDet = lensDetEnabled;
                lastZeroPoint = zeroPointEnabled;
                lastSessionSource = sessionSource;
            }
            return ok;
        } catch (Exception e) {
            Log.w(TAG, "configure_session failed", e);
            return false;
        }
    }

    public boolean startStreamDetect(@NonNull String rtspUrl) {
        try {
            JSONObject fields = new JSONObject();
            fields.put("rtsp_url", rtspUrl);
            JSONObject resp = requestCmd("stream_detect_start", fields);
            boolean ok = resp != null && resp.optBoolean("ok", false);
            if (ok) {
                lastRtspUrl = rtspUrl;
                streamWantRunning = true;
            }
            return ok;
        } catch (Exception e) {
            Log.w(TAG, "stream_detect_start failed", e);
            return false;
        }
    }

    public boolean stopStreamDetect() {
        try {
            JSONObject resp = requestCmd("stream_detect_stop", new JSONObject());
            boolean ok = resp != null && resp.optBoolean("ok", false);
            streamWantRunning = false;
            return ok;
        } catch (Exception e) {
            Log.w(TAG, "stream_detect_stop failed", e);
            streamWantRunning = false;
            return false;
        }
    }

    public boolean setStreamDetectBurstMode(boolean burst) {
        try {
            JSONObject fields = new JSONObject();
            fields.put("burst", burst);
            JSONObject resp = requestCmd("stream_detect_burst_mode", fields);
            return resp != null && resp.optBoolean("ok", false);
        } catch (Exception e) {
            Log.w(TAG, "stream_detect_burst_mode failed", e);
            return false;
        }
    }

    public boolean setStreamDetectZeroPointTargetMode(int targetMode) {
        try {
            JSONObject fields = new JSONObject();
            fields.put("target_mode", targetMode);
            JSONObject resp = requestCmd("stream_detect_zp_target_mode", fields);
            return resp != null && resp.optBoolean("ok", false);
        } catch (Exception e) {
            Log.w(TAG, "stream_detect_zp_target_mode failed", e);
            return false;
        }
    }

    /**
     * Offline OpenCV stain detect: write NV12 under workdir, ask daemon, return summary JSON.
     *
     * @return native summary JSON, or null on IPC/IO failure
     */
    @Nullable
    public String offlineOpencvStainFromNv12(@NonNull ByteBuffer nv12,
                                            int width,
                                            int height,
                                            @NonNull String outputDirAbsolute) {
        File staging = null;
        try {
            Context ctx = appContext;
            if (ctx == null) {
                Log.w(TAG, "offlineOpencvStainFromNv12: no app context");
                return null;
            }
            staging = writeNv12Staging(ctx, nv12, width, height);
            if (staging == null) {
                return null;
            }
            JSONObject fields = new JSONObject();
            fields.put("nv12_path", staging.getAbsolutePath());
            fields.put("width", width);
            fields.put("height", height);
            fields.put("output_dir", outputDirAbsolute);
            JSONObject resp = requestCmd("offline_infer_opencv_stain_nv12", fields);
            if (resp == null || !resp.optBoolean("ok", false)) {
                Log.w(TAG, "offline_infer_opencv_stain_nv12 rejected " + resp);
                return null;
            }
            return resp.optString("summary_json", null);
        } catch (Exception e) {
            Log.w(TAG, "offlineOpencvStainFromNv12 failed", e);
            return null;
        } finally {
            if (staging != null) {
                //noinspection ResultOfMethodCallIgnored
                staging.delete();
            }
        }
    }

    /**
     * Offline OpenCV stain detect from JPEG path via daemon.
     *
     * @return native summary JSON, or null on IPC failure
     */
    @Nullable
    public String offlineOpencvStainFromJpg(@NonNull String imagePath,
                                           @NonNull String outputDirAbsolute) {
        try {
            JSONObject fields = new JSONObject();
            fields.put("image_path", imagePath);
            fields.put("output_dir", outputDirAbsolute);
            JSONObject resp = requestCmd("offline_infer_opencv_stain_jpg", fields);
            if (resp == null || !resp.optBoolean("ok", false)) {
                Log.w(TAG, "offline_infer_opencv_stain_jpg rejected " + resp);
                return null;
            }
            return resp.optString("summary_json", null);
        } catch (Exception e) {
            Log.w(TAG, "offlineOpencvStainFromJpg failed", e);
            return null;
        }
    }

    /**
     * Offline zero-point detect on NV12 via daemon.
     *
     * @return native frame JSON, or null on IPC/IO failure
     */
    @Nullable
    public String offlineZeroPointFromNv12(@NonNull ByteBuffer nv12,
                                          int width,
                                          int height,
                                          int targetMode) {
        File staging = null;
        try {
            Context ctx = appContext;
            if (ctx == null) {
                Log.w(TAG, "offlineZeroPointFromNv12: no app context");
                return null;
            }
            staging = writeNv12Staging(ctx, nv12, width, height);
            if (staging == null) {
                return null;
            }
            JSONObject fields = new JSONObject();
            fields.put("nv12_path", staging.getAbsolutePath());
            fields.put("width", width);
            fields.put("height", height);
            fields.put("target_mode", targetMode);
            JSONObject resp = requestCmd("offline_infer_zero_point_nv12", fields);
            if (resp == null || !resp.optBoolean("ok", false)) {
                Log.w(TAG, "offline_infer_zero_point_nv12 rejected " + resp);
                return null;
            }
            return resp.optString("summary_json", null);
        } catch (Exception e) {
            Log.w(TAG, "offlineZeroPointFromNv12 failed", e);
            return null;
        } finally {
            if (staging != null) {
                //noinspection ResultOfMethodCallIgnored
                staging.delete();
            }
        }
    }

    @Nullable
    private static File writeNv12Staging(@NonNull Context ctx,
                                         @NonNull ByteBuffer nv12,
                                         int width,
                                         int height) {
        if (width <= 0 || height <= 0) {
            return null;
        }
        int expected = width * height * 3 / 2;
        ByteBuffer view = nv12.duplicate();
        view.rewind();
        if (view.remaining() < expected) {
            Log.w(TAG, "writeNv12Staging short buffer remaining=" + view.remaining()
                    + " expected=" + expected);
            return null;
        }
        File dir = new File(workDir(ctx), "offline_nv12");
        if (!dir.exists() && !dir.mkdirs()) {
            Log.w(TAG, "mkdir offline_nv12 failed");
            return null;
        }
        File out = new File(dir, "frame_" + System.nanoTime() + ".nv12");
        try (java.io.FileOutputStream fos = new java.io.FileOutputStream(out)) {
            byte[] chunk = new byte[Math.min(expected, 64 * 1024)];
            int left = expected;
            while (left > 0) {
                int n = Math.min(chunk.length, left);
                view.get(chunk, 0, n);
                fos.write(chunk, 0, n);
                left -= n;
            }
            return out;
        } catch (IOException e) {
            Log.w(TAG, "writeNv12Staging failed", e);
            //noinspection ResultOfMethodCallIgnored
            out.delete();
            return null;
        }
    }

    @Nullable
    private JSONObject requestCmd(@NonNull String type, @NonNull JSONObject fields) {
        int timeoutMs = type.startsWith("offline_infer_")
                ? OFFLINE_INFER_TIMEOUT_MS
                : DEFAULT_CMD_TIMEOUT_MS;
        return requestCmd(type, fields, timeoutMs);
    }

    @Nullable
    private JSONObject requestCmd(@NonNull String type, @NonNull JSONObject fields, int timeoutMs) {
        AiDaemonSocketClient c;
        synchronized (lock) {
            c = client;
        }
        if (c == null) {
            Log.w(TAG, type + " skipped: not connected");
            return null;
        }
        boolean longCmd = type.startsWith("offline_infer_");
        if (longCmd) {
            lastHeartbeatElapsedMs.set(android.os.SystemClock.elapsedRealtime());
            inFlightLongCmd.incrementAndGet();
        }
        try {
            return c.request(type, fields, timeoutMs);
        } catch (Exception e) {
            Log.w(TAG, type + " request failed", e);
            requestRestart(type + "_failed");
            return null;
        } finally {
            if (longCmd) {
                inFlightLongCmd.decrementAndGet();
            }
        }
    }

    private void sendLaserStateSafe(boolean laserOn, boolean force) {
        AiDaemonSocketClient c;
        synchronized (lock) {
            c = client;
        }
        if (c == null) {
            return;
        }
        if (!force) {
            Boolean prev = lastPushedLaser.get();
            if (prev != null && prev == laserOn) {
                return;
            }
        }
        try {
            JSONObject fields = new JSONObject();
            fields.put("laser_on", laserOn);
            JSONObject resp = c.request("laser_state", fields);
            if (resp.optBoolean("ok", false)) {
                lastPushedLaser.set(laserOn);
                Log.i(TAG, "pushed laser_state laser_on=" + laserOn);
            } else {
                Log.w(TAG, "laser_state rejected " + resp);
            }
        } catch (Exception e) {
            Log.w(TAG, "laser_state push failed", e);
            requestRestart("laser_push_failed");
        }
    }

    private void sendAiAssistConfigSafe() {
        AiDaemonSocketClient c;
        Context ctx;
        synchronized (lock) {
            c = client;
            ctx = appContext;
        }
        if (c == null || ctx == null) {
            return;
        }
        try {
            JSONObject fields = new JSONObject();
            fields.put("lens_contamination_enabled", desiredLensEnabled);
            fields.put("zero_point_offset_enabled", desiredZeroPointEnabled);
            JSONObject resp = c.request("ai_assist_config", fields);
            if (resp.optBoolean("ok", false)) {
                Log.i(TAG, "pushed ai_assist_config lens=" + desiredLensEnabled
                        + " zero_point=" + desiredZeroPointEnabled);
            } else {
                Log.w(TAG, "ai_assist_config rejected " + resp);
            }
        } catch (Exception e) {
            Log.w(TAG, "ai_assist_config push failed", e);
            requestRestart("assist_push_failed");
        }
    }

    private void scheduleWatchdog() {
        cancelWatchdog();
        watchdogFuture = scheduler.scheduleWithFixedDelay(
                this::watchdogTick, 1, 1, TimeUnit.SECONDS);
    }

    private void cancelWatchdog() {
        ScheduledFuture<?> f = watchdogFuture;
        watchdogFuture = null;
        if (f != null) {
            f.cancel(false);
        }
    }

    private void watchdogTick() {
        if (stopRequested.get()) {
            return;
        }
        Process p;
        synchronized (lock) {
            p = process;
        }
        if (p == null || !p.isAlive()) {
            requestRestart("process_dead");
            return;
        }
        if (inFlightLongCmd.get() > 0) {
            return;
        }
        long last = lastHeartbeatElapsedMs.get();
        if (last > 0 && android.os.SystemClock.elapsedRealtime() - last > HEARTBEAT_TIMEOUT_MS) {
            Log.w(TAG, "heartbeat timeout");
            requestRestart("heartbeat_timeout");
        }
    }

    private void requestRestart(@NonNull String reason) {
        if (stopRequested.get()) {
            return;
        }
        if (state.get() == DaemonState.ERROR) {
            return;
        }
        if (!restartInFlight.compareAndSet(false, true)) {
            return;
        }
        Context app;
        synchronized (lock) {
            state.set(DaemonState.RESTARTING);
            app = appContext;
            shutdownClientLocked();
            killProcessLocked();
        }
        if (app == null) {
            restartInFlight.set(false);
            return;
        }
        int burst = crashBurst.incrementAndGet();
        if (burst > MAX_CRASH_BURST) {
            restartInFlight.set(false);
            state.set(DaemonState.ERROR);
            Log.e(TAG, "daemon_state=error reason=" + reason + " burst=" + burst);
            return;
        }
        long delay = nextBackoffMs;
        nextBackoffMs = Math.min(BACKOFF_MAX_MS, nextBackoffMs * 2);
        Log.w(TAG, "restart scheduled reason=" + reason + " delayMs=" + delay + " burst=" + burst);
        scheduler.schedule(() -> {
            try {
                if (stopRequested.get()) {
                    return;
                }
                boolean ok = spawnAndConnectLockedPath(app, /*repush=*/true);
                if (!ok) {
                    restartInFlight.set(false);
                    requestRestart("respawn_failed");
                } else {
                    restartInFlight.set(false);
                    scheduleWatchdog();
                }
            } catch (Throwable t) {
                Log.e(TAG, "restart failed", t);
                restartInFlight.set(false);
                requestRestart("restart_throwable");
            }
        }, delay, TimeUnit.MILLISECONDS);
    }

    private void shutdownClientLocked() {
        AiDaemonSocketClient c = client;
        client = null;
        if (c != null) {
            try {
                JSONObject fields = new JSONObject();
                c.request("shutdown", fields);
            } catch (Exception ignored) {
            }
            c.close();
        }
    }

    private void killProcessLocked() {
        Process p = process;
        process = null;
        if (p == null) {
            return;
        }
        Log.i(TAG, "stopping daemon pid=" + processPid(p));
        p.destroy();
        try {
            if (!p.waitFor(500, TimeUnit.MILLISECONDS)) {
                p.destroyForcibly();
                p.waitFor(500, TimeUnit.MILLISECONDS);
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            p.destroyForcibly();
        }
        stderrDrain = null;
    }

    private void startStderrDrain(@NonNull Process proc) {
        Thread t = new Thread(() -> {
            try (BufferedReader r = new BufferedReader(new InputStreamReader(proc.getInputStream(),
                    StandardCharsets.UTF_8))) {
                String line;
                while ((line = r.readLine()) != null) {
                    Log.i(TAG, "daemon: " + line);
                }
            } catch (IOException ignored) {
            }
            try {
                int code = proc.waitFor();
                Log.w(TAG, "daemon exit code=" + code);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            if (!stopRequested.get()) {
                requestRestart("process_exit");
            }
        }, "ai-daemon-log");
        t.setDaemon(true);
        t.start();
        stderrDrain = t;
    }

    @NonNull
    static File workDir(@NonNull Context context) {
        return new File(context.getFilesDir(), "lens_guard");
    }

    @NonNull
    static File sockDir(@NonNull Context context) {
        return new File(context.getFilesDir(), "ai_daemon");
    }

    static void cleanSocks(@NonNull File sockDir) {
        File cmd = new File(sockDir, "cmd.sock");
        File evt = new File(sockDir, "evt.sock");
        //noinspection ResultOfMethodCallIgnored
        cmd.delete();
        //noinspection ResultOfMethodCallIgnored
        evt.delete();
    }

    private static boolean waitProcessAlive(@NonNull Process proc, long millis) {
        long deadline = System.currentTimeMillis() + millis;
        while (System.currentTimeMillis() < deadline) {
            if (!proc.isAlive()) {
                return false;
            }
            try {
                Thread.sleep(40L);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return proc.isAlive();
            }
        }
        return proc.isAlive();
    }

    private static int processPid(@NonNull Process proc) {
        try {
            return (int) Process.class.getMethod("pid").invoke(proc);
        } catch (Throwable t) {
            try {
                java.lang.reflect.Field f = proc.getClass().getDeclaredField("pid");
                f.setAccessible(true);
                return f.getInt(proc);
            } catch (Exception e) {
                return -1;
            }
        }
    }
}
