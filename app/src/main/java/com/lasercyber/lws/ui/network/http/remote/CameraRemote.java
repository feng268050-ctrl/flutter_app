package com.lasercyber.lws.ui.network.http.remote;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.blankj.utilcode.util.GsonUtils;
import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.bean.http.CameraDeviceInfo;
import com.lasercyber.lws.ui.bean.http.CameraTime;
import com.lasercyber.lws.ui.bean.result.CameraResult;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.config.CameraConfig;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.network.http.RequestApi;

import java.util.Objects;

import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;

public class CameraRemote {
    private static final String TAG = LogTAGConstant.CameraRemote;

    /** Shown when camera deviceinfo is unavailable or has no {@code appVersion}. */
    public static final String CAMERA_VERSION_UNAVAILABLE = "-";

    private static final String DEVICE_INFO_PATH = "System/deviceinfo";

    /**
     * 同步摄像头的时间
     */
    public static void updateCameraTime() {
        Boolean cameraAsyncTime = MemoryCacheManager.getInstance().getSerializable(CacheKey.CAMERA_ASYNC_TIME);
        if (Objects.equals(cameraAsyncTime, Boolean.TRUE)) {
            Log.d(TAG, "updateCameraTime: 当前已经同步过时间");
            return;
        }
        String url = CameraConfig.getBaseCameraAppUrl() + "System/time";
        RequestApi.getCameraRemoteApi().updateCameraTime(
                        CameraConfig.basicAuthorization(), CameraTime.createNow(), url)
                .enqueue(new Callback<>() {
                             @Override
                             public void onResponse(Call<CameraResult> call, Response<CameraResult> response) {
                                 Log.d(TAG, "updateCameraTime: 更新摄像头时间成功:" + response);
                                 MemoryCacheManager.getInstance().putSerializableNoNotice(CacheKey.CAMERA_ASYNC_TIME, Boolean.TRUE);
                             }

                             @Override
                             public void onFailure(Call<CameraResult> call, Throwable t) {
                                 Log.e(TAG, "onFailure: 摄像头时间更新失败", t);
                             }
                         }
                );
    }

    /**
     * HTTP fetch for camera deviceinfo; invokes callback with normalized display string (any thread).
     */
    public static void fetchDeviceInfoDisplay(@NonNull Context context, @NonNull DeviceInfoDisplayCallback callback) {
        String url = CameraConfig.getBaseCameraAppUrl() + DEVICE_INFO_PATH;
        Log.i(TAG, "fetchDeviceInfoDisplay: GET " + url);
        RequestApi.getCameraRemoteApi().getDeviceInfo(CameraConfig.basicAuthorization(), url)
                .enqueue(new Callback<>() {
                    @Override
                    public void onResponse(Call<CameraDeviceInfo> call, Response<CameraDeviceInfo> response) {
                        if (!response.isSuccessful()) {
                            Log.w(TAG, "fetchDeviceInfoDisplay: HTTP " + response.code()
                                    + " url=" + url
                                    + " errorBody=" + safeErrorBody(response));
                            callback.onResult(CAMERA_VERSION_UNAVAILABLE);
                            return;
                        }
                        CameraDeviceInfo body = response.body();
                        if (body == null) {
                            Log.w(TAG, "fetchDeviceInfoDisplay: empty body url=" + url);
                            callback.onResult(CAMERA_VERSION_UNAVAILABLE);
                            return;
                        }
                        String display = resolveAppVersionForDisplay(body);
                        Log.i(TAG, "fetchDeviceInfoDisplay: body=" + GsonUtils.toJson(body)
                                + " display=" + display);
                        callback.onResult(display);
                    }

                    @Override
                    public void onFailure(Call<CameraDeviceInfo> call, Throwable t) {
                        Log.w(TAG, "fetchDeviceInfoDisplay: request failed url=" + url, t);
                        callback.onResult(CAMERA_VERSION_UNAVAILABLE);
                    }
                });
    }

    /**
     * Refreshes {@link com.lasercyber.lws.ui.common.camera.CameraDeviceInfoCache} and invokes callback with cached display.
     */
    public static void fetchCameraAppVersion(@NonNull Context context, @NonNull CameraAppVersionCallback callback) {
        com.lasercyber.lws.ui.common.camera.CameraDeviceInfoCache.refresh(
                context, () -> callback.onResult(
                        com.lasercyber.lws.ui.common.camera.CameraDeviceInfoCache.getDisplay()));
    }

    public interface DeviceInfoDisplayCallback {
        void onResult(@NonNull String displayVersion);
    }

    @Nullable
    private static String safeErrorBody(@NonNull Response<?> response) {
        try {
            if (response.errorBody() == null) {
                return null;
            }
            return response.errorBody().string();
        } catch (Exception e) {
            return "<read error: " + e.getMessage() + ">";
        }
    }

    @NonNull
    public static String resolveAppVersionForDisplay(@Nullable CameraDeviceInfo info) {
        if (info == null) {
            return CAMERA_VERSION_UNAVAILABLE;
        }
        return parseCameraAppVersionDisplayValue(info.getAppVersion());
    }

    /**
     * Normalizes camera {@code appVersion} for UI, e.g. {@code v1.0.5 build20251127} → {@code 1.0.5}.
     */
    @NonNull
    public static String parseCameraAppVersionDisplayValue(@Nullable String rawAppVersion) {
        if (rawAppVersion == null) {
            return CAMERA_VERSION_UNAVAILABLE;
        }
        String trimmed = rawAppVersion.trim();
        if (trimmed.isEmpty()) {
            return CAMERA_VERSION_UNAVAILABLE;
        }
        if (!trimmed.isEmpty() && (trimmed.charAt(0) == 'v' || trimmed.charAt(0) == 'V')) {
            trimmed = trimmed.substring(1).trim();
        }
        int buildIdx = indexOfIgnoreCase(trimmed, " build");
        if (buildIdx >= 0) {
            trimmed = trimmed.substring(0, buildIdx).trim();
        }
        return trimmed.isEmpty() ? CAMERA_VERSION_UNAVAILABLE : trimmed;
    }

    private static int indexOfIgnoreCase(@NonNull String haystack, @NonNull String needle) {
        return haystack.toLowerCase().indexOf(needle.toLowerCase());
    }

    public interface CameraAppVersionCallback {
        void onResult(@NonNull String displayVersion);
    }
}
