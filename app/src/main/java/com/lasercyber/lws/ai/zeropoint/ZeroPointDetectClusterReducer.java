package com.lasercyber.lws.ai.zeropoint;
import androidx.annotation.NonNull;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;

/**
 * Reduces multiple native-valid zero-point samples in one laser-on round via spatial clustering
 * and round-anchor filtering. See {@code zero-point-detect-cluster-filter} OpenSpec.
 */
public final class ZeroPointDetectClusterReducer {

    /** Axis-aligned tolerance: |dx| and |dy| must both be within this value to share a cluster. */
    public static final int CLUSTER_TOLERANCE_PX = 16;
    /** Euclidean distance from the round's first valid sample beyond which later samples are anchor-rejected. */
    public static final int ROUND_ANCHOR_MAX_DEVIATION_PX = 10;

    private ZeroPointDetectClusterReducer() {
    }

    public static final class Observation {
        public final double offsetX;
        public final double offsetY;
        public final int arrivalIndex;

        public Observation(double offsetX, double offsetY, int arrivalIndex) {
            this.offsetX = offsetX;
            this.offsetY = offsetY;
            this.arrivalIndex = arrivalIndex;
        }
    }

    public static final class Result {
        public final boolean hasRepresentative;
        public final double representativeOffsetX;
        public final double representativeOffsetY;
        public final int clusterCount;
        public final int winnerClusterSize;
        public final int anchorRejectedCount;
        public final boolean usedFullSampleClustering;

        private Result(boolean hasRepresentative,
                       double representativeOffsetX,
                       double representativeOffsetY,
                       int clusterCount,
                       int winnerClusterSize,
                       int anchorRejectedCount,
                       boolean usedFullSampleClustering) {
            this.hasRepresentative = hasRepresentative;
            this.representativeOffsetX = representativeOffsetX;
            this.representativeOffsetY = representativeOffsetY;
            this.clusterCount = clusterCount;
            this.winnerClusterSize = winnerClusterSize;
            this.anchorRejectedCount = anchorRejectedCount;
            this.usedFullSampleClustering = usedFullSampleClustering;
        }

        @NonNull
        public static Result empty() {
            return new Result(false, 0.0, 0.0, 0, 0, 0, false);
        }

        @NonNull
        @Override
        public String toString() {
            return String.format(
                    Locale.US,
                    "Result{hasRep=%s, offset=(%.2f,%.2f), clusters=%d, winnerSize=%d,"
                            + " anchorRejected=%d, fullSample=%s}",
                    hasRepresentative,
                    representativeOffsetX,
                    representativeOffsetY,
                    clusterCount,
                    winnerClusterSize,
                    anchorRejectedCount,
                    usedFullSampleClustering);
        }
    }

    @NonNull
    public static Result reduce(@NonNull List<Double> offsetX, @NonNull List<Double> offsetY) {
        if (offsetX.isEmpty() || offsetY.isEmpty()) {
            return Result.empty();
        }
        int count = Math.min(offsetX.size(), offsetY.size());
        List<Observation> observations = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            Double x = offsetX.get(i);
            Double y = offsetY.get(i);
            observations.add(new Observation(
                    x == null ? 0.0 : x,
                    y == null ? 0.0 : y,
                    i));
        }
        return reduceObservations(observations);
    }

    @NonNull
    public static Result reduceObservations(@NonNull List<Observation> observations) {
        if (observations.isEmpty()) {
            return Result.empty();
        }
        ClusterPick fullPick = pickWinningCluster(observations);
        List<Observation> anchorFiltered = filterByRoundAnchor(observations);
        int anchorRejectedCount = observations.size() - anchorFiltered.size();
        ClusterPick filteredPick = pickWinningCluster(anchorFiltered);
        boolean useFull = fullPick.winnerClusterSize > filteredPick.winnerClusterSize;
        ClusterPick chosen = useFull ? fullPick : filteredPick;
        if (!chosen.hasRepresentative()) {
            return Result.empty();
        }
        Observation representative = chosen.representative;
        return new Result(
                true,
                representative.offsetX,
                representative.offsetY,
                chosen.clusterCount,
                chosen.winnerClusterSize,
                anchorRejectedCount,
                useFull);
    }

    @NonNull
    private static List<Observation> filterByRoundAnchor(@NonNull List<Observation> observations) {
        Observation anchor = observations.get(0);
        List<Observation> kept = new ArrayList<>();
        for (int i = 0; i < observations.size(); i++) {
            Observation sample = observations.get(i);
            if (i == 0 || distance(sample, anchor) <= ROUND_ANCHOR_MAX_DEVIATION_PX) {
                kept.add(sample);
            }
        }
        return kept;
    }

    @NonNull
    private static ClusterPick pickWinningCluster(@NonNull List<Observation> observations) {
        if (observations.isEmpty()) {
            return ClusterPick.empty();
        }
        int n = observations.size();
        UnionFind unionFind = new UnionFind(n);
        for (int i = 0; i < n; i++) {
            Observation a = observations.get(i);
            for (int j = i + 1; j < n; j++) {
                Observation b = observations.get(j);
                if (sameCluster(a, b)) {
                    unionFind.union(i, j);
                }
            }
        }
        List<List<Observation>> clusters = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            int root = unionFind.find(i);
            while (clusters.size() <= root) {
                clusters.add(new ArrayList<>());
            }
            clusters.get(root).add(observations.get(i));
        }
        List<List<Observation>> nonEmpty = new ArrayList<>();
        for (List<Observation> cluster : clusters) {
            if (!cluster.isEmpty()) {
                nonEmpty.add(cluster);
            }
        }
        if (nonEmpty.isEmpty()) {
            return ClusterPick.empty();
        }
        nonEmpty.sort(Comparator
                .comparingInt((List<Observation> cluster) -> cluster.size()).reversed()
                .thenComparing(ZeroPointDetectClusterReducer::clusterMeanKey));
        List<Observation> winner = nonEmpty.get(0);
        Observation representative = pickRepresentative(winner);
        return new ClusterPick(nonEmpty.size(), winner.size(), representative);
    }

    @NonNull
    private static String clusterMeanKey(@NonNull List<Observation> cluster) {
        double meanX = 0.0;
        double meanY = 0.0;
        for (Observation sample : cluster) {
            meanX += sample.offsetX;
            meanY += sample.offsetY;
        }
        meanX /= cluster.size();
        meanY /= cluster.size();
        return String.format(Locale.US, "%.6f,%.6f", meanX, meanY);
    }

    @NonNull
    private static Observation pickRepresentative(@NonNull List<Observation> cluster) {
        double centerX = 0.0;
        double centerY = 0.0;
        for (Observation sample : cluster) {
            centerX += sample.offsetX;
            centerY += sample.offsetY;
        }
        centerX /= cluster.size();
        centerY /= cluster.size();
        Observation best = cluster.get(0);
        double bestDistance = distance(best, centerX, centerY);
        for (int i = 1; i < cluster.size(); i++) {
            Observation candidate = cluster.get(i);
            double candidateDistance = distance(candidate, centerX, centerY);
            if (candidateDistance < bestDistance - 1e-9) {
                best = candidate;
                bestDistance = candidateDistance;
            } else if (Math.abs(candidateDistance - bestDistance) <= 1e-9
                    && candidate.arrivalIndex < best.arrivalIndex) {
                best = candidate;
            }
        }
        return best;
    }

    private static boolean sameCluster(@NonNull Observation a, @NonNull Observation b) {
        return Math.abs(a.offsetX - b.offsetX) <= CLUSTER_TOLERANCE_PX
                && Math.abs(a.offsetY - b.offsetY) <= CLUSTER_TOLERANCE_PX;
    }

    private static double distance(@NonNull Observation a, @NonNull Observation b) {
        return distance(a, b.offsetX, b.offsetY);
    }

    private static double distance(@NonNull Observation sample, double x, double y) {
        double dx = sample.offsetX - x;
        double dy = sample.offsetY - y;
        return Math.hypot(dx, dy);
    }

    private static final class ClusterPick {
        final int clusterCount;
        final int winnerClusterSize;
        @NonNull
        final Observation representative;

        private ClusterPick(int clusterCount, int winnerClusterSize, @NonNull Observation representative) {
            this.clusterCount = clusterCount;
            this.winnerClusterSize = winnerClusterSize;
            this.representative = representative;
        }

        static ClusterPick empty() {
            return new ClusterPick(0, 0, new Observation(0.0, 0.0, 0));
        }

        boolean hasRepresentative() {
            return winnerClusterSize > 0;
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
