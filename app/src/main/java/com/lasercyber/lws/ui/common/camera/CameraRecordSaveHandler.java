package com.lasercyber.lws.ui.common.camera;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.Nullable;

import com.blankj.utilcode.util.GsonUtils;
import com.blankj.utilcode.util.StringUtils;
import com.blankj.utilcode.util.ToastUtils;
import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.entity.ProcessParamsVideo;
import com.lasercyber.lws.ui.bean.entity.VideoInfo;
import com.lasercyber.lws.ui.common.config.CameraConfig;
import com.lasercyber.lws.ui.common.config.DeviceApiOriginConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.constant.VideoUploadStatus;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.state.ProcessParametersSnapshotStore;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.LocalVideoPlaybackValidator;
import com.lasercyber.lws.ui.common.utils.VideoCoverExtractor;
import com.lasercyber.lws.ui.common.utils.VideoFileUtils;
import com.lasercyber.lws.ui.common.worker.ProcessVideoCoverWorker;
import com.lasercyber.lws.ui.component.CameraController;
import com.lasercyber.lws.ui.network.http.local.CameraRecordUiBridge;

import java.io.File;
import java.util.UUID;

/**
 * Always-on {@link EasyPlayerClientManger} listener: persist recordings started from HTTP,
 * Fast Mode, or Engineer Mode even when the camera float is not attached.
 */
public final class CameraRecordSaveHandler implements EasyPlayerClientManger.IPlayerClientListener {
    private static final String TAG = LogTAGConstant.CameraRecordSaveHandler;

    private static volatile CameraRecordSaveHandler instance;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private volatile long recordingStartTimeMs;
    @Nullable
    private volatile ProcessParametersData startSnapshot;

    private CameraRecordSaveHandler() {
    }

    public static void ensureRegistered() {
        if (instance != null) {
            return;
        }
        synchronized (CameraRecordSaveHandler.class) {
            if (instance == null) {
                instance = new CameraRecordSaveHandler();
                EasyPlayerClientManger.getInstance().setListener(instance);
            }
        }
    }

    @Override
    public void startRecording() {
        recordingStartTimeMs = System.currentTimeMillis();
        ProcessParametersData snap = ProcessParametersSnapshotStore.getSnapshot();
        startSnapshot = snap == null ? null : snap.clone();
        CameraRecordStateStore.setRecording(true);
        mainHandler.post(() -> ToastUtils.showShort(R.string.start_recording_the_video));
    }

    @Override
    public void stopRecording(String path) {
        CameraRecordStateStore.setRecording(false);
        long durationMs = System.currentTimeMillis() - recordingStartTimeMs;
        ThreadPoolManager.getExecutor().execute(() -> {
            if (saveVideoBeforeCheck(path, durationMs)) {
                saveVideoAndProcess(path);
            }
        });
    }

    @Override
    public void pauseRecording() {
    }

    @Override
    public void resumeRecording() {
    }

    @Override
    public void recordingAborted() {
        CameraRecordStateStore.setRecording(false);
        startSnapshot = null;
        mainHandler.post(() -> {
            CameraController controller = CameraRecordUiBridge.get();
            if (controller != null) {
                controller.resetRecordUiPublic();
            }
            ToastUtils.showShort(R.string.recording_failed);
        });
    }

    private static final long MIN_SAVED_DURATION_MS = 1_000L;

    private boolean saveVideoBeforeCheck(String videoPath, long recordingDuration) {
        if (StringUtils.isEmpty(videoPath)) {
            Log.e(TAG, "saveVideoBeforeCheck: empty path, durationMs=" + recordingDuration);
            notifySaveComplete();
            mainHandler.post(() -> ToastUtils.showShort(
                    recordingDuration < 2000 ? R.string.the_recording_time_is_too_short : R.string.video_saving_failed));
            return false;
        }
        File file = new File(videoPath);
        if (!file.exists()) {
            Log.e(TAG, "saveVideoBeforeCheck: file missing path=" + videoPath + " durationMs=" + recordingDuration);
            notifySaveComplete();
            mainHandler.post(() -> ToastUtils.showShort(
                    recordingDuration < 2000 ? R.string.the_recording_time_is_too_short : R.string.video_saving_failed));
            return false;
        }
        LocalVideoPlaybackValidator.Result validation = LocalVideoPlaybackValidator.evaluate(file);
        if (!validation.playable) {
            Log.e(TAG, "saveVideoBeforeCheck: invalid recording path=" + videoPath
                    + " reason=" + validation.reason + " durationMs=" + recordingDuration);
            LocalVideoPlaybackValidator.deleteIfKnownInvalidShell(file);
            notifySaveComplete();
            mainHandler.post(() -> ToastUtils.showShort(R.string.video_saving_failed));
            return false;
        }
        VideoCoverExtractor.Probe probe = VideoCoverExtractor.probeVideoFile(file);
        if (probe.durationMs < MIN_SAVED_DURATION_MS) {
            Log.e(TAG, "saveVideoBeforeCheck: duration too short path=" + videoPath
                    + " probeMs=" + probe.durationMs + " wallMs=" + recordingDuration);
            if (probe.coverBitmap != null) {
                probe.coverBitmap.recycle();
            }
            LocalVideoPlaybackValidator.deleteIfKnownInvalidShell(file);
            notifySaveComplete();
            mainHandler.post(() -> ToastUtils.showShort(R.string.the_recording_time_is_too_short));
            return false;
        }
        if (probe.coverBitmap != null) {
            probe.coverBitmap.recycle();
        }
        return true;
    }

    private void saveVideoAndProcess(String videoPath) {
        mainHandler.post(() -> ToastUtils.showShort(R.string.recording_completed));
        ProcessParamsVideo processParamsVideo = new ProcessParamsVideo();
        processParamsVideo.setVideoPath(videoPath);
        processParamsVideo.setProcessType(resolveProcessType());
        processParamsVideo.setCreateTime(System.currentTimeMillis());
        processParamsVideo.setVideoId(UUID.randomUUID().toString());
        processParamsVideo.setUploadStatus(VideoUploadStatus.NOT_INITIATED);
        processParamsVideo.setUploadProgress(0);
        VideoInfo videoInfo = VideoFileUtils.readVideoFileInfo(videoPath);
        if (videoInfo != null) {
            processParamsVideo.setDuration(videoInfo.getDuration());
            processParamsVideo.setFileSize(videoInfo.getFileSize());
            if (!StringUtils.isEmpty(videoInfo.getResolution())) {
                processParamsVideo.setResolution(videoInfo.getResolution());
            }
        }
        if (StringUtils.isEmpty(processParamsVideo.getResolution())) {
            processParamsVideo.setResolution(
                    CameraConfig.VIDEO_RESOLUTION_WIDTH + "x" + CameraConfig.VIDEO_RESOLUTION_HEIGHT);
        }
        ProcessParametersData processParametersData = resolveProcessParameters();
        if (processParametersData != null) {
            processParamsVideo.setProcessParametersJson(GsonUtils.toJson(processParametersData));
            processParamsVideo.setMaterialType(processParametersData.getMaterialType());
        } else {
            Log.w(TAG, "saveVideoAndProcess: no process parameters available");
        }
        long rowId = AppDatabase.getInstance(Utils.getApp()).processProcessVideoDao().insert(processParamsVideo);
        processParamsVideo.setId(rowId);
        Log.d(TAG, "saveVideoAndProcess rowId=" + rowId + " path=" + videoPath);
        if (DeviceApiOriginConfig.getPinnedBase() != null) {
            ProcessVideoCoverWorker.enqueueAllPendingCoalesced(Utils.getApp());
        }
        notifySaveComplete();
    }

    private int resolveProcessType() {
        CameraController controller = CameraRecordUiBridge.get();
        if (controller != null) {
            return controller.getModelTypeForSave();
        }
        ProcessParametersData snap = startSnapshot;
        if (snap != null && snap.getProcessType() != null) {
            return snap.getProcessType();
        }
        return ModelConstant.CONTINUOUS_WELDING;
    }

    @Nullable
    private ProcessParametersData resolveProcessParameters() {
        CameraController controller = CameraRecordUiBridge.get();
        if (controller != null) {
            return controller.resolveSaveProcessParameters();
        }
        return startSnapshot;
    }

    private void notifySaveComplete() {
        mainHandler.post(() -> {
            CameraController controller = CameraRecordUiBridge.get();
            if (controller != null) {
                controller.notifySaveComplete();
            }
        });
    }
}
