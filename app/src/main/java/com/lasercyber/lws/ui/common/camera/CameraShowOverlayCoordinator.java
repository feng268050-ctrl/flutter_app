package com.lasercyber.lws.ui.common.camera;

import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ui.bean.http.CameraShowTimeRequest;
import com.lasercyber.lws.ui.bean.http.CameraVideoOverlayEditor;
import com.lasercyber.lws.ui.bean.result.CameraResult;
import com.lasercyber.lws.ui.common.config.CameraConfig;
import com.lasercyber.lws.ui.common.config.DeviceModelConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.network.http.RequestApi;
import com.lasercyber.lws.ui.network.http.local.CameraShowOverlayBody;

import com.google.gson.JsonObject;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

import retrofit2.Response;

/**
 * Applies camera clock ({@code PUT /System/showtime}), name overlay
 * ({@code GET/PUT /Media/Video/overlays?channel=1}), then {@code PUT /System/saveConf}.
 */
public final class CameraShowOverlayCoordinator {
    private static final String TAG = LogTAGConstant.CameraRemote;
    private static final long APPLY_TIMEOUT_SEC = 45L;
    private static final String SHOW_TIME_PATH = "System/showtime";
    private static final String SAVE_CONF_PATH = "System/saveConf";

    private static volatile CameraShowOverlayCoordinator instance;

    private final ExecutorService executor = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "camera-show-overlay");
        t.setDaemon(true);
        return t;
    });

    private CameraShowOverlayCoordinator() {
    }

    @NonNull
    public static CameraShowOverlayCoordinator getInstance() {
        if (instance == null) {
            synchronized (CameraShowOverlayCoordinator.class) {
                if (instance == null) {
                    instance = new CameraShowOverlayCoordinator();
                }
            }
        }
        return instance;
    }

    @VisibleForTesting
    static void resetForTest() {
        synchronized (CameraShowOverlayCoordinator.class) {
            instance = null;
        }
    }

    public static final class Result {
        public final boolean success;
        public final int httpCode;
        @Nullable
        public final String errorMessage;
        @Nullable
        public final CameraShowOverlayBody.Data data;

        private Result(boolean success, int httpCode, @Nullable String errorMessage,
                       @Nullable CameraShowOverlayBody.Data data) {
            this.success = success;
            this.httpCode = httpCode;
            this.errorMessage = errorMessage;
            this.data = data;
        }

        @NonNull
        public static Result ok(@NonNull CameraShowOverlayBody.Data data) {
            return new Result(true, 200, null, data);
        }

        @NonNull
        public static Result fail(int httpCode, @NonNull String errorMessage,
                                  @Nullable CameraShowOverlayBody.Data data) {
            return new Result(false, httpCode, errorMessage, data);
        }
    }

    @NonNull
    public Result applyBlocking(int enable, int positionX, int positionY) throws InterruptedException {
        CountDownLatch latch = new CountDownLatch(1);
        AtomicReference<Result> ref = new AtomicReference<>();
        executor.execute(() -> {
            try {
                ref.set(applyOnWorker(enable, positionX, positionY));
            } catch (Exception ex) {
                Log.e(TAG, "applyBlocking: unexpected failure", ex);
                ref.set(Result.fail(503, "camera_show_overlay_failed", null));
            } finally {
                latch.countDown();
            }
        });
        if (!latch.await(APPLY_TIMEOUT_SEC, TimeUnit.SECONDS)) {
            return Result.fail(503, "camera_show_overlay_timeout", null);
        }
        Result result = ref.get();
        return result != null ? result : Result.fail(503, "camera_show_overlay_failed", null);
    }

    @VisibleForTesting
    @NonNull
    Result applyOnWorker(int enable, int positionX, int positionY) {
        String machineModel = resolveMachineModelName();
        CameraShowOverlayBody.Data data =
                new CameraShowOverlayBody.Data(enable, positionX, positionY, machineModel);
        CameraShowTimeRequest body =
                CameraShowTimeRequest.create(enable, positionX, positionY, enable == 1);
        String auth = CameraConfig.basicAuthorization();
        String baseUrl = CameraConfig.getBaseCameraAppUrl();

        try {
            Response<CameraResult> showTimeResponse = RequestApi.getCameraRemoteApi()
                    .updateShowTime(auth, body, baseUrl + SHOW_TIME_PATH)
                    .execute();
            String showTimeError = cameraResultError(showTimeResponse, SHOW_TIME_PATH);
            if (showTimeError != null) {
                return Result.fail(mapHttpStatus(showTimeResponse), showTimeError, data);
            }

            String overlayError = applyNameOverlay(auth, baseUrl, enable, positionX, positionY, machineModel);
            if (overlayError != null) {
                return Result.fail(503, overlayError, data);
            }

            Response<CameraResult> saveConfResponse = RequestApi.getCameraRemoteApi()
                    .saveConf(auth, baseUrl + SAVE_CONF_PATH)
                    .execute();
            String saveConfError = cameraResultError(saveConfResponse, SAVE_CONF_PATH);
            if (saveConfError != null) {
                return Result.fail(mapHttpStatus(saveConfResponse), saveConfError, data);
            }
            return Result.ok(data);
        } catch (Exception ex) {
            Log.e(TAG, "applyOnWorker: camera HTTP failed", ex);
            return Result.fail(503, "camera_unreachable", data);
        }
    }

    @NonNull
    private static String resolveMachineModelName() {
        return DeviceModelConfig.getModel().trim();
    }

    @Nullable
    private static String applyNameOverlay(@NonNull String auth, @NonNull String baseUrl, int enable,
                                             int positionX, int positionY, @NonNull String name) {
        String overlaysUrl = baseUrl + CameraVideoOverlayEditor.OVERLAYS_CHANNEL_1_PATH;
        try {
            Response<JsonObject> getResponse = RequestApi.getCameraRemoteApi()
                    .getVideoOverlays(auth, overlaysUrl)
                    .execute();
            if (getResponse == null || !getResponse.isSuccessful()) {
                int code = getResponse != null ? getResponse.code() : 0;
                return CameraVideoOverlayEditor.OVERLAYS_CHANNEL_1_PATH + "_http_" + code;
            }
            JsonObject getBody = getResponse.body();
            JsonObject config = CameraVideoOverlayEditor.parseOverlayConfig(getBody);
            if (config == null) {
                return CameraVideoOverlayEditor.OVERLAYS_CHANNEL_1_PATH + "_invalid_body";
            }
            JsonObject updated = CameraVideoOverlayEditor.applyNameOverlay(
                    config, enable, positionX, positionY, name);
            if (updated == null) {
                return CameraVideoOverlayEditor.OVERLAYS_CHANNEL_1_PATH + "_missing_name_overlay";
            }

            Response<CameraResult> putResponse = RequestApi.getCameraRemoteApi()
                    .putVideoOverlays(auth, updated, overlaysUrl)
                    .execute();
            return cameraResultError(putResponse, CameraVideoOverlayEditor.OVERLAYS_CHANNEL_1_PATH);
        } catch (Exception ex) {
            Log.e(TAG, "applyNameOverlay: camera HTTP failed", ex);
            return CameraVideoOverlayEditor.OVERLAYS_CHANNEL_1_PATH + "_failed";
        }
    }

    @Nullable
    private static String cameraResultError(@Nullable Response<CameraResult> response, @NonNull String path) {
        if (response == null) {
            return path + "_no_response";
        }
        if (!response.isSuccessful()) {
            return path + "_http_" + response.code();
        }
        CameraResult body = response.body();
        if (body == null) {
            return path + "_empty_body";
        }
        if (body.getErrCode() != 200) {
            String message = body.getErrMessage();
            if (message == null || message.trim().isEmpty()) {
                return path + "_err_" + body.getErrCode();
            }
            return path + "_err_" + body.getErrCode() + ":" + message.trim();
        }
        return null;
    }

    private static int mapHttpStatus(@Nullable Response<?> response) {
        if (response == null || !response.isSuccessful()) {
            return response != null && response.code() > 0 ? response.code() : 503;
        }
        return 200;
    }
}
