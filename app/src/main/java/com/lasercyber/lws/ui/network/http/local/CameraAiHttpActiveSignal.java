package com.lasercyber.lws.ui.network.http.local;

/**
 * Tracks live PR1 inference streaming and {@code GET /v1/camera/ai} SSE subscriber count.
 */
public final class CameraAiHttpActiveSignal {

    private static volatile boolean livePr1InferenceStreaming;
    private static volatile boolean aiVisionLiveInferActive;
    private static volatile int cameraAiHttpSubscriberCount;

    private CameraAiHttpActiveSignal() {
    }

    public static void setLivePr1InferenceStreaming(boolean streaming) {
        livePr1InferenceStreaming = streaming;
    }

    public static boolean isLivePr1InferenceStreaming() {
        return livePr1InferenceStreaming;
    }

    public static void setAiVisionLiveInferActive(boolean active) {
        aiVisionLiveInferActive = active;
    }

    public static boolean isAiVisionLiveInferActive() {
        return aiVisionLiveInferActive;
    }

    public static void setCameraAiHttpSubscriberCount(int count) {
        cameraAiHttpSubscriberCount = Math.max(0, count);
    }

    public static int getCameraAiHttpSubscriberCount() {
        return cameraAiHttpSubscriberCount;
    }
}
