package com.lasercyber.lws.ai.zeropoint;
import com.lasercyber.lws.ai.model.OpencvDetectCodes;
import com.lasercyber.lws.ai.zeropoint.ZeroPointDetectJson;
import com.lasercyber.lws.ai.zeropoint.ZeroPointOverlaySnapshot;
import com.lasercyber.lws.ai.zeropoint.ZeroPointOverlayState;
import com.lasercyber.lws.ai.zeropoint.ZeroPointRoiConfig;
import android.content.Context;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

/**
 * Builds overlay snapshots when zero_point returns {@code code=0}.
 */
public final class ZeroPointOverlayPublisher {

    private ZeroPointOverlayPublisher() {
    }

    public static void publishSuccess(@Nullable Context context,
                                      double offsetX,
                                      double offsetY,
                                      int frameWidth,
                                      int frameHeight) {
        if (context == null || frameWidth <= 0 || frameHeight <= 0) {
            return;
        }
        ZeroPointRoiConfig roi = ZeroPointRoiConfig.load(context);
        if (roi == null) {
            return;
        }
        ZeroPointRoiConfig.ScaledReference ref = roi.scaleReferenceToFrame(frameWidth, frameHeight);
        ZeroPointOverlaySnapshot snapshot = new ZeroPointOverlaySnapshot(
                frameWidth,
                frameHeight,
                ref.x,
                ref.y,
                offsetX,
                offsetY);
        ZeroPointOverlayState.getInstance().update(snapshot);
    }

    public static void publishFromSample(@Nullable Context context,
                                         @NonNull ZeroPointDetectJson.Sample sample,
                                         int frameWidth,
                                         int frameHeight) {
        if (!sample.ok || sample.code != OpencvDetectCodes.OK.code()) {
            return;
        }
        int[] size = resolveFrameSize(context, frameWidth, frameHeight);
        publishSuccess(context, sample.offsetX, sample.offsetY, size[0], size[1]);
    }

    @NonNull
    private static int[] resolveFrameSize(@Nullable Context context, int frameWidth, int frameHeight) {
        if (frameWidth > 0 && frameHeight > 0) {
            return new int[]{frameWidth, frameHeight};
        }
        ZeroPointRoiConfig roi = ZeroPointRoiConfig.load(context);
        if (roi != null && roi.sourceWidth > 0 && roi.sourceHeight > 0) {
            return new int[]{roi.sourceWidth, roi.sourceHeight};
        }
        return new int[]{0, 0};
    }
}
