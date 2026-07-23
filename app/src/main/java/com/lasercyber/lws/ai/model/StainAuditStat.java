package com.lasercyber.lws.ai.model;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ai.model.StainAuditStatus;
import com.lasercyber.lws.ai.model.StainDetectSource;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.gson.annotations.SerializedName;

/**
 * V1 audit payload written to {@code stat.json} for stain auto-upload tasks.
 */
public final class StainAuditStat {

    @NonNull
    public final StainAuditStatus status;
    @NonNull
    public final String reason;
    @NonNull
    public final String source;
    @SerializedName("primary_result")
    @NonNull
    public final String primaryResult;
    @SerializedName("created_at")
    public final long createdAt;
    @SerializedName("frame_id")
    public final long frameId;
    public final int code;

    public StainAuditStat(@NonNull StainAuditStatus status,
                          @NonNull String reason,
                          @NonNull String source,
                          @NonNull String primaryResult,
                          long createdAt,
                          long frameId,
                          int code) {
        this.status = status;
        this.reason = reason;
        this.source = source;
        this.primaryResult = primaryResult;
        this.createdAt = createdAt;
        this.frameId = frameId;
        this.code = code;
    }

    @NonNull
    public static StainAuditStat fromLiveDetect(@NonNull StainAuditStatus status,
                                         @NonNull OpencvStainDetectResult result,
                                         long frameId) {
        String reason = result.message.isEmpty() ? status.name().toLowerCase() : result.message;
        return new StainAuditStat(
                status,
                reason,
                StainDetectSource.LIVE,
                status.name(),
                result.timestampMs > 0L ? result.timestampMs : System.currentTimeMillis(),
                frameId,
                result.code);
    }
}
