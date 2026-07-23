package com.lasercyber.lws.ai.stain;
import com.lasercyber.lws.ai.model.AiStainDetectResult;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ai.model.StainDetectSource;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.bean.event.LensCheckResultEvent;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Maps live {@link OpencvStainDetectResult} to {@link LensCheckResultEvent} for lens heavy/clean alerts.
 */
public final class StainDetectAlertMapper {

    private static final Pattern SOURCE_JSON_PATTERN =
            Pattern.compile("\"source\"\\s*:\\s*\"([^\"]+)\"");

    private StainDetectAlertMapper() {
    }

    @Nullable
    public static LensCheckResultEvent toLensCheckResult(@NonNull OpencvStainDetectResult result) {
        if (!result.success) {
            return null;
        }
        if (result.hasTarget()) {
            return new LensCheckResultEvent(2, "STAIN_HEAVY", buildMessageJson(StainDetectSource.LIVE, null));
        }
        return new LensCheckResultEvent(0, "CLEAN", buildMessageJson(StainDetectSource.LIVE, null));
    }

    /**
     * Maps offline process-video temporal summary to {@link LensCheckResultEvent} for AI Vision alerts.
     */
    @Nullable
    public static LensCheckResultEvent toOfflineSummaryLensCheckResult(
            @NonNull AiStainDetectResult summary) {
        if (!summary.success) {
            return null;
        }
        if (summary.boxes != null && !summary.boxes.isEmpty()) {
            return new LensCheckResultEvent(
                    2,
                    "STAIN_HEAVY",
                    buildMessageJson(StainDetectSource.OFFLINE, null));
        }
        return new LensCheckResultEvent(
                0,
                "CLEAN",
                buildMessageJson(StainDetectSource.OFFLINE, null));
    }

    /**
     * Offline stain detect (process video) must not drive deferred weld L001 alerts.
     */
    public static boolean isOfflineStainDetectMessage(@Nullable String rawMessage) {
        String source = readJsonSource(rawMessage);
        if (source == null || source.isEmpty()) {
            return false;
        }
        return StainDetectSource.OFFLINE.equals(source);
    }

    @NonNull
    static String buildMessageJson(@NonNull String source, @Nullable String humanMessage) {
        if (humanMessage == null || humanMessage.isEmpty()) {
            return "{\"source\":\"" + source + "\"}";
        }
        return "{\"source\":\"" + source + "\",\"message\":\"" + humanMessage + "\"}";
    }

    @Nullable
    private static String readJsonSource(@Nullable String rawMessage) {
        if (rawMessage == null || rawMessage.trim().isEmpty()) {
            return null;
        }
        String message = rawMessage.trim();
        if (!message.startsWith("{")) {
            return null;
        }
        Matcher matcher = SOURCE_JSON_PATTERN.matcher(message);
        if (!matcher.find()) {
            return null;
        }
        String source = matcher.group(1);
        return source == null || source.isEmpty() ? null : source;
    }
}
