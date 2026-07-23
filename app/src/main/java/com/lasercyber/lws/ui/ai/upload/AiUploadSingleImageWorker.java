package com.lasercyber.lws.ui.ai.upload;

import android.content.Context;
import android.os.Build;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.work.Constraints;
import androidx.work.Data;
import androidx.work.ExistingWorkPolicy;
import androidx.work.NetworkType;
import androidx.work.OneTimeWorkRequest;
import androidx.work.OutOfQuotaPolicy;
import androidx.work.WorkManager;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

import com.lasercyber.lws.ui.common.config.DeviceApiOriginConfig;
import com.lasercyber.lws.ui.common.device.DeviceIdentity;
import com.lasercyber.lws.ui.common.handler.DeviceStatusPut;
import com.lasercyber.lws.ui.common.utils.json.GsonInitUtils;
import com.lasercyber.lws.ui.network.http.DeviceWorkerAiReportClient;

import java.io.File;
import java.io.IOException;

import okhttp3.HttpUrl;

/**
 * One WorkManager work uploads exactly one image and deletes that source image after Worker success.
 * Used by Pictures batch ({@link AiUploadPictureDirectoryQueue}) and Live stain audit
 * ({@link StainAuditUploadCoordinator}).
 */
public class AiUploadSingleImageWorker extends Worker {
    private static final String TAG = "AiUpload";
    private static final String KEY_SOURCE_PATH = "source_path";
    private static final String KEY_MODEL = "model";
    private static final String KEY_TYPE = "type";
    private static final String KEY_SN = "sn";
    private static final String KEY_API_BASE = "api_base";
    private static final String KEY_STAT_JSON = "stat_json";
    private static final String UNIQUE_PREFIX = "ai-upload-image-";
    /** WorkManager {@link Data} payload limit is ~10 KiB; keep headroom for other keys. */
    private static final int MAX_STAT_JSON_BYTES = 8 * 1024;

    public AiUploadSingleImageWorker(@NonNull Context context, @NonNull WorkerParameters workerParams) {
        super(context, workerParams);
    }

    public static void enqueue(
            @NonNull Context context,
            @NonNull File imageFile,
            @NonNull AiUploadModel model,
            int type,
            @Nullable String sn,
            @Nullable HttpUrl apiBase
    ) {
        enqueue(context, imageFile, model, type, sn, apiBase, null);
    }

    /**
     * @param statJson optional ai-report {@code stat} body; when null/blank, uses a device status snapshot
     */
    public static void enqueue(
            @NonNull Context context,
            @NonNull File imageFile,
            @NonNull AiUploadModel model,
            int type,
            @Nullable String sn,
            @Nullable HttpUrl apiBase,
            @Nullable String statJson
    ) {
        Context app = context.getApplicationContext();
        String sourcePath;
        try {
            sourcePath = imageFile.getCanonicalFile().getAbsolutePath();
        } catch (IOException e) {
            sourcePath = imageFile.getAbsolutePath();
        }
        Data.Builder input = new Data.Builder()
                .putString(KEY_SOURCE_PATH, sourcePath)
                .putString(KEY_MODEL, model.wireValue())
                .putInt(KEY_TYPE, type);
        if (sn != null && !sn.trim().isEmpty()) {
            input.putString(KEY_SN, sn.trim());
        }
        if (apiBase != null) {
            input.putString(KEY_API_BASE, apiBase.toString());
        }
        if (statJson != null && !statJson.isEmpty()) {
            if (statJson.length() > MAX_STAT_JSON_BYTES) {
                Log.w(TAG, "stat_json too large (" + statJson.length()
                        + " chars); worker will fall back to device snapshot");
            } else {
                input.putString(KEY_STAT_JSON, statJson);
            }
        }

        Constraints constraints = new Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build();
        OneTimeWorkRequest.Builder request = new OneTimeWorkRequest.Builder(AiUploadSingleImageWorker.class)
                .setConstraints(constraints)
                .setInputData(input.build());
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            request.setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST);
        }
        String uniqueName = UNIQUE_PREFIX + Integer.toHexString(sourcePath.hashCode());
        WorkManager.getInstance(app).enqueueUniqueWork(uniqueName, ExistingWorkPolicy.REPLACE, request.build());
        Log.i(TAG, "enqueue single image work name=" + uniqueName + " source=" + sourcePath
                + " has_stat=" + (statJson != null && !statJson.isEmpty()));
    }

    @NonNull
    @Override
    public Result doWork() {
        Context app = getApplicationContext();
        String sourcePath = getInputData().getString(KEY_SOURCE_PATH);
        String model = getInputData().getString(KEY_MODEL);
        int type = getInputData().getInt(KEY_TYPE, 0);
        String sn = getInputData().getString(KEY_SN);
        String apiBase = getInputData().getString(KEY_API_BASE);
        String statFromInput = getInputData().getString(KEY_STAT_JSON);

        if (apiBase != null && !apiBase.trim().isEmpty()) {
            try {
                DeviceApiOriginConfig.setPinnedBase(HttpUrl.get(apiBase.trim()));
            } catch (IllegalArgumentException e) {
                Log.e(TAG, "single image work failed: bad api base " + apiBase, e);
                return Result.failure();
            }
        }
        if (sn == null || sn.trim().isEmpty()) {
            sn = DeviceIdentity.getDeviceSnSafely();
        }
        if (sourcePath == null || sourcePath.trim().isEmpty()) {
            Log.w(TAG, "single image work drop: missing source path");
            return Result.failure();
        }
        File source = new File(sourcePath);
        if (!source.isFile()) {
            Log.i(TAG, "single image work source already gone: " + sourcePath);
            return Result.success();
        }
        if (!AiUploadPictureDirectoryQueue.isSupportedImageFile(source)) {
            Log.w(TAG, "single image work drop unsupported file: " + sourcePath);
            return Result.failure();
        }
        String stat = (statFromInput != null && !statFromInput.isEmpty())
                ? statFromInput
                : GsonInitUtils.getGson().toJson(new DeviceStatusPut().packRemoteSnapshot(app));
        Log.i(TAG, "single image work upload start sn=" + sn + " model=" + model + " source=" + sourcePath
                + " stat_source=" + ((statFromInput != null && !statFromInput.isEmpty()) ? "input" : "snapshot"));
        DeviceWorkerAiReportClient.Outcome outcome = DeviceWorkerAiReportClient.postAiReport(
                sn,
                type,
                model,
                source,
                stat
        );
        if (!outcome.isOk()) {
            Log.w(TAG, "single image work upload retry source=" + sourcePath
                    + " err=" + outcome.getErrorMessage());
            return Result.retry();
        }
        AiUploadSourceDelete.tryDeleteSourceIfEligible(app, sourcePath, null);
        Log.i(TAG, "single image work upload success and delete requested source=" + sourcePath);
        return Result.success();
    }
}
