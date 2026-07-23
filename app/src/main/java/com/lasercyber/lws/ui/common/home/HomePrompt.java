package com.lasercyber.lws.ui.common.home;

import androidx.annotation.NonNull;

import com.lasercyber.lws.ui.MainActivity;

/** One home-screen startup prompt enqueued on {@link com.lasercyber.lws.ui.component.dialog.AutoDialogQueue}. */
public interface HomePrompt {

    @NonNull
    String id();

    /** Lower values are shown first. */
    int order();

    boolean isEligible(@NonNull MainActivity activity);

    /**
     * Optional async preparation (e.g. network). Must invoke {@code onPrepared} on the main thread.
     */
    default void prepare(@NonNull MainActivity activity, @NonNull Runnable onPrepared) {
        onPrepared.run();
    }

    /**
     * @return {@code true} if the prompt was shown or async presentation started;
     *         {@code false} to skip and try the next queued prompt
     */
    boolean show(@NonNull MainActivity activity, @NonNull Runnable onComplete);

    /** Called after {@code onComplete} when this prompt should not re-enter the queue this session. */
    default void markConsumedForSession(@NonNull MainActivity activity) {
    }
}
