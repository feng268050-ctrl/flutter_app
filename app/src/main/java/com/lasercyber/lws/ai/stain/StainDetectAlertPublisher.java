package com.lasercyber.lws.ai.stain;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ai.stain.StainDetectAlertMapper;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;

import androidx.annotation.NonNull;

import com.lasercyber.lws.ui.bean.event.LensCheckResultEvent;
import com.lasercyber.lws.ui.common.weld.WeldAlertScope;

import org.greenrobot.eventbus.EventBus;

/**
 * Posts live stain-detect dirty/clean events on the main thread with deduplication.
 */
public final class StainDetectAlertPublisher {

    private static final long SAME_LEVEL_DEDUP_MS = 12_000L;

    private static final StainDetectAlertPublisher INSTANCE = new StainDetectAlertPublisher();

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private int lastPostedBucket = -2;
    private long lastPostedElapsedMs;

    public static StainDetectAlertPublisher getInstance() {
        return INSTANCE;
    }

    public void publishFromWorker(@NonNull OpencvStainDetectResult result) {
        if (!WeldAlertScope.isEligibleFromTopActivity()) {
            return;
        }
        LensCheckResultEvent event = StainDetectAlertMapper.toLensCheckResult(result);
        if (event == null) {
            return;
        }
        mainHandler.post(() -> publishOnMain(event));
    }

    void publishOnMain(@NonNull LensCheckResultEvent event) {
        if (!WeldAlertScope.isEligibleFromTopActivity()) {
            return;
        }
        int bucket = severityBucket(event.getLevel());
        long now = SystemClock.elapsedRealtime();
        if (lastPostedBucket >= 0
                && bucket == lastPostedBucket
                && bucket > 0
                && (now - lastPostedElapsedMs) < SAME_LEVEL_DEDUP_MS) {
            return;
        }
        lastPostedBucket = bucket;
        lastPostedElapsedMs = now;
        EventBus.getDefault().post(event);
    }

    private static int severityBucket(int level) {
        if (level <= 0) {
            return 0;
        }
        if (level == 1) {
            return 1;
        }
        return 2;
    }
}
