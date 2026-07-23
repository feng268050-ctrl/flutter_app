package com.lasercyber.lws.ui.network.http.local;

import androidx.annotation.NonNull;

/**
 * Resolves {@code timestampMs} on AI inference SSE events.
 */
interface SseTimestampClock {

  /** First {@code idle} on connect — always media/connection t=0. */
  long connectIdleTimestampMs();

  /** Periodic {@code idle} while the connection stays open. */
  long periodicIdleTimestampMs(@NonNull AiInferenceSseHub.SseSubscriber subscriber);

  /** {@code start} event timestamp for one subscriber. */
  long startTimestampMs(@NonNull AiInferenceSseHub.SseSubscriber subscriber, boolean replay);

  /** {@code stop} event timestamp; {@code contextMs} is session-end media position or elapsed realtime. */
  long stopTimestampMs(@NonNull AiInferenceSseHub.SseSubscriber subscriber, long contextMs);

  /** {@code running} sample timestamp; {@code contextMs} is media sample ms or publish elapsed realtime. */
  long runningTimestampMs(@NonNull AiInferenceSseHub.SseSubscriber subscriber, long contextMs);
}
