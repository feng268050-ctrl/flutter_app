package com.lasercyber.lws.ai.stain;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import androidx.annotation.NonNull;

import com.lasercyber.lws.ui.common.ai.video.ProcessVideoAiTimeline;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/**
 * Temporal reduction of process-video stain detect boxes: cluster per-frame detections and keep
 * only boxes that appear on enough distinct frames to filter single-frame false positives.
 */
public final class LensStainBoxTemporalReducer {

    /** Expand each box by this many pixels per edge when testing overlap with another box. */
    public static final int BOX_CLUSTER_TOLERANCE_PX = 10;
    /** Keep a cluster when distinct-frame count is {@code >=} this value. */
    public static final int MIN_PERSISTENT_OCCURRENCE_COUNT = 3;

    private LensStainBoxTemporalReducer() {
    }

    public static final class PersistentBox {
        public final float x1;
        public final float y1;
        public final float x2;
        public final float y2;
        @NonNull
        public final String label;

        public PersistentBox(float x1, float y1, float x2, float y2, @NonNull String label) {
            this.x1 = x1;
            this.y1 = y1;
            this.x2 = x2;
            this.y2 = y2;
            this.label = label;
        }

        @NonNull
        public ProcessVideoAiTimeline.Box toTimelineBox() {
            return new ProcessVideoAiTimeline.Box(x1, y1, x2, y2, 0, label, 1.0);
        }
    }

    public static final class Result {
        @NonNull
        public final List<PersistentBox> boxes;
        public final int imageWidth;
        public final int imageHeight;

        public Result(@NonNull List<PersistentBox> boxes, int imageWidth, int imageHeight) {
            this.boxes = boxes;
            this.imageWidth = imageWidth;
            this.imageHeight = imageHeight;
        }

        public boolean hasContamination() {
            return !boxes.isEmpty();
        }
    }

    @NonNull
    public static Result reduce(@NonNull List<ProcessVideoAiTimeline.Frame> frames) {
        if (frames.isEmpty()) {
            return new Result(Collections.emptyList(), 0, 0);
        }
        List<ObservedBox> observed = collectObservedBoxes(frames);
        int imageWidth = referenceWidth(frames);
        int imageHeight = referenceHeight(frames);
        if (observed.isEmpty()) {
            return new Result(Collections.emptyList(), imageWidth, imageHeight);
        }
        List<PersistentBox> persistent = clusterPersistentBoxes(observed);
        return new Result(persistent, imageWidth, imageHeight);
    }

    @NonNull
    private static List<ObservedBox> collectObservedBoxes(@NonNull List<ProcessVideoAiTimeline.Frame> frames) {
        List<ObservedBox> observed = new ArrayList<>();
        for (int frameIndex = 0; frameIndex < frames.size(); frameIndex++) {
            ProcessVideoAiTimeline.Frame frame = frames.get(frameIndex);
            if (frame.temporalSummary) {
                continue;
            }
            if (!frame.boxes.isEmpty()) {
                for (ProcessVideoAiTimeline.Box box : frame.boxes) {
                    observed.add(new ObservedBox(
                            frameIndex,
                            frame.timeMs,
                            box.x1,
                            box.y1,
                            box.x2,
                            box.y2,
                            box.label));
                }
                continue;
            }
            if (frame.stainDetect != null && frame.stainDetect.hasTarget()) {
                float cx = (float) frame.stainDetect.targetX;
                float cy = (float) frame.stainDetect.targetY;
                float r = OpencvStainDetectResult.MARKER_RADIUS_PX;
                observed.add(new ObservedBox(
                        frameIndex,
                        frame.timeMs,
                        cx - r,
                        cy - r,
                        cx + r,
                        cy + r,
                        "contamination"));
            }
        }
        return observed;
    }

    @NonNull
    private static List<PersistentBox> clusterPersistentBoxes(@NonNull List<ObservedBox> observed) {
        int n = observed.size();
        UnionFind unionFind = new UnionFind(n);
        for (int i = 0; i < n; i++) {
            ObservedBox a = observed.get(i);
            for (int j = i + 1; j < n; j++) {
                ObservedBox b = observed.get(j);
                if (expandedRectsIntersect(
                        a.x1, a.y1, a.x2, a.y2,
                        b.x1, b.y1, b.x2, b.y2,
                        BOX_CLUSTER_TOLERANCE_PX)) {
                    unionFind.union(i, j);
                }
            }
        }
        List<List<ObservedBox>> clusters = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            int root = unionFind.find(i);
            while (clusters.size() <= root) {
                clusters.add(new ArrayList<>());
            }
            clusters.get(root).add(observed.get(i));
        }
        List<PersistentBox> persistent = new ArrayList<>();
        for (List<ObservedBox> cluster : clusters) {
            if (cluster.isEmpty()) {
                continue;
            }
            Set<Integer> distinctFrames = new HashSet<>();
            for (ObservedBox box : cluster) {
                distinctFrames.add(box.frameIndex);
            }
            if (distinctFrames.size() < MIN_PERSISTENT_OCCURRENCE_COUNT) {
                continue;
            }
            persistent.add(toCanonicalBox(cluster));
        }
        return persistent;
    }

    @NonNull
    private static PersistentBox toCanonicalBox(@NonNull List<ObservedBox> cluster) {
        float[] x1s = new float[cluster.size()];
        float[] y1s = new float[cluster.size()];
        float[] x2s = new float[cluster.size()];
        float[] y2s = new float[cluster.size()];
        String label = "contamination";
        for (int i = 0; i < cluster.size(); i++) {
            ObservedBox box = cluster.get(i);
            x1s[i] = box.x1;
            y1s[i] = box.y1;
            x2s[i] = box.x2;
            y2s[i] = box.y2;
            if (!box.label.trim().isEmpty()) {
                label = box.label;
            }
        }
        return new PersistentBox(
                median(x1s),
                median(y1s),
                median(x2s),
                median(y2s),
                label);
    }

    static boolean expandedRectsIntersect(float x1, float y1, float x2, float y2,
                                          float ox1, float oy1, float ox2, float oy2,
                                          int tolerancePx) {
        float left = x1 - tolerancePx;
        float top = y1 - tolerancePx;
        float right = x2 + tolerancePx;
        float bottom = y2 + tolerancePx;
        float oLeft = ox1 - tolerancePx;
        float oTop = oy1 - tolerancePx;
        float oRight = ox2 + tolerancePx;
        float oBottom = oy2 + tolerancePx;
        return left <= oRight && right >= oLeft && top <= oBottom && bottom >= oTop;
    }

    private static float median(@NonNull float[] values) {
        float[] copy = Arrays.copyOf(values, values.length);
        Arrays.sort(copy);
        int n = copy.length;
        if (n == 0) {
            return 0f;
        }
        if ((n & 1) == 1) {
            return copy[n / 2];
        }
        return (copy[n / 2 - 1] + copy[n / 2]) * 0.5f;
    }

    private static int referenceWidth(@NonNull List<ProcessVideoAiTimeline.Frame> frames) {
        for (int i = frames.size() - 1; i >= 0; i--) {
            ProcessVideoAiTimeline.Frame frame = frames.get(i);
            if (!frame.temporalSummary && frame.imageWidth > 0) {
                return frame.imageWidth;
            }
        }
        return 0;
    }

    private static int referenceHeight(@NonNull List<ProcessVideoAiTimeline.Frame> frames) {
        for (int i = frames.size() - 1; i >= 0; i--) {
            ProcessVideoAiTimeline.Frame frame = frames.get(i);
            if (!frame.temporalSummary && frame.imageHeight > 0) {
                return frame.imageHeight;
            }
        }
        return 0;
    }

    private static final class ObservedBox {
        final int frameIndex;
        final long timeMs;
        final float x1;
        final float y1;
        final float x2;
        final float y2;
        @NonNull
        final String label;

        ObservedBox(int frameIndex,
                    long timeMs,
                    float x1,
                    float y1,
                    float x2,
                    float y2,
                    @NonNull String label) {
            this.frameIndex = frameIndex;
            this.timeMs = timeMs;
            this.x1 = x1;
            this.y1 = y1;
            this.x2 = x2;
            this.y2 = y2;
            this.label = label;
        }

        @NonNull
        @Override
        public String toString() {
            return String.format(Locale.US, "ObservedBox{frame=%d, t=%d, [%.1f,%.1f,%.1f,%.1f]}",
                    frameIndex, timeMs, x1, y1, x2, y2);
        }
    }

    private static final class UnionFind {
        private final int[] parent;

        UnionFind(int size) {
            parent = new int[size];
            for (int i = 0; i < size; i++) {
                parent[i] = i;
            }
        }

        int find(int x) {
            if (parent[x] != x) {
                parent[x] = find(parent[x]);
            }
            return parent[x];
        }

        void union(int a, int b) {
            int rootA = find(a);
            int rootB = find(b);
            if (rootA != rootB) {
                parent[rootA] = rootB;
            }
        }
    }
}
