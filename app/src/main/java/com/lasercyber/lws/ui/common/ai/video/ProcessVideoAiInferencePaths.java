package com.lasercyber.lws.ui.common.ai.video;

import android.content.Context;
import android.text.TextUtils;

import androidx.annotation.NonNull;

import com.lasercyber.lws.ui.bean.entity.vo.ProcessParamsVideoVo;
import com.lasercyber.lws.ui.common.handler.AiVisionInferenceUploadStateStore;

import java.io.File;

/**
 * Canonical on-disk paths for AI Vision process-video inference artifacts.
 */
public final class ProcessVideoAiInferencePaths {

    private ProcessVideoAiInferencePaths() {
    }

    @NonNull
    public static String cacheKey(@NonNull ProcessParamsVideoVo processVideo, @NonNull File sourceFile) {
        return AiVisionInferenceUploadStateStore.buildInferenceCacheKey(processVideo, sourceFile);
    }

    @NonNull
    public static String cacheKey(@NonNull ProcessParamsVideoVo processVideo,
                                 @NonNull File sourceFile,
                                 @NonNull String extraSalt) {
        return AiVisionInferenceUploadStateStore.buildInferenceCacheKey(processVideo, sourceFile, extraSalt);
    }

    @NonNull
    public static File inferenceMp4(@NonNull Context context,
                                  @NonNull ProcessParamsVideoVo processVideo,
                                  @NonNull String cacheKey) {
        String owner = ownerSegment(processVideo);
        return new File(context.getFilesDir(),
                "ai-vision-inference-videos/" + owner
                        + "/ai-vision-inference-" + owner + "-" + cacheKey + ".mp4");
    }

    @NonNull
    public static File inferenceMp4Tmp(@NonNull File mp4) {
        return new File(mp4.getAbsolutePath() + ".tmp");
    }

    @NonNull
    public static File inferenceTimelineJson(@NonNull Context context,
                                           @NonNull ProcessParamsVideoVo processVideo,
                                           @NonNull String cacheKey) {
        String owner = ownerSegment(processVideo);
        return new File(context.getFilesDir(),
                "ai-vision-inference-videos/" + owner
                        + "/ai-vision-inference-" + owner + "-" + cacheKey + ".timeline.json");
    }

    @NonNull
    private static String ownerSegment(@NonNull ProcessParamsVideoVo processVideo) {
        if (processVideo.getId() > 0) {
            return String.valueOf(processVideo.getId());
        }
        String videoId = processVideo.getVideoId();
        return TextUtils.isEmpty(videoId) ? "unknown" : videoId;
    }
}
