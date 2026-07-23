package com.lasercyber.lws.ai.engine;
import androidx.annotation.Nullable;

/**
 * Small helper for "hold-forward" behavior: keep the last good value while work is in-flight.
 */
public final class AiHoldForwardStore<T> {

    @Nullable
    private volatile T value;

    @Nullable
    public T get() {
        return value;
    }

    public void set(@Nullable T value) {
        this.value = value;
    }
}

