package com.lasercyber.lws.ui.ai.upload;

import android.content.Context;
import android.util.Log;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.device.DeviceIdentity;
import com.lasercyber.lws.ui.common.utils.json.GsonInitUtils;
import com.lasercyber.lws.ui.network.http.DeviceWorkerAiReportClient;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.nio.charset.StandardCharsets;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.Arrays;
import java.util.Calendar;

/**
 * Local {@code files/ai_upload/} layout, pending queue, and Worker {@code ai-report} upload.
 */
public final class AiUploadCoordinator {
    private static final String TAG = LogTAGConstant.AiUploadCoordinator;
    private static final Object QUEUE_LOCK = new Object();

    private AiUploadCoordinator() {
    }

    /**
     * Create task under today's date, copy image to {@link AiUploadPaths#IMAGE_NAME}, append to pending queue, then schedule upload.
     *
     * @return {@code true} when the task was queued (drain scheduled); {@code false} when skipped or staging failed
     */
    public static boolean enqueue(Context context, AiUploadModel model, int type, File imageSource, @Nullable String statJson) {
        Context app = context.getApplicationContext();
        Calendar cal = Calendar.getInstance();
        String sn = DeviceIdentity.getDeviceSnSafely().trim();
        if (sn.isEmpty() || "unknown-sn".equals(sn)) {
            Log.w(TAG, "enqueue skipped: invalid sn");
            return false;
        }
        if (imageSource == null || !imageSource.isFile()) {
            Log.w(TAG, "enqueue skipped: missing image file");
            return false;
        }
        Log.i(TAG, "enqueue task model=" + model.wireValue() + " type=" + type
                + " source=" + imageSource.getAbsolutePath());
        String taskId = java.util.UUID.randomUUID().toString();
        File modelDir = AiUploadPaths.modelDirectory(app, cal, model);
        File taskDir = AiUploadPaths.taskDirectory(modelDir, taskId);
        if (!taskDir.mkdirs() && !taskDir.isDirectory()) {
            Log.e(TAG, "mkdirs failed: " + taskDir);
            return false;
        }
        File destImage = new File(taskDir, AiUploadPaths.IMAGE_NAME);
        try {
            copyFile(imageSource, destImage);
        } catch (IOException e) {
            Log.e(TAG, "copy image failed", e);
            deleteRecursive(taskDir);
            return false;
        }
        AiUploadMetadata meta = new AiUploadMetadata();
        meta.sn = sn;
        meta.model = model.wireValue();
        meta.type = type;
        meta.timestamp_device = OffsetDateTime.now(ZoneId.systemDefault()).toString();
        try {
            String sourceLocation = AiUploadSourceDelete.classifySourceLocationForDeletion(app, imageSource);
            if (sourceLocation != null) {
                meta.source_image_absolute_path = imageSource.getCanonicalFile().getAbsolutePath();
                meta.source_location = sourceLocation;
            }
        } catch (IOException e) {
            Log.w(TAG, "skip recording source_image_absolute_path", e);
        }
        try {
            writeJson(new File(taskDir, AiUploadPaths.METADATA), meta);
            AiUploadStateFile st = new AiUploadStateFile();
            st.state = "pending";
            writeJson(new File(taskDir, AiUploadPaths.STATE), st);
            if (statJson != null && !statJson.isEmpty()) {
                try (OutputStreamWriter w = new OutputStreamWriter(
                        new FileOutputStream(new File(taskDir, "stat.json")), StandardCharsets.UTF_8)) {
                    w.write(statJson);
                }
            }
        } catch (IOException e) {
            Log.e(TAG, "write metadata failed", e);
            deleteRecursive(taskDir);
            return false;
        }
        File pending = AiUploadPaths.pendingQueueFile(modelDir);
        synchronized (QUEUE_LOCK) {
            try {
                AiUploadQueueJson.appendId(pending, taskId);
            } catch (IOException e) {
                Log.e(TAG, "queue append failed", e);
                deleteRecursive(taskDir);
                return false;
            }
        }
        scheduleDrain(app);
        return true;
    }

    /**
     * Schedule a persistent drain for all pending AI upload queues.
     */
    public static void scheduleDrain(Context context) {
        Context app = context.getApplicationContext();
        Log.i(TAG, "scheduleDrain requested");
        AiUploadDrainWorker.enqueueDrain(app);
    }

    static boolean hasPendingWork(Context app) {
        File root = AiUploadPaths.root(app);
        if (!root.isDirectory()) {
            return false;
        }
        for (File dateDir : listDateDirectories(root)) {
            for (AiUploadModel model : AiUploadModel.values()) {
                if (modelHasPendingWork(new File(dateDir, model.wireValue()))) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * Drain every persisted date queue. WorkManager may run after the capture date has changed, so this must not
     * limit itself to today's directory.
     *
     * @return {@code true} when no upload task reported a retryable failure.
     */
    static boolean drainPendingQueues(Context app) {
        File root = AiUploadPaths.root(app);
        if (!root.isDirectory()) {
            return true;
        }
        Log.i(TAG, "drainPendingQueues root=" + root.getAbsolutePath());
        boolean allOk = true;
        for (File dateDir : listDateDirectories(root)) {
            if (!drainPendingForDateDirectory(app, dateDir)) {
                allOk = false;
            }
        }
        return allOk;
    }

    private static boolean drainPendingForDateDirectory(Context app, File dateDir) {
        boolean allOk = true;
        for (AiUploadModel model : AiUploadModel.values()) {
            File modelDir = new File(dateDir, model.wireValue());
            File pending = AiUploadPaths.pendingQueueFile(modelDir);
            while (true) {
                String id;
                synchronized (QUEUE_LOCK) {
                    id = AiUploadQueueJson.peekFirst(pending);
                }
                if (id == null) {
                    break;
                }
                boolean ok = uploadOneTask(app, modelDir, model, id, pending);
                if (!ok) {
                    allOk = false;
                    break;
                }
            }
        }
        return allOk;
    }

    private static boolean uploadOneTask(Context app, File modelDir, AiUploadModel model, String taskId, File pendingFile) {
        File taskDir = AiUploadPaths.taskDirectory(modelDir, taskId);
        File image = new File(taskDir, AiUploadPaths.IMAGE_NAME);
        File metaFile = new File(taskDir, AiUploadPaths.METADATA);
        if (!image.isFile() || !metaFile.isFile()) {
            synchronized (QUEUE_LOCK) {
                try {
                    AiUploadQueueJson.removeFirstMatching(pendingFile, taskId);
                } catch (IOException e) {
                    Log.w(TAG, "drop stale queue entry", e);
                }
            }
            deleteRecursive(taskDir);
            return true;
        }
        AiUploadMetadata meta;
        try {
            meta = readJson(metaFile, AiUploadMetadata.class);
        } catch (IOException e) {
            Log.e(TAG, "read metadata failed", e);
            return false;
        }
        if (meta == null) {
            return false;
        }
        try {
            AiUploadStateFile st = new AiUploadStateFile();
            st.state = "uploading";
            writeJson(new File(taskDir, AiUploadPaths.STATE), st);
        } catch (IOException e) {
            Log.w(TAG, "state uploading", e);
        }
        String stat = null;
        File statSidecar = new File(taskDir, "stat.json");
        if (statSidecar.isFile()) {
            try {
                stat = readWholeFile(statSidecar);
            } catch (IOException ignored) {
            }
        }
        DeviceWorkerAiReportClient.Outcome out = DeviceWorkerAiReportClient.postAiReport(
                meta.sn,
                meta.type,
                meta.model,
                image,
                stat
        );
        if (!out.isOk()) {
            Log.w(TAG, "ai-report failed task=" + taskId + " err=" + out.getErrorMessage());
            try {
                AiUploadStateFile st = new AiUploadStateFile();
                st.state = "failed";
                writeJson(new File(taskDir, AiUploadPaths.STATE), st);
            } catch (IOException ignored) {
            }
            return false;
        }
        Log.i(TAG, "ai-report success task=" + taskId + " model=" + model.wireValue()
                + " sourceLocation=" + meta.source_location);
        String stagedCanon = null;
        try {
            if (image.isFile()) {
                stagedCanon = image.getCanonicalFile().getAbsolutePath();
            }
        } catch (IOException e) {
            Log.w(TAG, "canonical staged image path", e);
        }
        synchronized (QUEUE_LOCK) {
            try {
                AiUploadQueueJson.removeFirstMatching(pendingFile, taskId);
            } catch (IOException e) {
                Log.e(TAG, "queue remove failed", e);
                return false;
            }
        }
        File dateDir = modelDir.getParentFile();
        deleteRecursive(taskDir);
        try {
            AiUploadSourceDelete.tryDeleteSourceIfEligible(app, meta.source_image_absolute_path, stagedCanon);
            Log.i(TAG, "post-success cleanup task=" + taskId + " source=" + meta.source_image_absolute_path);
        } catch (Exception e) {
            Log.w(TAG, "source delete after success", e);
        }
        try {
            tryPruneDateDirectory(dateDir);
        } catch (Exception e) {
            Log.w(TAG, "prune date dir", e);
        }
        return true;
    }

    private static void tryPruneDateDirectory(@Nullable File dateDir) {
        if (dateDir == null || !dateDir.isDirectory()) {
            return;
        }
        for (AiUploadModel m : AiUploadModel.values()) {
            File md = new File(dateDir, m.wireValue());
            if (modelHasPendingWork(md)) {
                return;
            }
        }
        deleteRecursive(dateDir);
    }

    private static boolean modelHasPendingWork(File modelDir) {
        File tasks = new File(modelDir, AiUploadPaths.TASKS);
        String[] list = tasks.list();
        if (list != null && list.length > 0) {
            return true;
        }
        return !AiUploadQueueJson.readIds(AiUploadPaths.pendingQueueFile(modelDir)).isEmpty();
    }

    private static File[] listDateDirectories(File root) {
        java.util.ArrayList<File> out = new java.util.ArrayList<>();
        File[] years = sortedDirectories(root);
        for (File year : years) {
            File[] months = sortedDirectories(year);
            for (File month : months) {
                File[] days = sortedDirectories(month);
                out.addAll(Arrays.asList(days));
            }
        }
        return out.toArray(new File[0]);
    }

    private static File[] sortedDirectories(File dir) {
        File[] dirs = dir.listFiles(File::isDirectory);
        if (dirs == null) {
            return new File[0];
        }
        Arrays.sort(dirs, (a, b) -> a.getName().compareTo(b.getName()));
        return dirs;
    }

    private static void copyFile(File src, File dst) throws IOException {
        try (FileInputStream in = new FileInputStream(src); FileOutputStream out = new FileOutputStream(dst)) {
            byte[] buf = new byte[64 * 1024];
            int n;
            while ((n = in.read(buf)) != -1) {
                out.write(buf, 0, n);
            }
        }
    }

    private static <T> void writeJson(File file, T value) throws IOException {
        File p = file.getParentFile();
        if (p != null && !p.isDirectory() && !p.mkdirs()) {
            throw new IOException("mkdirs: " + p);
        }
        try (OutputStreamWriter w = new OutputStreamWriter(new FileOutputStream(file), StandardCharsets.UTF_8)) {
            GsonInitUtils.getGson().toJson(value, w);
        }
    }

    private static <T> T readJson(File file, Class<T> type) throws IOException {
        try (InputStreamReader r = new InputStreamReader(new FileInputStream(file), StandardCharsets.UTF_8)) {
            return GsonInitUtils.getGson().fromJson(r, type);
        }
    }

    private static String readWholeFile(File file) throws IOException {
        try (InputStreamReader r = new InputStreamReader(new FileInputStream(file), StandardCharsets.UTF_8)) {
            StringBuilder sb = new StringBuilder();
            char[] buf = new char[4096];
            int n;
            while ((n = r.read(buf)) != -1) {
                sb.append(buf, 0, n);
            }
            return sb.toString();
        }
    }

    static void deleteRecursive(File f) {
        if (f.isDirectory()) {
            File[] ch = f.listFiles();
            if (ch != null) {
                for (File c : ch) {
                    deleteRecursive(c);
                }
            }
        }
        //noinspection ResultOfMethodCallIgnored
        f.delete();
    }
}
