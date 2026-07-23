package com.lasercyber.lws.ai.zeropoint;
import com.lasercyber.lws.ai.NativeBridge;
import com.lasercyber.lws.ai.model.OpencvDetectCodes;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.google.gson.JsonElement;

/**
 * Parses {@link NativeBridge#nativeOpencvZeroPointDetectFromNv12} JSON payloads.
 */
public final class ZeroPointDetectJson {

    public static final String REASON_SPOT_SIZE_BELOW_MIN = OpencvDetectCodes.REASON_SPOT_SIZE_BELOW_MIN;
    public static final String REASON_SPOT_SIZE_ABOVE_MAX = OpencvDetectCodes.REASON_SPOT_SIZE_ABOVE_MAX;

    private ZeroPointDetectJson() {
    }

    @NonNull
    public static Sample parse(@NonNull String json) {
        try {
            JsonElement parsed = new JsonParser().parse(json);
            JsonObject root = parsed.getAsJsonObject();
            boolean ok = root.has("ok") && root.get("ok").getAsBoolean();
            int code = root.has("code") ? root.get("code").getAsInt() : OpencvDetectCodes.INVALID_HANDLE.code();
            String reason = root.has("reason") ? root.get("reason").getAsString() : "";
            double offsetX = root.has("offset_x") ? root.get("offset_x").getAsDouble() : 0.0;
            double offsetY = root.has("offset_y") ? root.get("offset_y").getAsDouble() : 0.0;
            return new Sample(ok, code, reason, offsetX, offsetY);
        } catch (RuntimeException e) {
            return new Sample(false, OpencvDetectCodes.INVALID_HANDLE.code(), "", 0.0, 0.0);
        }
    }

    public static final class Sample {
        public final boolean ok;
        public final int code;
        @NonNull
        public final String reason;
        public final double offsetX;
        public final double offsetY;

        Sample(boolean ok, int code, @NonNull String reason, double offsetX, double offsetY) {
            this.ok = ok;
            this.code = code;
            this.reason = reason;
            this.offsetX = offsetX;
            this.offsetY = offsetY;
        }

        @NonNull
        public OpencvDetectCodes detectCode() {
            return OpencvDetectCodes.fromCode(code);
        }

        public boolean isSpotSizeRejection() {
            return detectCode().isSpotSizeRejection(reason);
        }
    }
}
