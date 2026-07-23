package com.lasercyber.lws.ui.common.home;

import android.util.Log;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.MainActivity;
import com.lasercyber.lws.ui.common.boot.BootSelfCheckCoordinator;
import com.lasercyber.lws.ui.common.config.AppRuntimeEnvironment;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.utils.WifiStatusUtils;
import com.lasercyber.lws.ui.component.dialog.AutoDialogQueue;

import java.lang.ref.WeakReference;
import java.util.HashSet;
import java.util.Set;

/**
 * Scans home-screen startup conditions and enqueues matching prompts on the global {@link AutoDialogQueue}.
 */
public final class HomePromptQueue {

    private static final String TAG = LogTAGConstant.MainActivity;
    private static final long HOME_PROMPT_TRANSITION_DEFER_MS = 350L;
    private static final HomePromptQueue INSTANCE = new HomePromptQueue();

    private static final HomePrompt[] PROMPTS = {
            new WifiInitHomePrompt(),
            new RemoteLockHomePrompt(),
            new BundledFirmwareHomePrompt(),
            new BindDeviceHomePrompt(),
            new AutoOtaUpdateHomePrompt(),
    };

    @Nullable
    private WeakReference<MainActivity> hostRef;
    private final Set<String> consumedSessionIds = new HashSet<>();
    private boolean firstHomeResumeSeen;

    private HomePromptQueue() {
    }

    public static HomePromptQueue get() {
        return INSTANCE;
    }

    /** {@code true} after the first {@link MainActivity} home {@code onResume} this app process. */
    boolean isFirstHomeResumeSeen() {
        return firstHomeResumeSeen;
    }

    public void onHomeResume(@NonNull MainActivity activity) {
        if (!firstHomeResumeSeen) {
            firstHomeResumeSeen = true;
            if (WifiStatusUtils.hasUsableWifiConnection(activity.getApplicationContext())) {
                AppRuntimeEnvironment.markWifiInitializationCompleted(activity);
            }
        }
        hostRef = new WeakReference<>(activity);
        if (BootSelfCheckCoordinator.isCompletedInProcess()) {
            scheduleRefreshAfterTransition(activity);
            return;
        }
        BootSelfCheckCoordinator.startWhenHomeEntered(activity, () -> {
            MainActivity host = hostRef != null ? hostRef.get() : null;
            if (host != null && !host.isFinishing() && !host.isDestroyed()) {
                scheduleRefreshAfterTransition(host);
            }
        });
    }

    public void onHomePause() {
        consumedSessionIds.remove(RemoteLockHomePrompt.ID);
        RemoteLockHomePrompt.resetResumeCycle();
    }

    public void onHostDestroyed(@NonNull MainActivity activity) {
        if (hostRef != null && hostRef.get() == activity) {
            hostRef = null;
        }
    }

    public void requestRefresh(@NonNull MainActivity activity) {
        onHomeResume(activity);
    }

    public void onWifiOnboardingCompleted(@NonNull MainActivity activity) {
        consumedSessionIds.remove(WifiInitHomePrompt.ID);
        onHomeResume(activity);
    }

    /**
     * Waits for the window transition to finish before scanning prompts so backdrop capture and
     * dialog attach do not block the activity close animation when returning from Settings / Monitor.
     */
    private void scheduleRefreshAfterTransition(@NonNull MainActivity activity) {
        View decor = activity.getWindow().getDecorView();
        Runnable work = () -> {
            if (activity.isFinishing() || activity.isDestroyed()) {
                return;
            }
            refreshAndEnqueue(activity);
        };
        if (!decor.isAttachedToWindow()) {
            decor.post(work);
            return;
        }
        decor.postDelayed(work, HOME_PROMPT_TRANSITION_DEFER_MS);
    }

    private void refreshAndEnqueue(@NonNull MainActivity activity) {
        if (!BootSelfCheckCoordinator.isCompletedInProcess()) {
            Log.d(TAG, "defer home prompts until boot self-check completes");
            return;
        }
        for (HomePrompt prompt : PROMPTS) {
            if (consumedSessionIds.contains(prompt.id())) {
                continue;
            }
            prompt.prepare(activity, () -> {
                MainActivity host = hostRef != null ? hostRef.get() : null;
                if (host != null && !host.isFinishing() && !host.isDestroyed()) {
                    maybeEnqueue(host, prompt);
                }
            });
            maybeEnqueue(activity, prompt);
        }
        AutoDialogQueue.get().scheduleDrain();
    }

    private void maybeEnqueue(@NonNull MainActivity activity, @NonNull HomePrompt prompt) {
        if (consumedSessionIds.contains(prompt.id()) || !prompt.isEligible(activity)) {
            return;
        }
        String taskId = homeTaskId(prompt.id());
        AutoDialogQueue.get().enqueueFrostDialog(
                taskId,
                prompt.order(),
                onDismissed -> {
                    boolean shown = prompt.show(activity, () -> {
                        prompt.markConsumedForSession(activity);
                        if (!prompt.isEligible(activity)) {
                            consumedSessionIds.add(prompt.id());
                        }
                        onDismissed.run();
                        MainActivity host = hostRef != null ? hostRef.get() : null;
                        if (host != null && !host.isFinishing() && !host.isDestroyed()) {
                            refreshAndEnqueue(host);
                        }
                    });
                    if (shown) {
                        Log.d(TAG, "enqueued home prompt showing: " + prompt.id());
                    }
                    return shown;
                });
    }

    @NonNull
    private static String homeTaskId(@NonNull String promptId) {
        return "home:" + promptId;
    }
}
