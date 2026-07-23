package com.lasercyber.lws.ai.zeropoint;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ai.Nv12FrameUtil;
import com.lasercyber.lws.ai.bridge.AssetDeployer;
import com.lasercyber.lws.ai.daemon.AiDaemonSupervisor;

import java.io.File;
import java.nio.ByteBuffer;

/**
 * Zero-point detect session facade. Offline NV12 infer goes through {@link AiDaemonSupervisor};
 * ROI bootstrap still deploys {@code zero_point_roi.json} into lens_guard for the daemon cwd.
 */
public final class ZeroPointDetectNativeSession {

    private static final String TAG = "ZeroPointNative";
    private static final String ZERO_POINT_ROI_ASSET = "zero_point_roi.json";
    private static final String ZERO_POINT_ROI_FILE = "zero_point_roi.json";

    private boolean roiReady;
    @Nullable
    private String zpRoiJsonPath;

    public void ensureReady(@Nullable Context context) {
        if (context == null) {
            return;
        }
        if (zpRoiJsonPath == null) {
            zpRoiJsonPath = bootstrapRoiJson(context, ZERO_POINT_ROI_ASSET, ZERO_POINT_ROI_FILE);
            roiReady = zpRoiJsonPath != null;
        }
    }

    public void destroy() {
        roiReady = false;
        zpRoiJsonPath = null;
    }

    public boolean isDetectorReady() {
        return roiReady && AiDaemonSupervisor.getInstance().isReady();
    }

    @NonNull
    public DetectOutcome detect(int targetMode,
                                @NonNull ByteBuffer nv12,
                                int width,
                                int height) {
        ZeroPointDetectJson.Sample mock = ZeroPointMockJsonLoader.tryLoadSample();
        if (mock != null) {
            return DetectOutcome.fromZeroPoint(mock);
        }
        if (!AiDaemonSupervisor.getInstance().isReady()) {
            Log.w(TAG, "detect skipped: AI daemon not ready");
            return DetectOutcome.fromZeroPoint(ZeroPointDetectJson.parse("{}"));
        }
        try {
            Nv12FrameUtil.Payload payload = Nv12FrameUtil.preparePayload(nv12, width, height);
            String json = AiDaemonSupervisor.getInstance().offlineZeroPointFromNv12(
                    payload.buffer, payload.width, payload.height, targetMode);
            if (json == null) {
                Log.w(TAG, "offline_infer_zero_point_nv12 failed mode="
                        + ZeroPointDetectTargetMode.logName(targetMode));
                return DetectOutcome.fromZeroPoint(ZeroPointDetectJson.parse("{}"));
            }
            return DetectOutcome.fromZeroPoint(ZeroPointDetectJson.parse(json));
        } catch (Throwable t) {
            Log.w(TAG, "offlineZeroPointFromNv12 failed mode="
                    + ZeroPointDetectTargetMode.logName(targetMode), t);
            return DetectOutcome.fromZeroPoint(ZeroPointDetectJson.parse("{}"));
        }
    }

    @Nullable
    private static String bootstrapRoiJson(@NonNull Context context,
                                             @NonNull String asset,
                                             @NonNull String runtimeFile) {
        try {
            AssetDeployer paths = AssetDeployer.deploy(context);
            File roiFile = new File(paths.getProjectRoot(), runtimeFile);
            AssetDeployer.deployAssetIfChanged(context, asset, roiFile);
            return roiFile.getAbsolutePath();
        } catch (Throwable t) {
            Log.e(TAG, "roi bootstrap failed asset=" + asset, t);
            return null;
        }
    }

    public static final class DetectOutcome {
        @NonNull
        public final ZeroPointDetectJson.Sample sample;

        private DetectOutcome(@NonNull ZeroPointDetectJson.Sample sample) {
            this.sample = sample;
        }

        @NonNull
        static DetectOutcome fromZeroPoint(@NonNull ZeroPointDetectJson.Sample sample) {
            return new DetectOutcome(sample);
        }
    }
}
