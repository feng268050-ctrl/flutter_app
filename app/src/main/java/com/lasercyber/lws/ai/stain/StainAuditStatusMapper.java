package com.lasercyber.lws.ai.stain;
import com.lasercyber.lws.ai.model.OpencvDetectCodes;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ai.model.StainAuditStatus;
import androidx.annotation.NonNull;

/**
 * Maps Live weld {@link OpencvStainDetectResult} to audit status and upload eligibility.
 */
public final class StainAuditStatusMapper {

    public static final class Mapped {
        @NonNull
        public final StainAuditStatus status;
        public final boolean uploadEligible;

        Mapped(@NonNull StainAuditStatus status, boolean uploadEligible) {
            this.status = status;
            this.uploadEligible = uploadEligible;
        }
    }

    private StainAuditStatusMapper() {
    }

    @NonNull
    public static Mapped mapLiveWeld(@NonNull OpencvStainDetectResult result) {
        if (result.code == OpencvDetectCodes.DETECT_FAILED.code()) {
            return new Mapped(StainAuditStatus.DETECT_FAILED, true);
        }
        if (result.code == OpencvDetectCodes.FRAME_REJECTED.code()) {
            return new Mapped(StainAuditStatus.INTERNAL_FILTERED, false);
        }
        if (result.success && result.code == 0) {
            return new Mapped(StainAuditStatus.STAIN_CONFIRMED, false);
        }
        return new Mapped(StainAuditStatus.INTERNAL_FILTERED, false);
    }
}
