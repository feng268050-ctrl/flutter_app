package com.lasercyber.lws.ai.model;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Parses OpenCV lens_det JNI summary JSON and {@code target.json} payloads.
 */
public final class OpencvStainDetectJson {

    private OpencvStainDetectJson() {
    }

    @NonNull
    public static Summary parseSummary(@Nullable String json) {
        if (json == null || json.trim().isEmpty()) {
            return Summary.failure(-1, "empty summary json");
        }
        try {
            JsonElement parsed = new JsonParser().parse(json.trim());
            JsonObject root = parsed.getAsJsonObject();
            boolean ok = root.has("ok") && root.get("ok").getAsBoolean();
            int code = root.has("code") ? root.get("code").getAsInt() : (ok ? 0 : -1);
            String reason = root.has("reason") ? root.get("reason").getAsString() : "";
            List<String> files = new ArrayList<>();
            if (root.has("files") && root.get("files").isJsonArray()) {
                JsonArray array = root.getAsJsonArray("files");
                for (JsonElement item : array) {
                    if (item != null && item.isJsonPrimitive()) {
                        files.add(item.getAsString());
                    }
                }
            }
            String frameKind = root.has("frame_kind") ? root.get("frame_kind").getAsString() : "red";
            return new Summary(ok, code, reason, files, frameKind);
        } catch (RuntimeException e) {
            return Summary.failure(-1, "invalid summary json");
        }
    }

    /**
     * Resolves {@code fileName} from summary {@code files[]} entries.
     * Tries each path as-is first, then relative to optional {@code searchRoots}
     * (e.g. {@code files/lens_guard}) when the native daemon wrote a cwd-relative path.
     */
    @Nullable
    public static File findWrittenFile(@NonNull Summary summary,
                                       @NonNull String fileName,
                                       @Nullable File... searchRoots) {
        for (String path : summary.files) {
            if (path == null || path.isEmpty()) {
                continue;
            }
            if (!(path.endsWith("/" + fileName) || path.endsWith(File.separator + fileName)
                    || path.equals(fileName) || path.endsWith(fileName))) {
                continue;
            }
            File direct = new File(path);
            if (direct.isFile()) {
                return direct;
            }
            if (direct.isAbsolute()) {
                continue;
            }
            if (searchRoots == null) {
                continue;
            }
            for (File root : searchRoots) {
                if (root == null) {
                    continue;
                }
                File underRoot = new File(root, path);
                if (underRoot.isFile()) {
                    return underRoot;
                }
            }
        }
        return null;
    }

    /** Backward-compatible overload without search roots. */
    @Nullable
    public static File findWrittenFile(@NonNull Summary summary, @NonNull String fileName) {
        return findWrittenFile(summary, fileName, (File[]) null);
    }

    @NonNull
    public static Target parseTargetFile(@NonNull File file) {
        try {
            String raw = new String(Files.readAllBytes(file.toPath()), StandardCharsets.UTF_8);
            JsonElement parsed = new JsonParser().parse(raw.trim());
            JsonObject root = parsed.getAsJsonObject();
            String name = root.has("name") ? root.get("name").getAsString() : "target";
            double x = root.has("x") ? root.get("x").getAsDouble() : Double.NaN;
            double y = root.has("y") ? root.get("y").getAsDouble() : Double.NaN;
            int bboxX = root.has("bbox_x") ? root.get("bbox_x").getAsInt() : 0;
            int bboxY = root.has("bbox_y") ? root.get("bbox_y").getAsInt() : 0;
            int width = root.has("w") ? root.get("w").getAsInt() : 0;
            int height = root.has("h") ? root.get("h").getAsInt() : 0;
            return new Target(name, x, y, bboxX, bboxY, width, height);
        } catch (IOException | RuntimeException e) {
            return Target.invalid();
        }
    }

    public static final class Summary {
        public final boolean ok;
        public final int code;
        @NonNull
        public final String reason;
        @NonNull
        public final List<String> files;
        @NonNull
        public final String frameKind;

        Summary(boolean ok, int code, @Nullable String reason, @Nullable List<String> files,
                @Nullable String frameKind) {
            this.ok = ok;
            this.code = code;
            this.reason = reason == null ? "" : reason;
            this.files = files == null ? Collections.emptyList() : Collections.unmodifiableList(files);
            this.frameKind = frameKind == null || frameKind.isEmpty() ? "red" : frameKind;
        }

        @NonNull
        static Summary failure(int code, @NonNull String reason) {
            return new Summary(false, code, reason, Collections.emptyList(), "red");
        }
    }

    public static final class Target {
        public final String name;
        public final double x;
        public final double y;
        public final int bboxX;
        public final int bboxY;
        public final int width;
        public final int height;

        Target(@Nullable String name,
               double x,
               double y,
               int bboxX,
               int bboxY,
               int width,
               int height) {
            this.name = name == null ? "" : name;
            this.x = x;
            this.y = y;
            this.bboxX = bboxX;
            this.bboxY = bboxY;
            this.width = width;
            this.height = height;
        }

        public boolean isValid() {
            return Double.isFinite(x) && Double.isFinite(y);
        }

        @NonNull
        static Target invalid() {
            return new Target("", Double.NaN, Double.NaN, 0, 0, 0, 0);
        }
    }
}
