package com.lasercyber.lws.ui.common.camera;

import android.os.SystemClock;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.config.CameraConfig;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.ShellCmdUtil;

import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * ICMP reachability probe for the configured camera IP; drives {@link CameraCommStatus}.
 */
public final class CameraPingHealth {

    private static final String TAG = LogTAGConstant.CameraPingHealth;

    private static final CameraPingHealth INSTANCE = new CameraPingHealth();

    /**
     * Consecutive successful pings required before declaring recovery, so a single
     * successful reply does not clear C002 and re-arm the popup while comm is still down.
     */
    @VisibleForTesting
    static final int RECOVERY_STABLE_PINGS = 3;

    /** Ignore probe failures briefly after eth0 configure (ARP flush / in-flight probes). */
    @VisibleForTesting
    static final long POST_CONFIGURE_QUIET_MS = 5_000L;

    /** Optimistic until a probe fails — enables the first fault to notify listeners. */
    private final AtomicBoolean reachable = new AtomicBoolean(true);
    private final AtomicBoolean probeInFlight = new AtomicBoolean(false);
    private final AtomicInteger eth0ConfigureDepth = new AtomicInteger(0);
    private int consecutiveOkProbes;
    private long postConfigureQuietUntilElapsedMs = -1L;
    private boolean reachableAtConfigureBegin;

    @Nullable
    private volatile PingExecutor pingExecutor = CameraPingHealth::defaultPing;

    private CameraPingHealth() {
    }

    public static CameraPingHealth getInstance() {
        return INSTANCE;
    }

    public boolean isReachable() {
        return reachable.get();
    }

    /** While {@code eth0} is being reconfigured, periodic ICMP probes are suspended. */
    public boolean isEth0Configuring() {
        return eth0ConfigureDepth.get() > 0;
    }

    /** Suppresses C002 rising edges during configure and the post-configure quiet window. */
    public boolean shouldSuppressFaultEdges() {
        return isEth0Configuring() || isPostConfigureQuietActive();
    }

    /**
     * Pauses reachability evaluation while {@link com.lasercyber.lws.ui.common.network.CameraEth0Configurator}
     * mutates {@code eth0} addressing, so transient ping loss does not re-trigger C002.
     */
    public void beginEth0Configure() {
        if (eth0ConfigureDepth.getAndIncrement() == 0) {
            reachableAtConfigureBegin = reachable.get();
            Log.i(TAG, "suspend icmp probes during eth0 configure reachable=" + reachableAtConfigureBegin);
        }
    }

    /**
     * Resumes probes and applies the configurator's final ping when available.
     * A failed configure ping does not downgrade a previously healthy link.
     */
    public void endEth0Configure(boolean pingOk) {
        int remaining = eth0ConfigureDepth.decrementAndGet();
        if (remaining > 0) {
            return;
        }
        if (remaining < 0) {
            eth0ConfigureDepth.set(0);
            return;
        }
        postConfigureQuietUntilElapsedMs = SystemClock.elapsedRealtime() + POST_CONFIGURE_QUIET_MS;
        if (pingOk) {
            onProbeResult(true);
        } else if (!reachableAtConfigureBegin) {
            consecutiveOkProbes = 0;
        } else {
            Log.i(TAG, "eth0 configure finished without ping; keeping reachability");
        }
        Log.i(TAG, "resume icmp probes after eth0 configure pingOk=" + pingOk);
    }

    private boolean isPostConfigureQuietActive() {
        return postConfigureQuietUntilElapsedMs >= 0L
                && SystemClock.elapsedRealtime() < postConfigureQuietUntilElapsedMs;
    }

    /** Fire-and-forget probe; coalesces when a probe is already running. */
    public void probeAsync() {
        if (isEth0Configuring()) {
            return;
        }
        if (!probeInFlight.compareAndSet(false, true)) {
            return;
        }
        ThreadPoolManager.getExecutor().execute(() -> {
            try {
                boolean ok = executePing(CameraConfig.getCameraIp());
                onProbeResult(ok);
            } finally {
                probeInFlight.set(false);
            }
        });
    }

    /**
     * Runs one ICMP probe on the calling thread and returns the raw result.
     * Unlike {@link #awaitReachable(long)}, this always executes a probe instead of
     * trusting the optimistic default reachable flag.
     */
    public boolean probeBlocking() {
        if (isEth0Configuring()) {
            return reachable.get();
        }
        boolean ok = executePing(CameraConfig.getCameraIp());
        onProbeResult(ok);
        return ok;
    }

    /**
     * Ensures a probe runs and waits up to {@code timeoutMs} for a reachable result.
     */
    public boolean awaitReachable(long timeoutMs) {
        if (reachable.get()) {
            return true;
        }
        probeAsync();
        long deadline = System.currentTimeMillis() + timeoutMs;
        while (System.currentTimeMillis() < deadline) {
            if (reachable.get()) {
                return true;
            }
            try {
                Thread.sleep(50L);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            }
        }
        return reachable.get();
    }

    private void onProbeResult(boolean pingOk) {
        if (isEth0Configuring()) {
            return;
        }
        if (!pingOk && isPostConfigureQuietActive()) {
            return;
        }
        boolean wasReachable = reachable.get();
        if (pingOk) {
            if (wasReachable) {
                consecutiveOkProbes = 0;
                return;
            }
            consecutiveOkProbes++;
            if (consecutiveOkProbes >= RECOVERY_STABLE_PINGS) {
                consecutiveOkProbes = 0;
                commitReachable(true);
            }
        } else {
            consecutiveOkProbes = 0;
            if (!wasReachable) {
                return;
            }
            commitReachable(false);
        }
    }

    private void commitReachable(boolean ok) {
        boolean previous = reachable.getAndSet(ok);
        if (previous != ok) {
            Log.i(TAG, "camera ping reachable=" + ok + " host=" + CameraConfig.getCameraIp());
            MemoryCacheManager.getInstance().putString(CacheKey.CAMERA_PING_REACHABLE, ok ? "1" : "0");
            if (ok) {
                CameraDeviceInfoCache.onPingBecameReachable();
            } else {
                postConfigureQuietUntilElapsedMs = -1L;
                CameraDeviceInfoCache.onPingBecameUnreachable();
            }
        }
    }

    private boolean executePing(@NonNull String host) {
        PingExecutor executor = pingExecutor;
        if (executor == null) {
            return false;
        }
        try {
            return executor.ping(host);
        } catch (Throwable t) {
            Log.w(TAG, "ping failed host=" + host, t);
            return false;
        }
    }


    private static boolean defaultPing(@NonNull String host) {
        return ShellCmdUtil.isCameraHostPingReachable(host);
    }

    @VisibleForTesting
    void resetForTest() {
        reachable.set(true);
        consecutiveOkProbes = 0;
        postConfigureQuietUntilElapsedMs = -1L;
        eth0ConfigureDepth.set(0);
        probeInFlight.set(false);
        pingExecutor = CameraPingHealth::defaultPing;
        MemoryCacheManager.getInstance().remove(CacheKey.CAMERA_PING_REACHABLE);
    }

    @VisibleForTesting
    void setReachableForTest(boolean ok) {
        consecutiveOkProbes = 0;
        commitReachable(ok);
    }

    @VisibleForTesting
    void onProbeResultForTest(boolean pingOk) {
        onProbeResult(pingOk);
    }

    @VisibleForTesting
    void setPingExecutorForTest(@Nullable PingExecutor executor) {
        pingExecutor = executor;
    }

    @VisibleForTesting
    void beginEth0ConfigureForTest() {
        beginEth0Configure();
    }

    @VisibleForTesting
    void endEth0ConfigureForTest(boolean pingOk) {
        endEth0Configure(pingOk);
    }

    @VisibleForTesting
    boolean isProbeInFlightForTest() {
        return probeInFlight.get();
    }

    @FunctionalInterface
    interface PingExecutor {
        boolean ping(@NonNull String host);
    }
}
