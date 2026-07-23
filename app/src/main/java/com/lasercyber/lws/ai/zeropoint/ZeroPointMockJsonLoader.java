package com.lasercyber.lws.ai.zeropoint;
import com.lasercyber.lws.ai.zeropoint.ZeroPointDetectJson;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ui.BuildConfig;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;

/**
 * Staging/debug helper: read zero-point detect JSON from a fixed SD path instead of native infer.
 * Disabled when {@link BuildConfig#RELEASE_CHANNEL} is true.
 */
public final class ZeroPointMockJsonLoader {

    static final String TAG = "ZeroPointMock";
    static final String MOCK_PATH = "/sdcard/lws_debug/zero_point_mock.json";

    @Nullable
    private static volatile Boolean releaseChannelOverride;

    @Nullable
    private static volatile String mockPathOverride;

    private ZeroPointMockJsonLoader() {
    }

    /**
     * @return parsed sample when mock is enabled and file is readable; otherwise null (use native).
     */
    @Nullable
    public static ZeroPointDetectJson.Sample tryLoadSample() {
        return tryLoadSampleFrom(resolveMockPath());
    }

    @Nullable
    static ZeroPointDetectJson.Sample tryLoadSampleFrom(String path) {
        if (isReleaseChannel()) {
            Log.d(TAG, "mock_miss reason=release_channel");
            return null;
        }
        File file = new File(path);
        if (!file.isFile() || !file.canRead()) {
            Log.d(TAG, "mock_miss reason=file_missing path=" + path);
            return null;
        }
        try {
            String json = new String(Files.readAllBytes(file.toPath()), StandardCharsets.UTF_8).trim();
            ZeroPointDetectJson.Sample sample = ZeroPointDetectJson.parse(json);
            if (!sample.ok && sample.code == -1) {
                Log.d(TAG, "mock_miss reason=invalid_json path=" + path);
                return null;
            }
            Log.i(TAG, "mock_hit path=" + path
                    + " ok=" + sample.ok
                    + " code=" + sample.code
                    + " offset_x=" + sample.offsetX
                    + " offset_y=" + sample.offsetY);
            return sample;
        } catch (IOException e) {
            Log.d(TAG, "mock_miss reason=read_failed path=" + path, e);
            return null;
        }
    }

    /** True when staging may use mock (file presence not checked). */
    public static boolean isMockChannelEnabled() {
        return !isReleaseChannel();
    }

    public static boolean mockFileExists() {
        if (isReleaseChannel()) {
            return false;
        }
        File file = new File(resolveMockPath());
        return file.isFile() && file.canRead();
    }

    private static String resolveMockPath() {
        String override = mockPathOverride;
        return override != null ? override : MOCK_PATH;
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
    static void setMockPathOverrideForTest(@Nullable String path) {
        mockPathOverride = path;
    }
}
