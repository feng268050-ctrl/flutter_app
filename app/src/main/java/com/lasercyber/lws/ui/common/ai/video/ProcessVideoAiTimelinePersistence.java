package com.lasercyber.lws.ui.common.ai.video;

import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

/**
 * Persists {@link ProcessVideoAiTimeline} to disk for replay after the session ends.
 */
public final class ProcessVideoAiTimelinePersistence {

    private static final String TAG = "ProcessVideoAiTimeline";
    private static final int FORMAT_VERSION = 1;

    private ProcessVideoAiTimelinePersistence() {
    }

    public static boolean hasReplayData(@Nullable File timelineFile) {
        if (timelineFile == null || !timelineFile.isFile() || timelineFile.length() <= 0L) {
            return false;
        }
        try {
            JSONObject root = readRoot(timelineFile);
            JSONArray frames = root.optJSONArray("frames");
            return frames != null;
        } catch (Exception e) {
            return false;
        }
    }

    public static void save(
            @NonNull File timelineFile,
            @NonNull ProcessVideoAiTimeline timeline,
            @Nullable String classificationLine) throws Exception {
        File parent = timelineFile.getParentFile();
        if (parent != null && !parent.exists() && !parent.mkdirs()) {
            throw new IllegalStateException("failed to create timeline dir");
        }
        File tmp = new File(timelineFile.getAbsolutePath() + ".tmp");
        JSONObject root = new JSONObject();
        root.put("version", FORMAT_VERSION);
        root.put("cacheKey", timeline.cacheKey);
        root.put("durationMs", timeline.durationMs);
        root.put("sampleIntervalMs", timeline.sampleIntervalMs);
        if (classificationLine != null && !classificationLine.trim().isEmpty()) {
            root.put("classificationLine", classificationLine.trim());
        }
        JSONArray framesArray = new JSONArray();
        for (ProcessVideoAiTimeline.Frame frame : timeline.snapshotFrames()) {
            framesArray.put(frameToJson(frame));
        }
        root.put("frames", framesArray);
        try (BufferedWriter writer = new BufferedWriter(new OutputStreamWriter(
                new FileOutputStream(tmp), StandardCharsets.UTF_8))) {
            writer.write(root.toString());
        }
        if (timelineFile.exists() && !timelineFile.delete()) {
            Log.w(TAG, "failed to delete old timeline file");
        }
        if (!tmp.renameTo(timelineFile)) {
            throw new IllegalStateException("failed to rename timeline tmp");
        }
    }

    @Nullable
    public static LoadedTimeline load(@NonNull File timelineFile) {
        if (!hasReplayData(timelineFile)) {
            return null;
        }
        try {
            JSONObject root = readRoot(timelineFile);
            String cacheKey = root.optString("cacheKey", "");
            long durationMs = root.optLong("durationMs", 0L);
            long sampleIntervalMs = root.optLong("sampleIntervalMs", 0L);
            String classificationLine = root.optString("classificationLine", null);
            if (classificationLine != null && classificationLine.trim().isEmpty()) {
                classificationLine = null;
            }
            ProcessVideoAiTimeline timeline = new ProcessVideoAiTimeline(
                    cacheKey,
                    durationMs,
                    sampleIntervalMs > 0L ? sampleIntervalMs : 200L);
            JSONArray framesArray = root.getJSONArray("frames");
            for (int i = 0; i < framesArray.length(); i++) {
                JSONObject frameJson = framesArray.optJSONObject(i);
                if (frameJson != null) {
                    timeline.addFrame(frameFromJson(frameJson));
                }
            }
            return new LoadedTimeline(timeline, classificationLine);
        } catch (Exception e) {
            Log.w(TAG, "failed to load timeline " + timelineFile.getAbsolutePath(), e);
            return null;
        }
    }

    public static void delete(@Nullable File timelineFile) {
        if (timelineFile != null && timelineFile.exists() && !timelineFile.delete()) {
            Log.w(TAG, "failed to delete timeline " + timelineFile.getAbsolutePath());
        }
    }

    public static final class LoadedTimeline {
        @NonNull
        public final ProcessVideoAiTimeline timeline;
        @Nullable
        public final String classificationLine;

        public LoadedTimeline(@NonNull ProcessVideoAiTimeline timeline, @Nullable String classificationLine) {
            this.timeline = timeline;
            this.classificationLine = classificationLine;
        }
    }

    @NonNull
    private static JSONObject readRoot(@NonNull File timelineFile) throws Exception {
        StringBuilder sb = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(
                new FileInputStream(timelineFile), StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) {
                sb.append(line);
            }
        }
        return new JSONObject(sb.toString());
    }

    @NonNull
    private static JSONObject frameToJson(@NonNull ProcessVideoAiTimeline.Frame frame) throws Exception {
        JSONObject root = new JSONObject();
        root.put("timeMs", frame.timeMs);
        root.put("level", frame.level);
        root.put("status", frame.status);
        root.put("message", frame.message);
        root.put("imageWidth", frame.imageWidth);
        root.put("imageHeight", frame.imageHeight);
        if (frame.temporalSummary) {
            root.put("temporalSummary", true);
        }
        JSONArray boxesArray = new JSONArray();
        for (ProcessVideoAiTimeline.Box box : frame.boxes) {
            JSONObject boxJson = new JSONObject();
            boxJson.put("x1", box.x1);
            boxJson.put("y1", box.y1);
            boxJson.put("x2", box.x2);
            boxJson.put("y2", box.y2);
            boxJson.put("classId", box.classId);
            boxJson.put("label", box.label);
            boxJson.put("score", box.score);
            boxesArray.put(boxJson);
        }
        root.put("boxes", boxesArray);
        return root;
    }

    @NonNull
    private static ProcessVideoAiTimeline.Frame frameFromJson(@NonNull JSONObject root) {
        long timeMs = root.optLong("timeMs", 0L);
        int level = root.optInt("level", -1);
        String status = root.optString("status", "");
        String message = root.optString("message", "");
        int imageWidth = root.optInt("imageWidth", 0);
        int imageHeight = root.optInt("imageHeight", 0);
        List<ProcessVideoAiTimeline.Box> boxes = new ArrayList<>();
        JSONArray boxesArray = root.optJSONArray("boxes");
        if (boxesArray != null) {
            for (int i = 0; i < boxesArray.length(); i++) {
                JSONObject boxJson = boxesArray.optJSONObject(i);
                if (boxJson != null) {
                    boxes.add(new ProcessVideoAiTimeline.Box(
                            (float) boxJson.optDouble("x1", 0.0),
                            (float) boxJson.optDouble("y1", 0.0),
                            (float) boxJson.optDouble("x2", 0.0),
                            (float) boxJson.optDouble("y2", 0.0),
                            boxJson.optInt("classId", -1),
                            boxJson.optString("label", ""),
                            boxJson.optDouble("score", 0.0)));
                }
            }
        }
        ProcessVideoAiTimeline.StainDetect stainDetect = null;
        JSONObject snapshotJson = root.optJSONObject("stainDetect");
        if (snapshotJson != null) {
            stainDetect = new ProcessVideoAiTimeline.StainDetect(
                    snapshotJson.optBoolean("success", false),
                    snapshotJson.optInt("code", -1),
                    snapshotJson.optDouble("targetX", Double.NaN),
                    snapshotJson.optDouble("targetY", Double.NaN),
                    snapshotJson.optString("source", ""));
        }
        boolean temporalSummary = root.optBoolean("temporalSummary", false);
        return new ProcessVideoAiTimeline.Frame(
                timeMs, level, status, message, imageWidth, imageHeight, boxes, stainDetect, temporalSummary);
    }
}
