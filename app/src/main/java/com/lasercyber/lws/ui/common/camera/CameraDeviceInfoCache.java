package com.lasercyber.lws.ui.common.camera;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.network.http.remote.CameraRemote;

import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Unified in-memory cache for normalized camera {@code appVersion} from {@code GET /System/deviceinfo}.
 * Fetches once per cache epoch with exponential backoff; no periodic HTTP refresh.
 */
public final class CameraDeviceInfoCache {

    private static final long[] BACKOFF_DELAYS_MS = {1000L, 2000L, 4000L, 8000L, 16000L};

    private static final AtomicBoolean refreshInFlight = new AtomicBoolean(false);
    private static final AtomicBoolean versionResolved = new AtomicBoolean(false);
    private static final AtomicBoolean backoffActive = new AtomicBoolean(false);
    private static final AtomicBoolean backoffExhausted = new AtomicBoolean(false);
    private static final AtomicBoolean versionFetchPending = new AtomicBoolean(false);
    private static final AtomicInteger backoffAttempt = new AtomicInteger(0);
    private static final CopyOnWriteArrayList<Runnable> pendingCallbacks = new CopyOnWriteArrayList<>();
    private static final AtomicReference<String> displayRef =
            new AtomicReference<>(CameraRemote.CAMERA_VERSION_UNAVAILABLE);

    private static final Handler backoffHandler = new Handler(Looper.getMainLooper());
    private static DelayScheduler delayScheduler = (delayMs, task) -> backoffHandler.postDelayed(task, delayMs);

    private static DeviceInfoFetcher deviceInfoFetcher =
            (context, callback) -> CameraRemote.fetchDeviceInfoDisplay(context, callback::onResult);

    @Nullable
    private static Context backoffContext;

    private CameraDeviceInfoCache() {
    }

    @NonNull
    public static String getDisplay() {
        String cached = displayRef.get();
        if (cached == null || cached.isEmpty()) {
            return CameraRemote.CAMERA_VERSION_UNAVAILABLE;
        }
        return cached;
    }

    public static void refresh(@Nullable Context context) {
        refresh(context, null);
    }

    /**
     * Starts or joins backoff fetch when version is unresolved; no-ops HTTP when already cached.
     */
    public static void refresh(@Nullable Context context, @Nullable Runnable onComplete) {
        if (onComplete != null) {
            pendingCallbacks.add(onComplete);
        }
        if (versionResolved.get()) {
            drainPendingCallbacks();
            return;
        }
        versionFetchPending.set(true);
        if (context == null) {
            if (!refreshInFlight.get() && !backoffActive.get()) {
                drainPendingCallbacks();
            }
            return;
        }
        Context app = context.getApplicationContext();
        backoffContext = app;
        requestVersionFetchWhenPingReady(app);
    }

    /**
     * Ping became reachable; start version HTTP backoff if a fetch was requested while unreachable.
     */
    static void onPingBecameReachable() {
        if (versionResolved.get() || backoffExhausted.get() || !versionFetchPending.get()) {
            return;
        }
        Context app = backoffContext;
        if (app == null) {
            startBackoffIfNeeded(null);
            return;
        }
        requestVersionFetchWhenPingReady(app);
    }

    /** Ping lost while version fetch pending; pause HTTP backoff until ping recovers. */
    static void onPingBecameUnreachable() {
        if (backoffActive.get() || refreshInFlight.get()) {
            pauseBackoffForUnreachable();
        }
    }

    private static void requestVersionFetchWhenPingReady(@NonNull Context app) {
        backoffContext = app;
        if (!CameraPingHealth.getInstance().isReachable()) {
            CameraPingHealth.getInstance().probeAsync();
            return;
        }
        startBackoffIfNeeded(app);
    }

    /** Clears cached value and schedules a backoff refresh (e.g. camera host preference changed). */
    public static void clearAndRefresh(@Nullable Context context) {
        cancelBackoff();
        versionResolved.set(false);
        backoffExhausted.set(false);
        backoffAttempt.set(0);
        applyDisplay(CameraRemote.CAMERA_VERSION_UNAVAILABLE);
        refresh(context);
    }

    @VisibleForTesting
    static void refreshBackoffForTest(@Nullable Runnable onComplete) {
        if (onComplete != null) {
            pendingCallbacks.add(onComplete);
        }
        if (versionResolved.get()) {
            drainPendingCallbacks();
            return;
        }
        versionFetchPending.set(true);
        if (!CameraPingHealth.getInstance().isReachable()) {
            return;
        }
        startBackoffIfNeeded(null);
    }

    private static void startBackoffIfNeeded(@Nullable Context app) {
        if (!CameraPingHealth.getInstance().isReachable()) {
            return;
        }
        if (versionResolved.get()) {
            drainPendingCallbacks();
            return;
        }
        if (backoffExhausted.get()) {
            drainPendingCallbacks();
            return;
        }
        if (!backoffActive.compareAndSet(false, true)) {
            return;
        }
        backoffAttempt.set(0);
        enqueueAttempt(app, 0L);
    }

    private static void enqueueAttempt(@Nullable Context app, long delayMs) {
        delayScheduler.schedule(delayMs, () -> {
            if (versionResolved.get()) {
                finishBackoff();
                return;
            }
            if (!backoffActive.get()) {
                return;
            }
            if (!CameraPingHealth.getInstance().isReachable()) {
                pauseBackoffForUnreachable();
                return;
            }
            int attemptIndex = backoffAttempt.getAndIncrement();
            if (attemptIndex >= BACKOFF_DELAYS_MS.length) {
                markBackoffExhausted();
                return;
            }
            if (!refreshInFlight.compareAndSet(false, true)) {
                backoffAttempt.decrementAndGet();
                enqueueAttempt(app, 50L);
                return;
            }
            deviceInfoFetcher.fetch(app, display -> {
                applyDisplay(display);
                refreshInFlight.set(false);
                if (isValidVersion(display)) {
                    finishBackoff();
                    return;
                }
                if (backoffAttempt.get() >= BACKOFF_DELAYS_MS.length) {
                    markBackoffExhausted();
                    return;
                }
                enqueueAttempt(app, BACKOFF_DELAYS_MS[attemptIndex]);
            });
        });
    }

    private static void markBackoffExhausted() {
        backoffExhausted.set(true);
        versionFetchPending.set(false);
        finishBackoff();
    }

    private static void finishBackoff() {
        backoffActive.set(false);
        backoffAttempt.set(0);
        drainPendingCallbacks();
    }

    private static void pauseBackoffForUnreachable() {
        backoffHandler.removeCallbacksAndMessages(null);
        backoffActive.set(false);
        refreshInFlight.set(false);
    }

    private static void cancelBackoff() {
        backoffHandler.removeCallbacksAndMessages(null);
        backoffActive.set(false);
        backoffAttempt.set(0);
        backoffContext = null;
    }

    private static boolean isValidVersion(@NonNull String display) {
        return !CameraRemote.CAMERA_VERSION_UNAVAILABLE.equals(display);
    }

    private static void applyDisplay(@NonNull String display) {
        displayRef.set(display);
        if (isValidVersion(display)) {
            versionResolved.set(true);
            versionFetchPending.set(false);
        }
        MemoryCacheManager.getInstance().putString(CacheKey.CAMERA_VERSION_DISPLAY, display);
    }

    private static void drainPendingCallbacks() {
        for (Runnable runnable : pendingCallbacks) {
            if (runnable != null) {
                runnable.run();
            }
        }
        pendingCallbacks.clear();
    }

    @VisibleForTesting
    public static void resetForTest() {
        cancelBackoff();
        refreshInFlight.set(false);
        versionResolved.set(false);
        backoffExhausted.set(false);
        versionFetchPending.set(false);
        pendingCallbacks.clear();
        displayRef.set(CameraRemote.CAMERA_VERSION_UNAVAILABLE);
        delayScheduler = (delayMs, task) -> backoffHandler.postDelayed(task, delayMs);
        deviceInfoFetcher =
                (context, callback) -> CameraRemote.fetchDeviceInfoDisplay(context, callback::onResult);
        MemoryCacheManager.getInstance().remove(CacheKey.CAMERA_VERSION_DISPLAY);
    }

    @VisibleForTesting
    static void applyDisplayForTest(@NonNull String display) {
        applyDisplay(display);
    }

    @VisibleForTesting
    static boolean isRefreshInFlightForTest() {
        return refreshInFlight.get();
    }

    @VisibleForTesting
    static void completeRefreshForTest(@NonNull String display) {
        applyDisplay(display);
        refreshInFlight.set(false);
        versionResolved.set(isValidVersion(display));
        finishBackoff();
    }

    @VisibleForTesting
    static int pendingCallbackCountForTest() {
        return pendingCallbacks.size();
    }

    @VisibleForTesting
    static void beginRefreshForTest() {
        refreshInFlight.set(true);
    }

    @VisibleForTesting
    static boolean isVersionResolvedForTest() {
        return versionResolved.get();
    }

    @VisibleForTesting
    static void setDelaySchedulerForTest(DelayScheduler scheduler) {
        delayScheduler = scheduler;
    }

    @VisibleForTesting
    static int backoffAttemptForTest() {
        return backoffAttempt.get();
    }

    @VisibleForTesting
    static void runBackoffAttemptForTest(@NonNull Context context) {
        enqueueAttempt(context.getApplicationContext(), 0L);
    }

    @VisibleForTesting
    static void setDeviceInfoFetcherForTest(DeviceInfoFetcher fetcher) {
        deviceInfoFetcher = fetcher;
    }

    @FunctionalInterface
    interface DeviceInfoFetcher {
        void fetch(@Nullable Context context, @NonNull DeviceInfoCallback callback);
    }

    @FunctionalInterface
    interface DeviceInfoCallback {
        void onResult(@NonNull String display);
    }

    @FunctionalInterface
    interface DelayScheduler {
        void schedule(long delayMs, @NonNull Runnable task);
    }
}
