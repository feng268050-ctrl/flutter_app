package com.lasercyber.lws.ui.ai.upload;

import android.content.Context;
import android.os.SystemClock;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ai.daemon.AiDaemonSupervisor;
import com.lasercyber.lws.ai.model.OpencvStainDetectJson;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ai.model.StainAuditStat;
import com.lasercyber.lws.ai.model.StainAuditStatus;
import com.lasercyber.lws.ai.model.StainDetectSource;
import com.lasercyber.lws.ai.stain.StainAuditStatusMapper;
import com.lasercyber.lws.ai.stream.StreamDetectEvent;
import com.lasercyber.lws.ui.common.config.DeviceApiOriginConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.settings.AiAssistanceSettings;
import com.lasercyber.lws.ui.common.utils.json.GsonInitUtils;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Live weld {@code lens_det} audit upload enqueue (V1: {@link StainAuditStatus#DETECT_FAILED} only).
 * <p>
 * Uses the same WorkManager path as Pictures batch ({@link AiUploadSingleImageWorker} →
 * {@code postAiReport}), after copying {@code input_frame.jpg} into {@code files/ai_audit_inbox/}
 * so native {@code frame_*} dirs can be deleted without racing the upload.
 * <p>
 * Disk safeguard: enqueues at most one DETECT_FAILED every {@link #MIN_ENQUEUE_INTERVAL_MS};
 * throttled frames discard native artifacts. On laser-off grace end, purges leftover {@code frame_*}.
 */
public final class StainAuditUploadCoordinator {

    private static final String TAG = LogTAGConstant.AiUploadCoordinator;
    private static final String INPUT_FRAME_NAME = "input_frame.jpg";
    private static final String INBOX_DIR = "ai_audit_inbox";
    /** Avoid flooding R2 while every live -3 would otherwise enqueue. */
    static final long MIN_ENQUEUE_INTERVAL_MS = 15_000L;

    private static final ExecutorService ENQUEUE_EXECUTOR = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "stain-audit-upload");
        t.setDaemon(true);
        return t;
    });

    private static final AtomicLong lastEnqueueElapsedMs = new AtomicLong(0L);

    public interface EnqueueSink {
        boolean enqueue(Context context, File imageFile, String statJson);
    }

    @Nullable
    private static volatile EnqueueSink enqueueSinkForTest;

    private StainAuditUploadCoordinator() {
    }

    public static void maybeEnqueueLiveDetectFailed(@Nullable Context context,
                                                    @NonNull StreamDetectEvent.DetectResult event,
                                                    @NonNull OpencvStainDetectResult result) {
        if (!StainDetectSource.LIVE.equals(result.source)) {
            return;
        }
        if (context == null && enqueueSinkForTest == null) {
            return;
        }
        StainAuditStatusMapper.Mapped mapped = StainAuditStatusMapper.mapLiveWeld(result);
        if (!mapped.uploadEligible || mapped.status != StainAuditStatus.DETECT_FAILED) {
            return;
        }
        Context app = context != null ? context.getApplicationContext() : null;
        if (enqueueSinkForTest == null
                && (app == null || !AiAssistanceSettings.isLensContaminationDetectionEnabled(app))) {
            Log.d(TAG, "stain_audit_enqueue_skipped assist_off frame_id=" + event.frameId);
            return;
        }

        File inputFrame = resolveInputFrame(app, event);
        if (inputFrame == null || !inputFrame.isFile()) {
            Log.w(TAG, "stain_audit_enqueue_skipped missing input_frame.jpg frame_id=" + event.frameId
                    + " reason=" + result.message
                    + " files=" + OpencvStainDetectJson.parseSummary(event.summaryJson).files);
            return;
        }

        long now = SystemClock.elapsedRealtime();
        long prev = lastEnqueueElapsedMs.get();
        if (enqueueSinkForTest == null
                && prev > 0L
                && (now - prev) < MIN_ENQUEUE_INTERVAL_MS) {
            Log.i(TAG, "stain_audit_enqueue_throttled frame_id=" + event.frameId
                    + " wait_ms=" + (MIN_ENQUEUE_INTERVAL_MS - (now - prev)));
            deleteNativeFrameArtifacts(inputFrame);
            return;
        }

        StainAuditStat stat = StainAuditStat.fromLiveDetect(mapped.status, result, event.frameId);
        String statJson = GsonInitUtils.getGson().toJson(stat);
        final File frameFile = inputFrame;
        ENQUEUE_EXECUTOR.execute(() -> {
            boolean ok;
            EnqueueSink sink = enqueueSinkForTest;
            if (sink != null) {
                ok = sink.enqueue(app, frameFile, statJson);
            } else {
                ok = stageAndEnqueueSingleImageWork(app, frameFile, statJson);
            }
            if (ok) {
                lastEnqueueElapsedMs.set(SystemClock.elapsedRealtime());
                // Inbox / Worker holds the upload copy; drop native frame_* immediately.
                deleteNativeFrameArtifacts(frameFile);
                Log.i(TAG, "stain_audit_enqueue status=" + mapped.status
                        + " frame_id=" + event.frameId + " reason=" + result.message
                        + " source=" + frameFile.getAbsolutePath());
            } else {
                Log.w(TAG, "stain_audit_enqueue_failed frame_id=" + event.frameId
                        + " source=" + frameFile.getAbsolutePath());
            }
        });
    }

    /**
     * Copy native frame into app-owned inbox, then schedule the same single-image Work as Pictures.
     */
    private static boolean stageAndEnqueueSingleImageWork(@NonNull Context app,
                                                          @NonNull File inputFrame,
                                                          @NonNull String statJson) {
        File staged = stageInboxCopy(app, inputFrame);
        if (staged == null) {
            return false;
        }
        try {
            AiUploadSingleImageWorker.enqueue(
                    app,
                    staged,
                    AiUploadModel.LENS,
                    0,
                    null,
                    DeviceApiOriginConfig.getPinnedBase(),
                    statJson);
            return true;
        } catch (RuntimeException e) {
            Log.e(TAG, "stain_audit single-image enqueue failed", e);
            //noinspection ResultOfMethodCallIgnored
            staged.delete();
            return false;
        }
    }

    @Nullable
    private static File stageInboxCopy(@NonNull Context app, @NonNull File inputFrame) {
        File inbox = new File(app.getFilesDir(), INBOX_DIR);
        if (!inbox.isDirectory() && !inbox.mkdirs()) {
            Log.e(TAG, "stain_audit inbox mkdirs failed: " + inbox.getAbsolutePath());
            return null;
        }
        File dest = new File(inbox, UUID.randomUUID() + ".jpg");
        try {
            copyFile(inputFrame, dest);
            return dest;
        } catch (IOException e) {
            Log.e(TAG, "stain_audit inbox copy failed", e);
            //noinspection ResultOfMethodCallIgnored
            dest.delete();
            return null;
        }
    }

    private static void copyFile(@NonNull File from, @NonNull File to) throws IOException {
        try (FileInputStream in = new FileInputStream(from);
             FileOutputStream out = new FileOutputStream(to)) {
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) >= 0) {
                out.write(buf, 0, n);
            }
            out.getFD().sync();
        }
    }

    /**
     * After laser-off grace / session stop: remove leftover {@code frame_*} dirs under the last
     * StreamDetect session output (inbox copies already hold staged images for in-flight works).
     */
    public static void cleanupLiveSessionFrameArtifacts(@Nullable Context context) {
        String sessionDir = AiDaemonSupervisor.getInstance().getLastStreamDetectOutputDir();
        if (sessionDir == null || sessionDir.isEmpty()) {
            return;
        }
        File dir = new File(sessionDir);
        if (!dir.isDirectory()) {
            return;
        }
        File[] children = dir.listFiles();
        if (children == null) {
            return;
        }
        int removed = 0;
        for (File child : children) {
            if (child != null && child.isDirectory() && child.getName().startsWith("frame_")) {
                deleteRecursive(child);
                removed++;
            }
        }
        if (removed > 0) {
            Log.i(TAG, "stain_audit_session_cleanup removed_frames=" + removed
                    + " session=" + sessionDir);
        }
    }

    @Nullable
    private static File resolveInputFrame(@Nullable Context app,
                                          @NonNull StreamDetectEvent.DetectResult event) {
        OpencvStainDetectJson.Summary summary = OpencvStainDetectJson.parseSummary(event.summaryJson);
        File lensGuard = app != null ? new File(app.getFilesDir(), "lens_guard") : null;
        File resolved = OpencvStainDetectJson.findWrittenFile(summary, INPUT_FRAME_NAME, lensGuard);
        if (resolved != null && resolved.isFile()) {
            return resolved;
        }
        String sessionDir = AiDaemonSupervisor.getInstance().getLastStreamDetectOutputDir();
        if (sessionDir != null && !sessionDir.isEmpty() && event.frameId > 0) {
            File fallback = new File(sessionDir, "frame_" + event.frameId + File.separator + INPUT_FRAME_NAME);
            if (fallback.isFile()) {
                Log.i(TAG, "stain_audit_resolve_fallback frame_id=" + event.frameId
                        + " path=" + fallback.getAbsolutePath());
                return fallback;
            }
        }
        return resolved;
    }

    /** Deletes {@code frame_*} directory that owns {@code input_frame.jpg}. */
    @VisibleForTesting
    static void deleteNativeFrameArtifacts(@Nullable File inputFrame) {
        if (inputFrame == null) {
            return;
        }
        File parent = inputFrame.getParentFile();
        if (parent != null && parent.isDirectory() && parent.getName().startsWith("frame_")) {
            deleteRecursive(parent);
            return;
        }
        if (inputFrame.isFile() && !inputFrame.delete()) {
            Log.w(TAG, "stain_audit_delete_failed path=" + inputFrame.getAbsolutePath());
        }
    }

    private static void deleteRecursive(@NonNull File f) {
        File[] children = f.listFiles();
        if (children != null) {
            for (File c : children) {
                if (c != null) {
                    deleteRecursive(c);
                }
            }
        }
        //noinspection ResultOfMethodCallIgnored
        f.delete();
    }

    public static void setEnqueueSinkForTest(@Nullable EnqueueSink sink) {
        enqueueSinkForTest = sink;
        lastEnqueueElapsedMs.set(0L);
    }

    @VisibleForTesting
    public static void resetThrottleForTest() {
        lastEnqueueElapsedMs.set(0L);
    }
}
