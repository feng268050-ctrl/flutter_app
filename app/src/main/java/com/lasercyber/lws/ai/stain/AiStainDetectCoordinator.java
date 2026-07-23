package com.lasercyber.lws.ai.stain;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Single in-flight gate for unified RKNN stain infer ({@code rknnStainDetectFromJpg} / {@code rknnStainDetectFromNv12} / {@code rknnStainDetectFromRgb}).
 */
public final class AiStainDetectCoordinator {

    private final AtomicBoolean inFlight = new AtomicBoolean(false);

    public boolean tryBegin() {
        return inFlight.compareAndSet(false, true);
    }

    public void end() {
        inFlight.set(false);
    }

    public boolean isInFlight() {
        return inFlight.get();
    }
}
