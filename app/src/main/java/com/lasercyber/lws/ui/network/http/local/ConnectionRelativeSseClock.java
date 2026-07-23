package com.lasercyber.lws.ui.network.http.local;

import android.os.SystemClock;

import androidx.annotation.NonNull;

/** Live camera: {@code timestampMs} is ms since the SSE connection was established. */
final class ConnectionRelativeSseClock implements SseTimestampClock {

  @Override
  public long connectIdleTimestampMs() {
    return 0L;
  }

  @Override
  public long periodicIdleTimestampMs(@NonNull AiInferenceSseHub.SseSubscriber subscriber) {
    return subscriber.connectionTimelineMs(SystemClock.elapsedRealtime());
  }

  @Override
  public long startTimestampMs(@NonNull AiInferenceSseHub.SseSubscriber subscriber, boolean replay) {
    return replay ? 0L : subscriber.connectionTimelineMs(SystemClock.elapsedRealtime());
  }

  @Override
  public long stopTimestampMs(@NonNull AiInferenceSseHub.SseSubscriber subscriber, long contextMs) {
    return subscriber.connectionTimelineMs(contextMs);
  }

  @Override
  public long runningTimestampMs(@NonNull AiInferenceSseHub.SseSubscriber subscriber, long contextMs) {
    return subscriber.connectionTimelineMs(contextMs);
  }
}
