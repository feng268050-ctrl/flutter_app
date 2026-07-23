package com.lasercyber.lws.ai.stain;
import com.lasercyber.lws.ai.model.OpencvDetectCodes;
import com.lasercyber.lws.ai.model.OpencvStainDetectJson;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.io.File;

/**
 * Maps lens_det native summary JSON and {@code target.json} into {@link OpencvStainDetectResult}.
 */
public final class OpencvStainDetectResultMapper {

    private OpencvStainDetectResultMapper() {
    }

    @NonNull
    public static OpencvStainDetectResult fromNativeSummary(@Nullable String summaryJson,
                                                        int imageWidth,
                                                        int imageHeight,
                                                        long timestampMs,
                                                        @Nullable String source) {
        OpencvStainDetectJson.Summary summary = OpencvStainDetectJson.parseSummary(summaryJson);
        if (!summary.ok) {
            OpencvDetectCodes detectCode = OpencvDetectCodes.fromCode(summary.code);
            String message = summary.reason.isEmpty()
                    ? detectCode.name().toLowerCase()
                    : summary.reason;
            return appError(summary.code, message, timestampMs, source);
        }
        if (summary.files.isEmpty()) {
            return appError(summary.code, "lens_det ok but files[] empty", timestampMs, source);
        }
        File targetFile = new File(summary.files.get(0));
        OpencvStainDetectJson.Target target = OpencvStainDetectJson.parseTargetFile(targetFile);
        if (!target.isValid()) {
            return appError(OpencvDetectCodes.IO_ERROR.code(),
                    "invalid target.json at " + targetFile.getAbsolutePath(), timestampMs, source);
        }
        return new OpencvStainDetectResult(
                true,
                summary.code,
                target.name.isEmpty() ? "target" : target.name,
                target.x,
                target.y,
                target.bboxX,
                target.bboxY,
                target.width,
                target.height,
                imageWidth,
                imageHeight,
                source,
                timestampMs,
                summary.frameKind);
    }

    @NonNull
    public static OpencvStainDetectResult appError(int code,
                                               @NonNull String message,
                                               long timestampMs,
                                               @Nullable String source) {
        return new OpencvStainDetectResult(
                false,
                code,
                message,
                Double.NaN,
                Double.NaN,
                0,
                0,
                source,
                timestampMs);
    }
}
