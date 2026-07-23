package com.lasercyber.lws.ai.zeropoint;
import com.lasercyber.lws.ai.zeropoint.ZeroPointPendingCorrectionStore;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.lasercyber.lws.ui.BuildConfig;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;

/**
 * Staging/debug helper: inject a pending weld zero-point result from a fixed SD path so
 * Manual Auto method 1 can be exercised without a laser OFF→ON→OFF cycle.
 * Disabled when {@link BuildConfig#RELEASE_CHANNEL} is true.
 */
public final class ZeroPointPendingJsonLoader {

    static final String TAG = "ZeroPointPending";
    static final String PENDING_PATH = "/sdcard/lws_debug/zero_point_pending.json";
    private static final long DEBUG_EVENT_ID = -1L;

    @Nullable
    private static volatile Boolean releaseChannelOverride;

    @Nullable
    private static volatile String pendingPathOverride;

    private ZeroPointPendingJsonLoader() {
    }

    /**
     * Reads pending JSON from disk and stores it in {@link ZeroPointPendingCorrectionStore}.
     *
     * @return true when a valid pending result was loaded; otherwise false.
     */
    public static boolean tryHydratePendingFromFile() {
        return tryHydratePendingFrom(resolvePendingPath());
    }

    static boolean tryHydratePendingFrom(String path) {
        if (isReleaseChannel()) {
            Log.d(TAG, "pending_miss reason=release_channel");
            return false;
        }
        File file = new File(path);
        if (!file.isFile() || !file.canRead()) {
            Log.d(TAG, "pending_miss reason=file_missing path=" + path);
            return false;
        }
        try {
            String json = new String(Files.readAllBytes(file.toPath()), StandardCharsets.UTF_8).trim();
            PendingPayload payload = parsePendingPayload(json);
            if (payload == null) {
                Log.d(TAG, "pending_miss reason=invalid_json path=" + path);
                return false;
            }
            ZeroPointPendingCorrectionStore.getInstance().setWeldResult(
                    DEBUG_EVENT_ID,
                    payload.validSamples,
                    payload.offsetX,
                    payload.offsetY);
            if (!file.delete()) {
                Log.w(TAG, "pending_hydrated delete_failed path=" + path);
            }
            Log.i(TAG, "pending_hydrated path=" + path
                    + " valid_samples=" + payload.validSamples
                    + " offset_x=" + payload.offsetX
                    + " offset_y=" + payload.offsetY);
            return true;
        } catch (IOException e) {
            Log.d(TAG, "pending_miss reason=read_failed path=" + path, e);
            return false;
        }
    }

    public static boolean pendingFileExists() {
        if (isReleaseChannel()) {
            return false;
        }
        File file = new File(resolvePendingPath());
        return file.isFile() && file.canRead();
    }

    @Nullable
    static PendingPayload parsePendingPayload(@Nullable String json) {
        if (json == null || json.isEmpty()) {
            return null;
        }
        try {
            JsonElement parsed = new JsonParser().parse(json);
            JsonObject root = parsed.getAsJsonObject();
            if (!root.has("offset_x") || !root.has("offset_y")) {
                return null;
            }
            int validSamples = root.has("valid_samples")
                    ? root.get("valid_samples").getAsInt()
                    : 1;
            if (validSamples <= 0) {
                return null;
            }
            double offsetX = root.get("offset_x").getAsDouble();
            double offsetY = root.get("offset_y").getAsDouble();
            return new PendingPayload(validSamples, offsetX, offsetY);
        } catch (RuntimeException e) {
            return null;
        }
    }

    static final class PendingPayload {
        final int validSamples;
        final double offsetX;
        final double offsetY;

        PendingPayload(int validSamples, double offsetX, double offsetY) {
            this.validSamples = validSamples;
            this.offsetX = offsetX;
            this.offsetY = offsetY;
        }
    }

    private static String resolvePendingPath() {
        String override = pendingPathOverride;
        return override != null ? override : PENDING_PATH;
    }

    private static boolean isReleaseChannel() {
        Boolean override = releaseChannelOverride;
        if (override != null) {
            return override;
        }
        return BuildConfig.RELEASE_CHANNEL;
    }

    @VisibleForTesting
    static void setReleaseChannelOverrideForTest(@Nullable Boolean releaseChannel) {
        releaseChannelOverride = releaseChannel;
    }

    @VisibleForTesting
    static void setPendingPathOverrideForTest(@Nullable String path) {
        pendingPathOverride = path;
    }
}
