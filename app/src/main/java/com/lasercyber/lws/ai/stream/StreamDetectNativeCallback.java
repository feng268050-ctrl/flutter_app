package com.lasercyber.lws.ai.stream;
import androidx.annotation.NonNull;

/**
 * JNI uplink callback target for {@code StreamDetectPipeline} events.
 */
public interface StreamDetectNativeCallback {
    void onStreamDetectEvent(@NonNull String jsonLine);
}
