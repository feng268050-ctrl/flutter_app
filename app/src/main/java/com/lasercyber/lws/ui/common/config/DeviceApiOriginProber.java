package com.lasercyber.lws.ui.common.config;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.Network;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.blankj.utilcode.util.ToastUtils;
import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.ai.upload.AiUploadCoordinator;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.LwsCloudSyncLog;
import com.lasercyber.lws.ui.common.network.proxy.ClientPurpose;
import com.lasercyber.lws.ui.common.network.proxy.NetworkHttpClientProvider;
import com.lasercyber.lws.ui.common.network.proxy.NetworkRoutePolicy;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.worker.ProcessVideoCoverWorker;
import com.lasercyber.lws.ui.network.http.RequestApi;
import com.lasercyber.lws.ui.network.ws.DeviceWebSocketConnectionManager;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.atomic.AtomicLong;

import okhttp3.HttpUrl;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;

/**
 * Concurrent reachability probe for Worker API candidate bases; first success wins and cancels the rest.
 * <p>
 * {@link #probeWhenNetworkAvailable} applies a trailing debounce on the <em>probe</em> entry point (not on
 * WebSocket): rapid {@code onAvailable} bursts coalesce into one probe round. The post-probe {@code after}
 * runnable (typically WebSocket connect) runs only after a successful probe that pinned a base.
 */
public final class DeviceApiOriginProber {
    private static final String TAG = LogTAGConstant.DEVICE_API_ORIGIN_PROBE;
    /** Per-probe budget: fail fast (~5s total per HTTP GET). */
    private static final long PROBE_CONNECT_TIMEOUT_SEC = 3L;
    private static final long PROBE_READ_TIMEOUT_SEC = 4L;
    /** Whole-call ceiling (connect + TLS + response). */
    private static final long PROBE_CALL_TIMEOUT_SEC = 5L;
    /** Slightly above {@link #PROBE_CALL_TIMEOUT_SEC} so invokeAny can collect the first completion. */
    private static final long INVOKE_ANY_TIMEOUT_SEC = 6L;
    /** Coalesce rapid {@link ConnectivityManager.NetworkCallback#onAvailable} before starting HTTP probes. */
    private static final long ON_AVAILABLE_PROBE_DEBOUNCE_MS = 500L;

    /**
     * Bumped when a debounced probe round actually starts; used so an older in-flight probe does not run
     * {@code after} if a newer network event superseded it.
     */
    private static final AtomicLong probeTriggerGeneration = new AtomicLong(0L);

    private static final Object debounceLock = new Object();
    private static final ScheduledExecutorService debouncer = Executors.newSingleThreadScheduledExecutor(r -> {
        Thread t = new Thread(r, "device-api-origin-debounce");
        t.setDaemon(true);
        return t;
    });
    @Nullable
    private static ScheduledFuture<?> debouncedLaunchFuture;

    private DeviceApiOriginProber() {
    }

    @VisibleForTesting
    public static void resetForTest() {
        synchronized (debounceLock) {
            if (debouncedLaunchFuture != null) {
                debouncedLaunchFuture.cancel(false);
                debouncedLaunchFuture = null;
            }
        }
        probeTriggerGeneration.set(0L);
    }

    /**
     * Runs {@link #probeWhenNetworkAvailable(Network, Runnable)} synchronously on the current thread (unit tests only).
     */
    @VisibleForTesting
    public static void probeSynchronouslyForTest(@Nullable Network network, Runnable after) {
        long generation = probeTriggerGeneration.incrementAndGet();
        List<HttpUrl> candidates = DeviceApiOriginConfig.orderedCandidateBases();
        if (candidates.isEmpty()) {
            logW("probe skipped: no candidates");
            return;
        }
        runProbeRound(generation, network, candidates, after);
    }

    /**
     * After network is available: debounce, then run one probe round bound to {@code network}. If a candidate
     * wins, {@code after} runs (e.g. open WebSocket). If all probes fail, {@code after} is not run.
     */
    public static void probeWhenNetworkAvailable(@Nullable Network network, Runnable after) {
        synchronized (debounceLock) {
            if (debouncedLaunchFuture != null) {
                debouncedLaunchFuture.cancel(false);
                debouncedLaunchFuture = null;
            }
            final Network net = network;
            final Runnable afterRun = after;
            debouncedLaunchFuture = debouncer.schedule(
                    () -> launchDebouncedProbe(net, afterRun),
                    ON_AVAILABLE_PROBE_DEBOUNCE_MS,
                    TimeUnit.MILLISECONDS);
        }
    }

    private static void launchDebouncedProbe(@Nullable Network network, Runnable after) {
        synchronized (debounceLock) {
            debouncedLaunchFuture = null;
        }
        logI("debounced probe: starting (delayMs=" + ON_AVAILABLE_PROBE_DEBOUNCE_MS + ")");
        long generation = probeTriggerGeneration.incrementAndGet();
        List<HttpUrl> candidates = DeviceApiOriginConfig.orderedCandidateBases();
        if (candidates.isEmpty()) {
            logW("probe skipped: no candidates, skip ws bootstrap");
            return;
        }
        ThreadPoolManager.getExecutor().execute(() -> runProbeRound(generation, network, candidates, after));
    }

    private static void runProbeRound(
            long generation,
            @Nullable Network network,
            List<HttpUrl> candidates,
            Runnable after) {
        synchronized (DeviceApiOriginProber.class) {
            if (generation != probeTriggerGeneration.get()) {
                logI("probe round abandoned (superseded), gen=" + generation + " latest=" + probeTriggerGeneration.get());
                return;
            }
            boolean pinned = false;
            HttpUrl winner = null;
            OkHttpClient boundClient = buildProbeClient(network);

            // Single candidate: run probe on this thread. newFixedThreadPool(1)+invokeAny has caused hangs/failures
            // on some devices when only CANDIDATE_BASES_TEST has one entry; parallel pool is unnecessary for n==1.
            if (candidates.size() == 1) {
                HttpUrl only = candidates.get(0);
                try {
                    winner = probeOne(boundClient, only);
                    DeviceApiOriginConfig.setPinnedBase(winner);
                    pinned = true;
                    logI("probe ok (single candidate), pinned=" + winner);
                } catch (IOException e) {
                    if (network != null) {
                        logW("single candidate probe failed on bound network, retry unbound: " + only, e);
                        OkHttpClient unbound = buildProbeClient(null);
                        try {
                            winner = probeOne(unbound, only);
                            DeviceApiOriginConfig.setPinnedBase(winner);
                            pinned = true;
                            logI("probe ok (single candidate, unbound retry), pinned=" + winner);
                        } catch (IOException e2) {
                            logW("single candidate probe failed for " + only, e2);
                        }
                    } else {
                        logW("single candidate probe failed for " + only, e);
                    }
                }
            } else {
                ExecutorService pool = Executors.newFixedThreadPool(Math.min(4, candidates.size()));
                List<Callable<HttpUrl>> tasks = new ArrayList<>(candidates.size());
                for (HttpUrl base : candidates) {
                    tasks.add(() -> probeOne(boundClient, base));
                }
                try {
                    winner = pool.invokeAny(tasks, INVOKE_ANY_TIMEOUT_SEC, TimeUnit.SECONDS);
                    DeviceApiOriginConfig.setPinnedBase(winner);
                    pinned = true;
                    logI("probe ok, pinned=" + winner);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    logW("probe interrupted", e);
                } catch (TimeoutException e) {
                    logW("probe timed out waiting for any candidate", e);
                } catch (ExecutionException e) {
                    logW("all candidate probes failed", e);
                } finally {
                    pool.shutdownNow();
                    try {
                        if (!pool.awaitTermination(2, TimeUnit.SECONDS)) {
                            logW("probe pool did not terminate cleanly");
                        }
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                    }
                }
            }

            if (pinned) {
                try {
                    RetrofitClient.invalidate();
                    RequestApi.invalidateCachedClients();
                } catch (Throwable t) {
                    logW("invalidate retrofit after API pin failed", t);
                }
            }

            if (!pinned) {
                logW("probe no winner, skip ws bootstrap (gen=" + generation + ")");
                postProbeAllFailedToast();
                return;
            }
            if (generation != probeTriggerGeneration.get()) {
                logI("probe winner ignored for ws: superseded gen=" + generation + " latest=" + probeTriggerGeneration.get());
                return;
            }
            logI("running post-probe action (ws connect), gen=" + generation);
            try {
                ProcessVideoCoverWorker.enqueueAllPendingCoalesced(Utils.getApp());
            } catch (Throwable t) {
                logW("enqueue pending video cover failed", t);
            }
            try {
                AiUploadCoordinator.scheduleDrain(Utils.getApp());
            } catch (Throwable t) {
                logW("enqueue pending AI uploads failed", t);
            }
            runAfterProbe(after);
        }
    }

    private static void runAfterProbe(Runnable r) {
        if (r == null) {
            return;
        }
        r.run();
    }

    private static OkHttpClient buildProbeClient(@Nullable Network network) {
        return NetworkHttpClientProvider.getInstance()
                .getClient(ClientPurpose.PROBE, NetworkRoutePolicy.INTERNET_PROXY_AWARE, network);
    }

    private static void postProbeAllFailedToast() {
        try {
            Context app = Utils.getApp();
            if (app == null) {
                return;
            }
            String msg = app.getString(R.string.api_origin_probe_failed);
            new Handler(Looper.getMainLooper()).post(() -> ToastUtils.showLong(msg));
        } catch (Throwable ignored) {
        }
    }

    private static HttpUrl probeOne(OkHttpClient client, HttpUrl base) throws IOException {
        HttpUrl probeUrl = DeviceApiOriginConfig.rootProbeHttpUrl(base);
        Request request = new Request.Builder().url(probeUrl).get().build();
        try (Response response = client.newCall(request).execute()) {
            okhttp3.ResponseBody body = response.body();
            if (body != null) {
                body.string();
            }
        }
        return base;
    }

    private static void logI(String message) {
        try {
            Log.i(TAG, message);
            LwsCloudSyncLog.i("ApiProbe", message);
        } catch (RuntimeException ignored) {
        }
    }

    private static void logW(String message) {
        try {
            Log.w(TAG, message);
            LwsCloudSyncLog.w("ApiProbe", message);
        } catch (RuntimeException ignored) {
            // android.util.Log is not mocked on JVM unit tests
        }
    }

    private static void logW(String message, Throwable t) {
        try {
            Log.w(TAG, message, t);
            LwsCloudSyncLog.w("ApiProbe", message, t);
        } catch (RuntimeException ignored) {
            // android.util.Log is not mocked on JVM unit tests
        }
    }

    /**
     * User switched runtime tier: supersede in-flight probes, clear pin, and schedule a fresh debounced probe +
     * WebSocket reconnect on the default network.
     */
    public static void onAppEnvironmentChanged(Context applicationContext) {
        if (applicationContext == null) {
            return;
        }
        synchronized (debounceLock) {
            if (debouncedLaunchFuture != null) {
                debouncedLaunchFuture.cancel(false);
                debouncedLaunchFuture = null;
            }
        }
        probeTriggerGeneration.incrementAndGet();
        DeviceApiOriginConfig.clearPinnedBase();
        ConnectivityManager cm = (ConnectivityManager) applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE);
        Network n = cm != null ? cm.getActiveNetwork() : null;
        probeWhenNetworkAvailable(n, () -> {
            try {
                DeviceWebSocketConnectionManager.getInstance().connectOrReconnect("app_env_changed");
            } catch (Throwable t) {
                Log.e(TAG, "app env change: ws bootstrap skipped", t);
            }
        });
    }
}
