package com.lasercyber.lws.ui.common.queue;

import androidx.annotation.NonNull;

/**
 * One unit of work executed serially by {@link SerialTaskQueue}.
 * <p>
 * Generic beyond dialogs: any side effect that must not overlap with peers can implement this interface.
 */
public interface SerialTask {

    @NonNull
    String id();

    /** Lower values run before higher values; ties preserve enqueue order. */
    int priority();

    /** Whether this task can run now (e.g. host activity available). */
    default boolean isReady() {
        return true;
    }

    /** Optional async preparation; must invoke {@code onPrepared} on the queue thread. */
    default void prepare(@NonNull Runnable onPrepared) {
        onPrepared.run();
    }

    /**
     * @return {@code true} if work started; {@code false} to drop this task and continue the queue
     */
    boolean run(@NonNull Runnable onComplete);
}
