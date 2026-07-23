package com.lasercyber.lws.ai.sampling;
/**
 * Minimum interval between live AI inference frames per usage context (code constants only).
 * Offline one-shot {@code inferFromJpg} uses separate timing — not defined here.
 */
public enum AiFrameSamplingInterval {

    /** Live PR1 sub-stream while welding (Quick / Engineer). */
    LIVE_WELD(500L),

    /** AI Vision: live preview sampled from TextureView. */
    AI_VISION_LIVE(500L),

    /** AI Vision: selected process video (real-time file inference + HTTP /ai). */
    AI_VISION_PROCESS_VIDEO(500L),

    /** Laser-on zero-point detect (PR1-driven while laser ON). */
    ZERO_POINT_ON_LASER(500L),

    /** Live PR1 zero_point + lens_det after {@code code=-5} (FRAME_REJECTED). */
    FRAME_REJECTED_BURST(100L);

    private final long intervalMs;

    AiFrameSamplingInterval(long intervalMs) {
        this.intervalMs = intervalMs;
    }

    public long getIntervalMs() {
        return intervalMs;
    }
}
