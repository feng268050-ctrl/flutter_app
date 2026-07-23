package com.lasercyber.lws.ui.common.camera;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.Nullable;

/**
 * Process-wide 1 Hz ICMP ping probe via {@link CameraPingHealth} on the main looper.
 */
public final class CameraPingHealthScheduler {

    private static final long INTERVAL_MS = 1000L;

    private static final CameraPingHealthScheduler INSTANCE = new CameraPingHealthScheduler();

    private final Handler handler = new Handler(Looper.getMainLooper());
    private final Runnable tick = new Runnable() {
        @Override
        public void run() {
            if (!started) {
                return;
            }
            CameraPingHealth.getInstance().probeAsync();
            handler.postDelayed(this, INTERVAL_MS);
        }
    };

    private boolean started;

    private CameraPingHealthScheduler() {
    }

    public static CameraPingHealthScheduler getInstance() {
        return INSTANCE;
    }

    public synchronized void start(@Nullable Context context) {
        if (context == null) {
            return;
        }
        if (started) {
            return;
        }
        started = true;
        handler.removeCallbacks(tick);
        handler.post(tick);
    }

    public synchronized void stop() {
        started = false;
        handler.removeCallbacks(tick);
    }

    /** Visible for unit tests. */
    static boolean isStartedForTest() {
        return INSTANCE.started;
    }
}
