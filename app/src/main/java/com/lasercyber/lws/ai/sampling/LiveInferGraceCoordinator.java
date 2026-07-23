package com.lasercyber.lws.ai.sampling;
import com.lasercyber.lws.ai.stream.LaserDetectSamplingCoordinator;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.gpio.LaserEnableStateHolder;

import java.util.concurrent.CopyOnWriteArrayList;

/**
 * After laser enable OFF (End of work), keep live infer (PR1 stream + zero_point + lens_det sampling)
 * active for a short grace window before tearing down the round.
 */
public final class LiveInferGraceCoordinator implements LaserEnableStateHolder.Listener {

    private static final String TAG = "LiveInferGrace";

    /** Package-visible for tests and log messages. */
    public static final long DEFAULT_GRACE_AFTER_LASER_OFF_MS = 3000L;

    public interface GraceEndedListener {
        void onLiveInferGraceEnded(String trigger);
    }

    private static volatile LiveInferGraceCoordinator instance;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private final CopyOnWriteArrayList<GraceEndedListener> listeners = new CopyOnWriteArrayList<>();

    private volatile boolean attached;
    @Nullable
    private volatile Boolean lastLaserEnableActive;
    private volatile long graceEndElapsedMs = 0L;
    private String graceTrigger = "";

    private final Runnable graceExpireRunnable = this::expireGrace;

    public static LiveInferGraceCoordinator getInstance() {
        if (instance == null) {
            synchronized (LiveInferGraceCoordinator.class) {
                if (instance == null) {
                    instance = new LiveInferGraceCoordinator();
                }
            }
        }
        return instance;
    }

    public void attach(@Nullable Context context) {
        if (attached) {
            return;
        }
        attached = true;
        lastLaserEnableActive = LaserEnableStateHolder.isActive();
        LaserEnableStateHolder.addListener(this);
        Log.i(TAG, "attached graceMs=" + DEFAULT_GRACE_AFTER_LASER_OFF_MS);
    }

    public void detach() {
        if (!attached) {
            return;
        }
        cancelGrace();
        LaserEnableStateHolder.removeListener(this);
        listeners.clear();
        attached = false;
        lastLaserEnableActive = null;
        Log.i(TAG, "detached");
    }

    public void addGraceEndedListener(GraceEndedListener listener) {
        listeners.add(listener);
    }

    public void removeGraceEndedListener(GraceEndedListener listener) {
        listeners.remove(listener);
    }

    /** Laser enable ON, or still inside the post-enable-OFF grace window. */
    public boolean isLiveInferActive() {
        if (LaserEnableStateHolder.isActive()) {
            return true;
        }
        return isInGracePeriod();
    }

    public boolean isInGracePeriod() {
        long end = graceEndElapsedMs;
        return end > 0L && SystemClock.elapsedRealtime() < end;
    }

    /** Package-visible for unit tests. */
    static boolean isLiveInferActive(boolean laserEnableActive, long nowElapsed, long graceEndElapsed) {
        return laserEnableActive || (graceEndElapsed > 0L && nowElapsed < graceEndElapsed);
    }

    @Override
    public void onLaserEnableChanged(boolean active) {
        if (!attached) {
            return;
        }
        applyLaserEnableState("laser_enable", active);
    }

    private void applyLaserEnableState(String trigger, boolean laserEnableActive) {
        Boolean previous = lastLaserEnableActive;
        if (previous != null && previous == laserEnableActive) {
            return;
        }
        lastLaserEnableActive = laserEnableActive;

        if (previous != null && previous && !laserEnableActive) {
            startGrace(trigger);
        } else if (previous != null && !previous && laserEnableActive) {
            cancelGrace();
            Log.d(TAG, "grace_cancelled laser_enable_on trigger=" + trigger);
        }
    }

    private void startGrace(String trigger) {
        handler.removeCallbacks(graceExpireRunnable);
        graceTrigger = trigger;
        graceEndElapsedMs = SystemClock.elapsedRealtime() + DEFAULT_GRACE_AFTER_LASER_OFF_MS;
        handler.postDelayed(graceExpireRunnable, DEFAULT_GRACE_AFTER_LASER_OFF_MS);
        Log.i(TAG, "grace_start ms=" + DEFAULT_GRACE_AFTER_LASER_OFF_MS + " trigger=" + trigger);
    }

    private void cancelGrace() {
        handler.removeCallbacks(graceExpireRunnable);
        graceEndElapsedMs = 0L;
    }

    private void expireGrace() {
        graceEndElapsedMs = 0L;
        String trigger = graceTrigger;
        Log.i(TAG, "grace_end trigger=" + trigger);
        LaserDetectSamplingCoordinator.getInstance().onLaserOff();
        for (GraceEndedListener listener : listeners) {
            try {
                listener.onLiveInferGraceEnded(trigger);
            } catch (Exception e) {
                Log.w(TAG, "grace_listener_failed", e);
            }
        }
    }
}
