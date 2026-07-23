package com.lasercyber.lws.ui.ai.upload;

import android.content.Context;
import android.os.Build;
import android.util.Log;
import android.app.Instrumentation;

import androidx.annotation.NonNull;
import androidx.work.Constraints;
import androidx.work.ExistingWorkPolicy;
import androidx.work.NetworkType;
import androidx.work.OneTimeWorkRequest;
import androidx.work.OutOfQuotaPolicy;
import androidx.work.WorkManager;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

import com.lasercyber.lws.ui.common.config.DeviceApiOriginConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import okhttp3.HttpUrl;

/**
 * Persistent WorkManager drain for AI report image uploads.
 */
public class AiUploadDrainWorker extends Worker {
    private static final String TAG = LogTAGConstant.AiUploadCoordinator;
    private static final String UNIQUE_WORK = "ai-upload-drain";

    public AiUploadDrainWorker(@NonNull Context context, @NonNull WorkerParameters workerParams) {
        super(context, workerParams);
    }

    static void enqueueDrain(@NonNull Context context) {
        Context app = context.getApplicationContext();
        Constraints constraints = new Constraints.Builder()
                .setRequiredNetworkType(NetworkType.NOT_REQUIRED)
                .build();
        OneTimeWorkRequest.Builder builder = new OneTimeWorkRequest.Builder(AiUploadDrainWorker.class)
                .setConstraints(constraints);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST);
        }
        WorkManager.getInstance(app)
                .enqueueUniqueWork(UNIQUE_WORK, ExistingWorkPolicy.APPEND_OR_REPLACE, builder.build());
        Log.i(TAG, "enqueueDrain uniqueWork=" + UNIQUE_WORK);
    }

    @NonNull
    @Override
    public Result doWork() {
        Context app = getApplicationContext();
        Log.i(TAG, "doWork start");
        if (!AiUploadCoordinator.hasPendingWork(app)) {
            Log.i(TAG, "doWork no pending work");
            return Result.success();
        }
        if (DeviceApiOriginConfig.getPinnedBase() == null) {
            if (isRunningUnderAndroidXInstrumentation()) {
                // Instrumented-test fallback: avoid waiting on network callback probing.
                DeviceApiOriginConfig.setPinnedBaseForTest(HttpUrl.get("https://api-test.lasercyber.workers.dev"));
                Log.i(TAG, "doWork instrumentation fallback pinned base=api-test");
            }
        }
        if (DeviceApiOriginConfig.getPinnedBase() == null) {
            Log.i(TAG, "ai upload drain retry: pinned API base null");
            return Result.retry();
        }
        boolean ok = AiUploadCoordinator.drainPendingQueues(app);
        if (ok) {
            Log.i(TAG, "doWork success");
            return Result.success();
        }
        if (AiUploadCoordinator.hasPendingWork(app)) {
            Log.i(TAG, "doWork retry pending work remains");
            return Result.retry();
        }
        Log.i(TAG, "doWork success with no remaining pending work");
        return Result.success();
    }

    private static boolean isRunningUnderAndroidXInstrumentation() {
        try {
            Class<?> activityThreadClass = Class.forName("android.app.ActivityThread");
            Object activityThread = activityThreadClass.getMethod("currentActivityThread").invoke(null);
            if (activityThread == null) {
                return false;
            }
            Object instrumentationObj = activityThreadClass.getMethod("getInstrumentation").invoke(activityThread);
            if (!(instrumentationObj instanceof Instrumentation)) {
                return false;
            }
            String cls = instrumentationObj.getClass().getName();
            return cls.startsWith("androidx.test.") || cls.contains("MonitoringInstrumentation");
        } catch (Throwable ignored) {
            return false;
        }
    }
}
