package com.lasercyber.lws.ai.model;
/**
 * Capability-level source tags on stain-detect inference results (wire / timeline / SSE running rows).
 * <ul>
 *   <li>{@link #LIVE} — real-time PR1 stream (AI Vision preview or laser-on background path)</li>
 *   <li>{@link #OFFLINE} — AI Vision process-video file inference</li>
 * </ul>
 */
public final class StainDetectSource {

    public static final String LIVE = "live_stain_detect";
    public static final String OFFLINE = "offline_stain_detect";

    private StainDetectSource() {
    }
}
