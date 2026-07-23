package com.lasercyber.lws.ui.network.mediamtx;

import android.content.Context;
import android.util.Log;

import androidx.annotation.GuardedBy;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import android.os.Build;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.utils.AndroidEmulatorUtils;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Owns MediaMTX process lifecycle: always-on LAN preview (replaces legacy {@code GET /v1/camera/live})
 * plus optional extra leases that do not tear down the relay while LAN preview is held.
 */
public final class MediaMtxRelayCoordinator {

    private static final String TAG = LogTAGConstant.MEDIA_MTX_RELAY;
    private static final MediaMtxRelayCoordinator INSTANCE = new MediaMtxRelayCoordinator();

    private final Object lock = new Object();
    @GuardedBy("lock")
    @Nullable
    private Context appContext;
    @GuardedBy("lock")
    @Nullable
    private Process process;
    @GuardedBy("lock")
    @Nullable
    private MediaMtxBinary.ResolvedBinary resolved;
    @GuardedBy("lock")
    @Nullable
    private Thread stderrDrain;
    /** Extra holders (e.g. background loop recorder); does not include the LAN preview hold. */
    private final AtomicInteger extraLeaseCount = new AtomicInteger(0);
    @GuardedBy("lock")
    private boolean lanPreviewHold;
    @GuardedBy("lock")
    private boolean shutdownHookRegistered;

    private MediaMtxRelayCoordinator() {
    }

    @NonNull
    public static MediaMtxRelayCoordinator getInstance() {
        return INSTANCE;
    }

    public void init(@NonNull Context context) {
        synchronized (lock) {
            appContext = context.getApplicationContext();
            if (!shutdownHookRegistered) {
                shutdownHookRegistered = true;
                Runtime.getRuntime().addShutdownHook(new Thread(this::stopProcessLocked,
                        "mediamtx-shutdown"));
            }
        }
    }

    /**
     * Start MediaMTX for LAN RTSP preview ({@code rtsp://<device-lan-ip>:8554/camera/pr0}).
     * Call once from application scope; holds until process exit.
     */
    public void startForLanPreview() {
        synchronized (lock) {
            lanPreviewHold = true;
            if (AndroidEmulatorUtils.isLikelyEmulator()) {
                Log.i(TAG, "startForLanPreview skipped on emulator (use peer relay via camera_ip)");
                return;
            }
            boolean ok = ensureRunningLocked();
            Log.i(TAG, "startForLanPreview ok=" + ok
                    + " relayReady=" + isRelayReadyUnlocked()
                    + " upstreamPr0=" + MediaMtxConfigRenderer.currentUpstreamPr0RtspUrl()
                    + " upstreamPr1=" + MediaMtxConfigRenderer.currentUpstreamPr1RtspUrl()
                    + " lanPr0=rtsp://<device-lan-ip>:" + MediaMtxRelayUrls.RTSP_PORT
                    + "/" + MediaMtxRelayUrls.PATH_PR0
                    + " lanPr1=.../" + MediaMtxRelayUrls.PATH_PR1
                    + " recordIngest=" + MediaMtxRelayUrls.localPr0()
                    + " inferIngest=" + MediaMtxRelayUrls.localPr1());
        }
    }

    private boolean isRelayReadyUnlocked() {
        return process != null && process.isAlive();
    }

    /**
     * Optional extra hold so teardown waits until all recorders release (does not stop LAN preview).
     */
    public boolean acquireLease() {
        synchronized (lock) {
            extraLeaseCount.incrementAndGet();
            return ensureRunningLocked();
        }
    }

    public void releaseLease() {
        synchronized (lock) {
            int n = extraLeaseCount.decrementAndGet();
            if (n < 0) {
                extraLeaseCount.set(0);
            }
            maybeStopLocked();
        }
    }

    public boolean isRelayReady() {
        synchronized (lock) {
            return process != null && process.isAlive();
        }
    }

    @VisibleForTesting
    int extraLeaseCountForTest() {
        return extraLeaseCount.get();
    }

    @VisibleForTesting
    boolean lanPreviewHoldForTest() {
        synchronized (lock) {
            return lanPreviewHold;
        }
    }

    @VisibleForTesting
    void resetForTest() {
        synchronized (lock) {
            extraLeaseCount.set(0);
            lanPreviewHold = false;
            stopProcessLocked();
            appContext = null;
        }
    }

    private void maybeStopLocked() {
        if (lanPreviewHold) {
            return;
        }
        if (extraLeaseCount.get() == 0) {
            stopProcessLocked();
        }
    }

    private boolean ensureRunningLocked() {
        if (process != null && process.isAlive()) {
            Log.d(TAG, "ensureRunning: reuse existing mediamtx pid=" + processPid(process)
                    + " (mediamtx.yml upstream log only on fresh start)");
            return true;
        }
        Context ctx = appContext;
        if (ctx == null) {
            Log.w(TAG, "ensureRunning: appContext null");
            return false;
        }
        try {
            resolved = MediaMtxBinary.resolve(ctx);
        } catch (IOException e) {
            Log.e(TAG, "resolve mediamtx binary failed", e);
            return false;
        }
        if (resolved == null || !resolved.executable.canExecute()) {
            Log.w(TAG, "relay_not_ready: mediamtx binary missing (run make mediamtx and rebuild APK)");
            return false;
        }
        try {
            writeConfig(resolved.configFile);
        } catch (IOException e) {
            Log.e(TAG, "write mediamtx.yml failed path=" + resolved.configFile, e);
            return false;
        }
        try {
            ProcessBuilder pb = new ProcessBuilder(
                    resolved.executable.getAbsolutePath(),
                    resolved.configFile.getAbsolutePath());
            pb.redirectErrorStream(true);
            pb.directory(resolved.executable.getParentFile());
            process = pb.start();
            startStderrDrain(process);
            if (!waitProcessAlive(process, 500L)) {
                int exit = exitCodeIfExited(process);
                Log.e(TAG, "mediamtx exited immediately exit=" + exit
                        + " (APK binary must be GOOS=android; run make mediamtx and reinstall)");
                process = null;
                return false;
            }
            Log.i(TAG, "mediamtx start pid=" + processPid(process)
                    + " binary=" + resolved.executable.getAbsolutePath()
                    + " conf=" + resolved.configFile.getAbsolutePath()
                    + " version=" + resolved.version);
            return true;
        } catch (IOException e) {
            Log.e(TAG, "mediamtx start failed", e);
            process = null;
            return false;
        }
    }

    private void writeConfig(@NonNull File configFile) throws IOException {
        File parent = configFile.getParentFile();
        if (parent != null && !parent.exists() && !parent.mkdirs()) {
            throw new IOException("mkdir " + parent);
        }
        byte[] yaml = MediaMtxConfigRenderer.renderYaml().getBytes(StandardCharsets.UTF_8);
        Log.i(TAG, "mediamtx.yml upstream pr0=" + MediaMtxConfigRenderer.currentUpstreamPr0RtspUrl()
                + " pr1=" + MediaMtxConfigRenderer.currentUpstreamPr1RtspUrl());
        try (FileOutputStream out = new FileOutputStream(configFile)) {
            out.write(yaml);
        }
    }

    private void startStderrDrain(@NonNull Process proc) {
        Thread t = new Thread(() -> {
            StringBuilder tail = new StringBuilder();
            try (BufferedReader r = new BufferedReader(new InputStreamReader(proc.getInputStream(),
                    StandardCharsets.UTF_8))) {
                String line;
                while ((line = r.readLine()) != null) {
                    if (tail.length() < 4000) {
                        tail.append(line).append('\n');
                    }
                    Log.i(TAG, "mediamtx: " + line);
                }
            } catch (IOException ignored) {
            }
            try {
                int code = proc.waitFor();
                Log.w(TAG, "mediamtx exit code=" + code + " stderrTail=" + tail);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            synchronized (MediaMtxRelayCoordinator.this.lock) {
                if (MediaMtxRelayCoordinator.this.process == proc) {
                    MediaMtxRelayCoordinator.this.process = null;
                }
            }
        }, "mediamtx-log-drain");
        t.setDaemon(true);
        t.start();
        stderrDrain = t;
    }

    private void stopProcessLocked() {
        Process p = process;
        process = null;
        resolved = null;
        if (p != null) {
            Log.i(TAG, "mediamtx stop pid=" + processPid(p));
            p.destroy();
            try {
                Thread.sleep(200L);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            if (p.isAlive()) {
                p.destroyForcibly();
            }
        }
        stderrDrain = null;
    }

    private static boolean waitProcessAlive(@NonNull Process proc, long millis) {
        long deadline = System.currentTimeMillis() + millis;
        while (System.currentTimeMillis() < deadline) {
            if (!proc.isAlive()) {
                return false;
            }
            try {
                Thread.sleep(50L);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return proc.isAlive();
            }
        }
        return proc.isAlive();
    }

    private static int exitCodeIfExited(@NonNull Process proc) {
        try {
            return proc.exitValue();
        } catch (IllegalThreadStateException e) {
            return -1;
        }
    }

    private static int processPid(@NonNull Process p) {
        if (Build.VERSION.SDK_INT >= 26) {
            try {
                return (int) Process.class.getMethod("pid").invoke(p);
            } catch (Exception ignored) {
            }
        }
        try {
            java.lang.reflect.Field f = p.getClass().getDeclaredField("pid");
            f.setAccessible(true);
            return f.getInt(p);
        } catch (Exception e) {
            return -1;
        }
    }
}
