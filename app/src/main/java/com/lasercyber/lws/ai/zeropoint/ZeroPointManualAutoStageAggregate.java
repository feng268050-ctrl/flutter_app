package com.lasercyber.lws.ai.zeropoint;

import android.util.Log;

import androidx.annotation.NonNull;

import java.util.List;

/**
 * Cluster-reduced offset aggregate for one manual-auto correction stage
 * (online 500 ms, offline 200 ms, offline 100 ms, or pending JSON).
 */
final class ZeroPointManualAutoStageAggregate {

    private static final String TAG = "ZeroPointManualAuto";

    @NonNull
    final String stageName;
    final int validSamples;
    final double meanOffsetX;
    final double meanOffsetY;

    private ZeroPointManualAutoStageAggregate(@NonNull String stageName,
                                              int validSamples,
                                              double meanOffsetX,
                                              double meanOffsetY) {
        this.stageName = stageName;
        this.validSamples = validSamples;
        this.meanOffsetX = meanOffsetX;
        this.meanOffsetY = meanOffsetY;
    }

    static ZeroPointManualAutoStageAggregate empty(@NonNull String stageName) {
        return new ZeroPointManualAutoStageAggregate(stageName, 0, 0.0, 0.0);
    }

    static ZeroPointManualAutoStageAggregate from(@NonNull String stageName,
                                                  @NonNull List<Double> offsetX,
                                                  @NonNull List<Double> offsetY) {
        ZeroPointDetectClusterReducer.Result reduced =
                ZeroPointDetectClusterReducer.reduce(offsetX, offsetY);
        if (!reduced.hasRepresentative) {
            return empty(stageName);
        }
        Log.i(TAG, "manual_auto cluster_reduce stage=" + stageName
                + " rawSamples=" + Math.min(offsetX.size(), offsetY.size())
                + " clusterCount=" + reduced.clusterCount
                + " winnerClusterSize=" + reduced.winnerClusterSize
                + " anchorRejected=" + reduced.anchorRejectedCount
                + " usedFullSampleClustering=" + reduced.usedFullSampleClustering
                + " representativeOffsetX=" + reduced.representativeOffsetX
                + " representativeOffsetY=" + reduced.representativeOffsetY);
        return new ZeroPointManualAutoStageAggregate(
                stageName,
                reduced.winnerClusterSize,
                reduced.representativeOffsetX,
                reduced.representativeOffsetY);
    }

    static ZeroPointManualAutoStageAggregate from(
            @NonNull ZeroPointPendingCorrectionStore.PendingCorrection pendingCorrection) {
        return new ZeroPointManualAutoStageAggregate(
                pendingCorrection.stageName,
                pendingCorrection.validSamples,
                pendingCorrection.meanOffsetX,
                pendingCorrection.meanOffsetY);
    }

    boolean hasValidSamples() {
        return validSamples > 0;
    }
}
