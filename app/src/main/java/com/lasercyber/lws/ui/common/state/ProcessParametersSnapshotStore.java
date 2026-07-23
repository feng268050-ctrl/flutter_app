package com.lasercyber.lws.ui.common.state;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;

import java.util.concurrent.atomic.AtomicReference;

/**
 * Keeps a real-time in-memory snapshot of process parameters for outbound status messages.
 */
public final class ProcessParametersSnapshotStore {
    private static final AtomicReference<ProcessParametersData> SNAPSHOT = new AtomicReference<>();

    private ProcessParametersSnapshotStore() {
    }

    public static void update(@Nullable ProcessParametersData latest) {
        SNAPSHOT.set(cloneOrNull(latest));
    }

    @Nullable
    public static ProcessParametersData getSnapshot() {
        return cloneOrNull(SNAPSHOT.get());
    }

    private static ProcessParametersData cloneOrNull(@Nullable ProcessParametersData source) {
        return source == null ? null : source.clone();
    }
}
