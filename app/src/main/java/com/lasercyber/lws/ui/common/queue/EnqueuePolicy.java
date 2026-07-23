package com.lasercyber.lws.ui.common.queue;

/** How {@link SerialTaskQueue} handles duplicate {@link SerialTask#id()} values. */
public enum EnqueuePolicy {
    /** Ignore the enqueue when the same id is already pending or running. */
    SKIP_IF_PENDING,
    /** Replace a pending entry with the same id; also releases a stale active slot for that id. */
    REPLACE_PENDING,
    /** Always append, even when the same id is already queued. */
    ALLOW_DUPLICATE
}
