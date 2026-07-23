package com.lasercyber.lws.ui.common.handler;

import android.content.Context;
import android.content.SharedPreferences;
import android.text.TextUtils;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ai.sampling.AiFrameSamplingInterval;
import com.lasercyber.lws.ui.BuildConfig;
import com.lasercyber.lws.ui.bean.entity.vo.ProcessParamsVideoVo;
import com.lasercyber.lws.ui.common.constant.VideoUploadStatus;

import org.json.JSONObject;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Locale;

public final class AiVisionInferenceUploadStateStore {
    private static final String TAG = "AiVisionUploadState";
    public static final long INFERENCE_SAMPLE_INTERVAL_MS =
            AiFrameSamplingInterval.AI_VISION_PROCESS_VIDEO.getIntervalMs();
    private static final String PREFS_AI_VISION = "ai_vision";
    private static final String PREF_INFERENCE_UPLOAD_STATE_PREFIX = "inference_upload_state_";

    private AiVisionInferenceUploadStateStore() {
    }

    @NonNull
    public static SharedPreferences prefs(@NonNull Context context) {
        return context.getApplicationContext()
                .getSharedPreferences(PREFS_AI_VISION, Context.MODE_PRIVATE);
    }

    @Nullable
    public static File resolveSourceVideo(@Nullable ProcessParamsVideoVo processVideo) {
        if (processVideo == null || TextUtils.isEmpty(processVideo.getVideoPath())) {
            return null;
        }
        File file = new File(processVideo.getVideoPath().trim()).getAbsoluteFile();
        return file.exists() && file.length() > 0L ? file : null;
    }

    @NonNull
    public static String buildInferenceCacheKey(@NonNull ProcessParamsVideoVo processVideo,
                                                @NonNull File videoFile) {
        return buildInferenceCacheKey(processVideo, videoFile, "");
    }

    @NonNull
    public static String buildInferenceCacheKey(@NonNull ProcessParamsVideoVo processVideo,
                                                @NonNull File videoFile,
                                                @Nullable String extraSalt) {
        String appVersion = BuildConfig.VERSION_NAME != null ? BuildConfig.VERSION_NAME : "";
        String raw = processVideo.getId()
                + "|" + processVideo.getVideoId()
                + "|" + videoFile.getAbsolutePath()
                + "|" + videoFile.length()
                + "|" + videoFile.lastModified()
                + "|" + appVersion
                + "|" + INFERENCE_SAMPLE_INTERVAL_MS
                + "|" + (extraSalt == null ? "" : extraSalt.trim());
        return sha256(raw);
    }

    public static boolean isInferenceVideoUploaded(@NonNull Context context,
                                                   @Nullable ProcessParamsVideoVo processVideo) {
        File sourceVideo = resolveSourceVideo(processVideo);
        if (processVideo == null || sourceVideo == null) {
            return false;
        }
        String cacheKey = buildInferenceCacheKey(processVideo, sourceVideo);
        return read(context, cacheKey).uploadStatus == VideoUploadStatus.VIDEO_UPLOADED;
    }

    @NonNull
    public static State read(@Nullable Context context, @Nullable String cacheKey) {
        if (context == null || TextUtils.isEmpty(cacheKey)) {
            return State.empty();
        }
        String raw = prefs(context).getString(PREF_INFERENCE_UPLOAD_STATE_PREFIX + cacheKey, null);
        if (TextUtils.isEmpty(raw)) {
            return State.empty();
        }
        try {
            JSONObject json = new JSONObject(raw);
            return new State(
                    json.optInt("uploadStatus", VideoUploadStatus.NOT_INITIATED),
                    json.optInt("uploadProgress", 0),
                    json.optString("videoUrl", ""),
                    json.optString("objectKey", ""));
        } catch (Exception e) {
            Log.w(TAG, "ignore broken AI Vision inference upload state cacheKey=" + cacheKey, e);
            return State.empty();
        }
    }

    public static void persist(@Nullable Context context, @Nullable String cacheKey, @Nullable State state) {
        if (context == null || TextUtils.isEmpty(cacheKey) || state == null) {
            return;
        }
        try {
            JSONObject json = new JSONObject();
            json.put("uploadStatus", state.uploadStatus);
            json.put("uploadProgress", state.uploadProgress);
            json.put("videoUrl", state.videoUrl);
            json.put("objectKey", state.objectKey);
            prefs(context).edit()
                    .putString(PREF_INFERENCE_UPLOAD_STATE_PREFIX + cacheKey, json.toString())
                    .apply();
        } catch (Exception e) {
            Log.w(TAG, "failed to persist AI Vision inference upload state", e);
        }
    }

    private static String sha256(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] bytes = digest.digest(value.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder(bytes.length * 2);
            for (byte b : bytes) {
                sb.append(String.format(Locale.US, "%02x", b & 0xff));
            }
            return sb.toString();
        } catch (Exception e) {
            return String.valueOf(value.hashCode());
        }
    }

    public static final class State {
        public final int uploadStatus;
        public final int uploadProgress;
        @NonNull
        public final String videoUrl;
        @NonNull
        public final String objectKey;

        public State(int uploadStatus,
                     int uploadProgress,
                     @Nullable String videoUrl,
                     @Nullable String objectKey) {
            this.uploadStatus = uploadStatus;
            this.uploadProgress = uploadProgress;
            this.videoUrl = videoUrl == null ? "" : videoUrl;
            this.objectKey = objectKey == null ? "" : objectKey;
        }

        @NonNull
        public static State empty() {
            return new State(VideoUploadStatus.NOT_INITIATED, 0, "", "");
        }
    }
}
