package com.lasercyber.lws.ui.common.worker;

import android.content.Context;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.work.Constraints;
import androidx.work.Data;
import androidx.work.ExistingWorkPolicy;
import androidx.work.ListenableWorker;
import androidx.work.NetworkType;
import androidx.work.OneTimeWorkRequest;
import androidx.work.OutOfQuotaPolicy;
import androidx.work.WorkManager;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.LwsCloudSyncLog;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.handler.ProcessVideoCoverR2Upload;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.repository.ProcessProcessVideoDao;

import java.io.IOException;
import java.util.List;

/**
 * WorkManager + foreground pass: uploads JPEG cover (R2 STS + S3 PutObject) for rows with {@code uploadStatus == 0},
 * then updates DB and sends {@code video.metadata}. Does not POST multipart video metadata to the Worker.
 */
public class ProcessVideoCoverWorker extends Worker {
    public static final String KEY_ROW_ID = "row_id";
    private static final String TAG = LogTAGConstant.VideoCoverWorker;

    private static final Handler COALESCE_HANDLER = new Handler(Looper.getMainLooper());
    private static final Object COALESCE_LOCK = new Object();
    private static final long COALESCE_DELAY_MS = 200L;
    private static Runnable coalescedDrain;

    public ProcessVideoCoverWorker(@NonNull Context context, @NonNull WorkerParameters workerParams) {
        super(context, workerParams);
    }

    public static void enqueueForRow(@NonNull Context context, long rowId) {
        if (rowId <= 0) {
            return;
        }
        Constraints constraints = new Constraints.Builder()
                .setRequiredNetworkType(NetworkType.NOT_REQUIRED)
                .build();
        OneTimeWorkRequest.Builder b = new OneTimeWorkRequest.Builder(ProcessVideoCoverWorker.class)
                .setConstraints(constraints)
                .setInputData(new Data.Builder().putLong(KEY_ROW_ID, rowId).build());
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            b.setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST);
        }
        OneTimeWorkRequest req = b.build();
        String unique = uniqueWorkNameForRow(rowId);
        WorkManager.getInstance(context.getApplicationContext())
                .enqueueUniqueWork(unique, ExistingWorkPolicy.KEEP, req);
        LwsCloudSyncLog.i("CoverWM", "enqueueForRow rowId=" + rowId + " uniqueWork=" + unique);
    }

    /**
     * Debounces {@link #enqueueAllPending(Context)} onto {@link ThreadPoolManager} (Room off main thread).
     */
    public static void enqueueAllPendingCoalesced(@NonNull Context context) {
        final Context app = context.getApplicationContext();
        synchronized (COALESCE_LOCK) {
            if (coalescedDrain != null) {
                COALESCE_HANDLER.removeCallbacks(coalescedDrain);
            }
            coalescedDrain = () -> {
                synchronized (COALESCE_LOCK) {
                    coalescedDrain = null;
                }
                ThreadPoolManager.getExecutor().execute(() -> enqueueAllPending(app));
            };
            COALESCE_HANDLER.postDelayed(coalescedDrain, COALESCE_DELAY_MS);
        }
    }

    static void tryUploadPendingCoverOnce(@NonNull Context app) {
        try {
            ProcessProcessVideoDao dao = AppDatabase.getInstance(app).processProcessVideoDao();
            List<Long> ids = dao.selectPendingCoverUploadRowIds(50);
            if (ids == null || ids.isEmpty()) {
                LwsCloudSyncLog.i("CoverWM", "immediate try skipped: no pending cover rows");
                return;
            }
            LwsCloudSyncLog.i("CoverWM", "immediate try pendingRows=" + ids.size());
            for (Long id : ids) {
                if (id == null || id <= 0) {
                    continue;
                }
                runCoverUploadForRow(app, id, "fg");
            }
        } catch (Exception e) {
            Log.w(TAG, "tryUploadPendingCoverOnce failed", e);
            LwsCloudSyncLog.w("CoverWM", "immediate try failed", e);
        }
    }

    @NonNull
    public static ListenableWorker.Result runCoverUploadForRow(
            @NonNull Context app, long rowId, @NonNull String source) {
        if (rowId < 0) {
            Log.w(TAG, source + ": invalid row_id");
            return ListenableWorker.Result.failure();
        }
        try {
            ProcessVideoCoverR2Upload.uploadCoverForRowIfPending(app, rowId);
            return ListenableWorker.Result.success();
        } catch (IOException e) {
            Log.w(TAG, source + ": cover retry rowId=" + rowId + " msg=" + e.getMessage());
            LwsCloudSyncLog.w("CoverWM", "retry rowId=" + rowId + " (" + source + ") msg=" + e.getMessage());
            return ListenableWorker.Result.retry();
        } catch (Exception e) {
            Log.e(TAG, source + ": cover failed rowId=" + rowId, e);
            LwsCloudSyncLog.e("CoverWM", "retry rowId=" + rowId + " (" + source + ")", e);
            return ListenableWorker.Result.retry();
        }
    }

    public static void enqueueAllPending(@NonNull Context context) {
        try {
            ProcessProcessVideoDao dao = AppDatabase.getInstance(context).processProcessVideoDao();
            List<Long> ids = dao.selectPendingCoverUploadRowIds(50);
            if (ids == null) {
                Log.i(TAG, "enqueueAllPending: query returned null");
                LwsCloudSyncLog.i("CoverWM", "enqueueAllPending: dao returned null id list");
                return;
            }
            int enqueued = 0;
            for (Long id : ids) {
                if (id != null && id > 0) {
                    enqueueForRow(context, id);
                    enqueued++;
                }
            }
            Log.i(TAG, "enqueueAllPending: pendingRows=" + ids.size() + " enqueuedWork=" + enqueued);
            LwsCloudSyncLog.i("CoverWM", "enqueueAllPending pendingRows=" + ids.size() + " enqueuedWork=" + enqueued);
            tryUploadPendingCoverOnce(context.getApplicationContext());
        } catch (Exception e) {
            Log.w(TAG, "enqueueAllPending failed", e);
            LwsCloudSyncLog.w("CoverWM", "enqueueAllPending failed", e);
        }
    }

    public static String uniqueWorkNameForRow(long rowId) {
        return "video-cover-" + rowId;
    }

    public static void cancelUniqueWorkForRow(@NonNull Context context, long rowId) {
        if (rowId <= 0) {
            return;
        }
        WorkManager.getInstance(context.getApplicationContext()).cancelUniqueWork(uniqueWorkNameForRow(rowId));
        LwsCloudSyncLog.i("CoverWM", "cancelUniqueWorkForRow rowId=" + rowId);
    }

    @NonNull
    @Override
    public ListenableWorker.Result doWork() {
        long rowId = getInputData().getLong(KEY_ROW_ID, -1L);
        return runCoverUploadForRow(getApplicationContext(), rowId, "wm");
    }
}
