package com.lasercyber.lws.ui.common.handler;

import android.content.Context;
import android.os.Handler;

import androidx.annotation.Nullable;

/**
 * Single-flight coordinator for {@link MonitorProcessVideoListUploadRunner} used from the Videos list
 * UI and from WebSocket {@code command.upload_video} so cancel/replace semantics stay consistent.
 */
public final class MonitorListForegroundUploadCoordinator {

    private static final MonitorListForegroundUploadCoordinator INSTANCE = new MonitorListForegroundUploadCoordinator();

    public static MonitorListForegroundUploadCoordinator get() {
        return INSTANCE;
    }

    private MonitorListForegroundUploadCoordinator() {
    }

    @Nullable
    private volatile MonitorProcessVideoListUploadRunner activeRunner;

    /**
     * Cancels any previous runner, then starts {@code runner} for {@code rowId}. Listener callbacks
     * run per {@link MonitorProcessVideoListUploadRunner#runForeground}.
     */
    public synchronized void start(Context app, long rowId, Handler mainHandler,
            MonitorProcessVideoListUploadRunner.Listener listener) {
        MonitorProcessVideoListUploadRunner previous = activeRunner;
        if (previous != null) {
            previous.cancel();
        }
        MonitorProcessVideoListUploadRunner runner = new MonitorProcessVideoListUploadRunner();
        activeRunner = runner;
        MonitorProcessVideoListUploadRunner.Listener wrapped = new MonitorProcessVideoListUploadRunner.Listener() {
            @Override
            public void onMetadataPhaseStarted() {
                listener.onMetadataPhaseStarted();
            }

            @Override
            public void onVideoProgress(int percent0to100, @Nullable String detail) {
                listener.onVideoProgress(percent0to100, detail);
            }

            @Override
            public void onFinishedSuccess(@Nullable String videoPublicUrl) {
                clearIfSame(runner);
                listener.onFinishedSuccess(videoPublicUrl);
            }

            @Override
            public void onFinishedError(@Nullable String message) {
                clearIfSame(runner);
                listener.onFinishedError(message);
            }
        };
        runner.runForeground(app, rowId, mainHandler, wrapped);
    }

    private synchronized void clearIfSame(MonitorProcessVideoListUploadRunner runner) {
        if (activeRunner == runner) {
            activeRunner = null;
        }
    }

    public synchronized void cancel() {
        MonitorProcessVideoListUploadRunner r = activeRunner;
        if (r != null) {
            r.cancel();
        }
    }
}
