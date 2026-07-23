package com.lasercyber.lws.ui.network.http.local;

import androidx.annotation.NonNull;

import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.lasercyber.lws.ai.model.AiStainDetectResult;
import com.lasercyber.lws.ai.stain.AiStainDetectResultMapper;
import com.lasercyber.lws.ai.model.StainDetectSource;
import com.lasercyber.lws.ui.common.ai.video.ProcessVideoAiTimeline;

/**
 * JSON payload for {@code GET /v1/videos/:video_id/ai/replay}.
 * Each frame uses the same running-row shape as {@code GET /v1/videos/:id/ai} SSE.
 */
public final class ProcessVideoAiReplayJson {

    static final String REPLAY_VERSION = "1";
    private static final Gson GSON = new Gson();
    private static final JsonParser JSON_PARSER = new JsonParser();

    private ProcessVideoAiReplayJson() {
    }

    @NonNull
    public static JsonObject replayDataObject(@NonNull String videoId,
                                              long generatedAtMs,
                                              @NonNull ProcessVideoAiTimeline timeline) {
        JsonObject root = new JsonObject();
        root.addProperty("version", REPLAY_VERSION);
        root.addProperty("videoId", videoId);
        root.addProperty("generatedAtMs", generatedAtMs);
        JsonArray frames = new JsonArray();
        for (ProcessVideoAiTimeline.Frame frame : timeline.snapshotFrames()) {
            frames.add(runningFrameObject(frame));
        }
        root.add("frames", frames);
        return root;
    }

    @NonNull
    static JsonObject runningFrameObject(@NonNull ProcessVideoAiTimeline.Frame frame) {
        AiStainDetectResult result = AiStainDetectResultMapper.fromTimelineFrame(
                frame, StainDetectSource.OFFLINE);
        String json = AiInferenceSseJson.runningData(result, frame.timeMs, null);
        return JSON_PARSER.parse(json).getAsJsonObject();
    }

    @NonNull
    public static String replayData(@NonNull String videoId,
                                    long generatedAtMs,
                                    @NonNull ProcessVideoAiTimeline timeline) {
        return GSON.toJson(replayDataObject(videoId, generatedAtMs, timeline));
    }
}
