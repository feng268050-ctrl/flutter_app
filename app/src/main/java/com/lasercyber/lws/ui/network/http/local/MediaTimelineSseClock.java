package com.lasercyber.lws.ui.network.http.local;

import androidx.annotation.NonNull;

/** Process video: {@code timestampMs} is ms on the source recording timeline from 0. */
final class MediaTimelineSseClock implements SseTimestampClock {

    @NonNull
    private final MediaPositionMs mediaPosition;

    MediaTimelineSseClock(@NonNull MediaPositionMs mediaPosition) {
        this.mediaPosition = mediaPosition;
    }

    @Override
    public long connectIdleTimestampMs() {
        return 0L;
    }

    @Override
    public long periodicIdleTimestampMs(@NonNull AiInferenceSseHub.SseSubscriber subscriber) {
        return Math.max(0L, mediaPosition.getMediaPositionMs());
    }

    @Override
    public long startTimestampMs(@NonNull AiInferenceSseHub.SseSubscriber subscriber, boolean replay) {
        return 0L;
    }

    @Override
    public long stopTimestampMs(@NonNull AiInferenceSseHub.SseSubscriber subscriber, long contextMs) {
        return Math.max(0L, contextMs);
    }

    @Override
    public long runningTimestampMs(@NonNull AiInferenceSseHub.SseSubscriber subscriber, long contextMs) {
        return Math.max(0L, contextMs);
    }
}
