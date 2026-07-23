package com.lasercyber.lws.ui.component;

import android.app.Activity;
import android.content.Context;
import android.content.res.TypedArray;
import android.os.Handler;
import android.os.Looper;
import android.util.AttributeSet;
import android.util.Log;
import android.view.LayoutInflater;
import android.widget.LinearLayout;

import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;

import com.blankj.utilcode.util.GsonUtils;
import com.blankj.utilcode.util.StringUtils;
import com.blankj.utilcode.util.ToastUtils;
import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.entity.ProcessParamsVideo;
import com.lasercyber.lws.ui.bean.ui.SubmitProcessDataAndVideo;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.camera.CameraCommStatus;
import com.lasercyber.lws.ui.common.camera.CameraPingHealth;
import com.lasercyber.lws.ui.common.camera.CameraRecordButtonVisualState;
import com.lasercyber.lws.ui.common.camera.CameraRecordCoordinator;
import com.lasercyber.lws.ui.common.camera.CameraRecordStateStore;
import com.lasercyber.lws.ui.common.camera.EasyPlayerClientManger;
import com.lasercyber.lws.ui.common.gpio.LaserEnableStateHolder;
import com.lasercyber.lws.ui.network.http.local.CameraRecordUiBridge;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.enums.UploadFileType;
import com.lasercyber.lws.ui.common.handler.VideoAndProcessParamsHandler;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.VideoUploadProgressDialog;
import com.lasercyber.lws.ui.databinding.CameraControllerBinding;
import com.lasercyber.lws.frostui.control.interop.FrostCheckboxView;

import org.apache.commons.lang3.time.DurationFormatUtils;

import java.util.Objects;

import lombok.Setter;
import lombok.extern.apachecommons.CommonsLog;

/**
 * Recording Work checkbox: when checked, Laser Enable ON auto-starts process-video recording.
 * Fill color follows work-mode orange / green / blue.
 */
@CommonsLog
public class CameraController extends LinearLayout
        implements MemoryCacheManager.OnCacheChangedListener,
        CameraRecordStateStore.Listener,
        LaserEnableStateHolder.Listener {
    private static final int DEFAULT_MODEL_TYPE = ModelConstant.CONTINUOUS_WELDING;
    private static final String TAG = LogTAGConstant.CameraController;
    private CameraControllerBinding binding;
    @Setter
    private CameraControllerListener cameraControllerListener;
    protected Handler handler = new Handler(Looper.getMainLooper());
    @Nullable
    private VideoUploadProgressDialog videoUploadProgressDialog;
    private volatile boolean uploadCancelledByUser;
    // 工艺参数临时保存
    private ProcessParametersData processParametersDataTemp;
    /**
     * 停止录制视频的回调
     */
    private StopRecordListener stopRecordListener;
    private boolean commCacheListenerRegistered;
    private boolean laserListenerRegistered;
    private boolean syncInFlight;

    public CameraController(Context context) {
        super(context);
        initView(context);
        attrsHandler(context, null);
    }

    public CameraController(Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
        initView(context);
        attrsHandler(context, attrs);
    }

    public CameraController(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        initView(context);
        attrsHandler(context, attrs);
    }

    public CameraController(Context context, AttributeSet attrs, int defStyleAttr, int defStyleRes) {
        super(context, attrs, defStyleAttr, defStyleRes);
        initView(context);
        attrsHandler(context, attrs);
    }

    public void initView(Context context) {
        binding = CameraControllerBinding.inflate(LayoutInflater.from(context), this, true);

        initRecord();
        FrostCheckboxView checkbox = binding.recordWorkingCheckbox;
        checkbox.setOnCheckedChangeListener((view, isChecked) -> {
            if (!suppressArmedSideEffects) {
                syncRecordingWithArmedAndLaser();
                if (recordWorkingArmedChangeListener != null) {
                    recordWorkingArmedChangeListener.onRecordWorkingArmedChanged(isChecked);
                }
            }
            notifyRecordUiStateChanged();
        });
        applyModeColor(binding.getModelType() != null ? binding.getModelType() : DEFAULT_MODEL_TYPE);
    }

    @Nullable
    private OnRecordWorkingArmedChangeListener recordWorkingArmedChangeListener;
    private boolean suppressArmedSideEffects;
    @Nullable
    private Runnable recordUiStateChangedListener;

    public void setOnRecordWorkingArmedChangeListener(
            @Nullable OnRecordWorkingArmedChangeListener listener) {
        recordWorkingArmedChangeListener = listener;
    }

    public void setRecordUiStateChangedListener(@Nullable Runnable listener) {
        recordUiStateChangedListener = listener;
    }

    private void notifyRecordUiStateChanged() {
        if (recordUiStateChangedListener != null) {
            recordUiStateChangedListener.run();
        }
    }

    public boolean isRecordWorkingArmed() {
        return binding != null
                && binding.recordWorkingCheckbox != null
                && binding.recordWorkingCheckbox.isChecked();
    }

    /** Keep the Record Work arm state aligned across Engineer Mode tab-local controls. */
    public void setRecordWorkingArmed(boolean armed) {
        if (binding == null || binding.recordWorkingCheckbox == null) {
            return;
        }
        suppressArmedSideEffects = true;
        try {
            binding.recordWorkingCheckbox.setChecked(armed);
        } finally {
            suppressArmedSideEffects = false;
        }
    }

    /** Toggle Record Working when the surrounding row is tapped. */
    public void toggleRecordWorkingArmed() {
        if (binding == null || binding.recordWorkingCheckbox == null
                || !binding.recordWorkingCheckbox.isEnabled()) {
            return;
        }
        binding.recordWorkingCheckbox.toggle();
    }

    /**
     * Start when Record Working is checked and Laser Enable is on; stop otherwise.
     */
    private void syncRecordingWithArmedAndLaser() {
        if (binding == null || syncInFlight) {
            return;
        }
        boolean armed = isRecordWorkingArmed();
        boolean laserOn = LaserEnableStateHolder.isActive();
        if (armed && laserOn) {
            if (!isRecording()) {
                boolean cameraCommHealthy = CameraCommStatus.isHealthy();
                if (CameraRecordButtonVisualState.shouldShowCameraUnavailableToast(false, cameraCommHealthy)) {
                    ToastUtils.showShort(R.string.unable_to_open_the_camera_title);
                    return;
                }
                if (CameraRecordButtonVisualState.shouldStartPreflightOnTap(false, cameraCommHealthy)) {
                    checkAndStartRecord();
                }
            }
            return;
        }
        if (isRecording()) {
            stopRecord();
        }
    }

    @Override
    public void onLaserEnableChanged(boolean active) {
        handler.post(this::syncRecordingWithArmedAndLaser);
    }

    private void refreshRecordVisualState() {
        if (binding == null) {
            return;
        }
        boolean healthy = CameraCommStatus.isHealthy();
        binding.setCameraCommAvailable(healthy);
        // Disabled look comes from FrostCheckbox (same as Auto Wire Feed); do not also dim the root.
        binding.cameraControllerRoot.setAlpha(1f);
        applyModeColor(binding.getModelType() != null ? binding.getModelType() : DEFAULT_MODEL_TYPE);
        applyCheckboxEnabledForComm(healthy);
        notifyRecordUiStateChanged();
    }

    /**
     * Camera unreachable → Recording Work cannot be checked (and any arm is cleared).
     */
    private void applyCheckboxEnabledForComm(boolean healthy) {
        if (binding == null || binding.recordWorkingCheckbox == null || syncInFlight) {
            return;
        }
        if (!healthy) {
            if (binding.recordWorkingCheckbox.isChecked()) {
                binding.recordWorkingCheckbox.setChecked(false);
            }
            binding.recordWorkingCheckbox.setEnabled(false);
            return;
        }
        binding.recordWorkingCheckbox.setEnabled(true);
    }

    private boolean useModeColor = true;

    private void applyModeColor(@Nullable Integer modelType) {
        if (binding == null || binding.recordWorkingCheckbox == null) {
            return;
        }
        int colorRes = R.color.frost_control_checkbox_fill;
        if (!useModeColor) {
            binding.recordWorkingCheckbox.setCheckedFillColor(
                    ContextCompat.getColor(getContext(), colorRes));
            return;
        }
        colorRes = R.color.quick_model_orange;
        int type = modelType != null ? modelType : DEFAULT_MODEL_TYPE;
        if (type == ModelConstant.WELD_CLEAN || type == ModelConstant.WIDTH_CLEAN) {
            colorRes = R.color.quick_model_green;
        } else if (type == ModelConstant.HAND_CUT) {
            colorRes = R.color.quick_model_blue;
        }
        binding.recordWorkingCheckbox.setCheckedFillColor(
                ContextCompat.getColor(getContext(), colorRes));
    }

    /**
     * Used by {@link com.lasercyber.lws.ui.common.camera.CameraRecordSaveHandler} when persisting.
     */
    public int getModelTypeForSave() {
        return binding != null ? binding.getModelType() : ModelConstant.CONTINUOUS_WELDING;
    }

    @Nullable
    public ProcessParametersData resolveSaveProcessParameters() {
        return findProcessParametersData();
    }

    public void notifySaveComplete() {
        invokeStopCall();
    }

    /**
     * 查找视频的工艺参数
     *
     * @return
     */
    private ProcessParametersData findProcessParametersData() {
        ProcessParametersData processParametersData = null;
        if (cameraControllerListener != null) {
            processParametersData = cameraControllerListener.getProcessParametersData();
        }
        if (processParametersData == null) {
            processParametersData = processParametersDataTemp;
        } else {
            processParametersData = processParametersData.clone();
            if (processParametersDataTemp != null &&
                    processParametersDataTemp.getProcessType() != null &&
                    !Objects.equals(processParametersDataTemp.getProcessType(), processParametersData.getProcessType())) {
                processParametersData = processParametersDataTemp;
            }
        }
        return processParametersData;
    }

    private void invokeStopCall() {
        if (stopRecordListener != null) {
            handler.post(() -> {
                stopRecordListener.callBack();
            });
        }
    }

    /**
     * 上传视频
     *
     * @param processParamsVideo
     */
    private void doUploadVideo(ProcessParamsVideo processParamsVideo, long videoId, String videoTitle) {
        uploadCancelledByUser = false;
        Context ctx = getContext();
        if (!(ctx instanceof Activity)) {
            ToastUtils.showShort(R.string.upload_failed);
            return;
        }
        dismissVideoUploadProgress();
        videoUploadProgressDialog = new VideoUploadProgressDialog((Activity) ctx, () -> {
            uploadCancelledByUser = true;
            VideoAndProcessParamsHandler.cancelActiveUpload();
            dismissVideoUploadProgress();
        });
        videoUploadProgressDialog.show();
        videoUploadProgressDialog.updateProgress(0, Utils.getApp().getString(R.string.uploading_in_progress));
        SubmitProcessDataAndVideo submitProcessDataAndVideo = new SubmitProcessDataAndVideo();
        submitProcessDataAndVideo.setVideoTitle(videoTitle);
        submitProcessDataAndVideo.setVideoPath(processParamsVideo.getVideoPath())
                .setOssAsyncResumableUploadSuccess((request, result, type) -> {
                    Log.d(TAG, "全部上传成功=====>" + type);
                    if (type == UploadFileType.VIDEO) {
                        handler.post(this::dismissVideoUploadProgress);
                        ToastUtils.showShort(R.string.upload_successful);
                    }
                })
                .setOssAsyncResumableUploadFail((request, clientExcepion, serviceException, type) -> {
                    Log.d(TAG, "上传失败", clientExcepion);
                    handler.post(() -> {
                        dismissVideoUploadProgress();
                        if (uploadCancelledByUser) {
                            uploadCancelledByUser = false;
                            ToastUtils.showShort(R.string.upload_cancelled);
                            return;
                        }
                        ToastUtils.showShort(R.string.upload_failed);
                    });
                })
                .setOssProgressCallback((request, currentSize, totalSize, type) -> {
                    Log.d(TAG, "上传进度【" + type + "】：" + currentSize + "  " + totalSize);
                    if (type != UploadFileType.VIDEO || totalSize <= 0) {
                        return;
                    }
                    final int progress = (int) Math.min(100L, (currentSize * 100L) / totalSize);
                    final String phase = Utils.getApp().getString(R.string.video_upload_phase_video);
                    handler.post(() -> {
                        if (videoUploadProgressDialog != null) {
                            videoUploadProgressDialog.updateProgress(progress, phase + " · " + progress + "%");
                        }
                    });
                });
        if (!StringUtils.isEmpty(processParamsVideo.getProcessParametersJson())) {
            submitProcessDataAndVideo.setProcessParametersData(
                    GsonUtils.fromJson(processParamsVideo.getProcessParametersJson(), ProcessParametersData.class));
        }

        // 录制完成后的首次上传（R2 STS 封面 + 元数据登记 + R2 STS 视频）
        VideoAndProcessParamsHandler.saveVideoAndProcessParams(submitProcessDataAndVideo);
    }

    private void dismissVideoUploadProgress() {
        if (videoUploadProgressDialog != null) {
            videoUploadProgressDialog.dismiss();
            videoUploadProgressDialog = null;
        }
    }

    /**
     * 解析参数
     *
     * @param context
     * @param attrs
     */
    private void attrsHandler(Context context, @Nullable AttributeSet attrs) {
        TypedArray typedArray = context.obtainStyledAttributes(attrs, R.styleable.CameraControllerAttrs);
        // 自定义的属性xml
        try {
            useModeColor = typedArray.getBoolean(
                    R.styleable.CameraControllerAttrs_record_use_mode_color, true);
            int modeType = typedArray.getInt(R.styleable.CameraControllerAttrs_mode_type, DEFAULT_MODEL_TYPE);
            binding.setModelType(modeType);
            applyModeColor(modeType);
            if (typedArray.hasValue(R.styleable.CameraControllerAttrs_record_label_text_size)) {
                float sizePx = typedArray.getDimension(
                        R.styleable.CameraControllerAttrs_record_label_text_size, 0f);
                float scaledDensity = getResources().getDisplayMetrics().scaledDensity;
                binding.recordWorkingCheckbox.setLabelTextSizeSp(sizePx / scaledDensity);
            }
        } catch (Exception exception) {
            Log.e(TAG, "相机控制组件，初始化参数异常", exception);
        } finally {
            // 回收typedArray
            typedArray.recycle();
        }
    }

    public void setMode_type(int modelType) {
        binding.setModelType(modelType);
        applyModeColor(modelType);
    }

    /**
     * 初始化数据
     */
    private void initRecord() {
        binding.setIsRecord(Boolean.FALSE);
        binding.setIsRecordPreparing(Boolean.FALSE);
        binding.setRecordingDuration("");
        refreshRecordVisualState();
    }

    /**
     * 检测摄像头并开始录制
     */
    private void checkAndStartRecord() {
        if (syncInFlight) {
            return;
        }
        syncInFlight = true;
        if (binding != null) {
            binding.recordWorkingCheckbox.setEnabled(false);
        }
        CameraRecordCoordinator.getInstance().runStartPreflight(
                true,
                () -> {
                    syncInFlight = false;
                    if (binding != null) {
                        applyCheckboxEnabledForComm(CameraCommStatus.isHealthy());
                    }
                    if (!isRecordWorkingArmed() || !LaserEnableStateHolder.isActive()) {
                        return;
                    }
                    startRecord();
                },
                () -> {
                    syncInFlight = false;
                    if (binding != null) {
                        applyCheckboxEnabledForComm(CameraCommStatus.isHealthy());
                        refreshRecordVisualState();
                    }
                }
        );
    }

    /**
     * Remote / HTTP start after preflight: same UI and timer path as a tap, without re-running checks.
     */
    public void applyExternalRecordOn() {
        if (binding == null || isRecording()) {
            return;
        }
        startRecord();
    }

    /**
     * HTTP path: enter preparing visuals before {@link EasyPlayerClientManger#start()} runs off-thread.
     */
    public void applyExternalRecordPreparing() {
        if (binding == null || isRecording()) {
            return;
        }
        if (cameraControllerListener != null) {
            ProcessParametersData processParametersData = cameraControllerListener.getProcessParametersData();
            if (processParametersData != null) {
                processParametersDataTemp = processParametersData.clone();
            }
            Log.d(TAG, "applyExternalRecordPreparing: process snapshot=" + processParametersDataTemp);
        }
        binding.setIsRecordPreparing(Boolean.TRUE);
        binding.setIsRecord(Boolean.FALSE);
        binding.setRecordingDuration("");
        refreshRecordVisualState();
    }

    /** HTTP path: muxer is writing; align UI with {@link #syncRecordTimerWithMuxer()}. */
    public void applyExternalRecordMuxerReady() {
        syncRecordTimerWithMuxer();
    }

    /** HTTP path: start/muxer failed after preparing visuals were shown. */
    public void applyExternalRecordStartFailed() {
        resetRecordUi();
        ToastUtils.showShort(R.string.recording_failed);
    }

    /**
     * Remote / HTTP stop: same as tapping stop while recording.
     */
    public void applyExternalRecordOff() {
        if (binding == null || !isRecording()) {
            return;
        }
        stopRecord();
    }

    /**
     * 开始录制
     */
    private void startRecord() {
        // 先记录工艺参数
        if (cameraControllerListener != null) {
            ProcessParametersData processParametersData = cameraControllerListener.getProcessParametersData();
            if (processParametersData != null) {
                processParametersDataTemp = processParametersData.clone();
            }
            Log.d(TAG, "startRecord: 开始录制视频时，先获取一次工艺参数：" + processParametersDataTemp);
        }
        binding.setIsRecordPreparing(Boolean.TRUE);
        binding.setIsRecord(Boolean.FALSE);
        binding.setRecordingDuration("");
        refreshRecordVisualState();
        Log.d(TAG, "开始录制=====>");
        ThreadPoolManager.getExecutor().execute(() -> {
            boolean initAndStart;
            try {
                initAndStart = EasyPlayerClientManger.getInstance().start();
            } catch (Throwable t) {
                Log.e(TAG, "recorder start threw", t);
                initAndStart = false;
            }
            if (!initAndStart) {
                Log.e(TAG, "初始化失败");
                handler.post(() -> {
                    resetRecordUi();
                    ToastUtils.showShort(R.string.recording_failed);
                });
            }
        });
    }

    /**
     * 停止录制
     */
    private void stopRecord() {
        Log.d(TAG, "stopRecord: 开始停止录制");
        resetRecordUi();
        ThreadPoolManager.getExecutor().execute(() -> {
            try {
                EasyPlayerClientManger.getInstance().stop();
            } catch (Throwable t) {
                Log.e(TAG, "recorder stop threw", t);
            }
        });
    }

    private void resetRecordUi() {
        if (binding != null) {
            binding.setIsRecord(Boolean.FALSE);
            binding.setIsRecordPreparing(Boolean.FALSE);
            binding.setRecordingDuration("");
            refreshRecordVisualState();
        }
    }

    /** Called when recording aborts without a saveable file. */
    public void resetRecordUiPublic() {
        resetRecordUi();
    }

    private void updateRecordingDuration(long elapsedMs) {
        if (binding == null) {
            return;
        }
        binding.setRecordingDuration(
                DurationFormatUtils.formatDuration(elapsedMs, "mm:ss"));
    }

    private void updateRecordingDurationIfActive(long elapsedMs) {
        if (binding == null || !isRecording()) {
            return;
        }
        if (Objects.equals(binding.getIsRecordPreparing(), Boolean.TRUE)) {
            return;
        }
        updateRecordingDuration(elapsedMs);
    }

    /** Expand timer and switch to recording icon when muxer begins writing frames. */
    private void syncRecordTimerWithMuxer() {
        if (!isRecording()) {
            return;
        }
        if (binding != null) {
            binding.setIsRecordPreparing(Boolean.FALSE);
            binding.setIsRecord(Boolean.TRUE);
            refreshRecordVisualState();
        }
        updateRecordingDuration(0L);
    }

    @Override
    public void onRecordingChanged(boolean recording) {
        if (!recording && binding != null && isRecording()) {
            resetRecordUi();
        }
    }

    /**
     * After a 10-minute segment is saved: if Record Working is still armed and Laser Enable
     * is still on, start the next segment; otherwise leave recording stopped.
     */
    private void onRecordingDurationLimitReached() {
        if (binding == null) {
            return;
        }
        // Clear UI flags before preflight; EasyPlayer session is already stopped.
        resetRecordUi();
        if (!isRecordWorkingArmed() || !LaserEnableStateHolder.isActive()) {
            Log.d(TAG, "duration limit: not rolling over armed=" + isRecordWorkingArmed()
                    + " laser=" + LaserEnableStateHolder.isActive());
            return;
        }
        Log.d(TAG, "duration limit: rolling over to next recording segment");
        checkAndStartRecord();
    }

    /**
     * 是否正在录制中
     *
     * @return
     */
    public boolean isRecording() {
        if (binding == null) {
            return false;
        }
        return Objects.equals(binding.getIsRecord(), Boolean.TRUE)
                || Objects.equals(binding.getIsRecordPreparing(), Boolean.TRUE);
    }

    public boolean tryStopRecord(StopRecordListener stopRecordListener) {
        if (binding == null) {
            return false;
        }
        if (!isRecording()) {
            return false;
        }
        Log.d(TAG, "tryStopRecord: 当前正在录制中:" + binding.getIsRecord());
        stopRecord();
        this.stopRecordListener = stopRecordListener;
        return true;
    }

    @Override
    public void onCacheChanged(String key) {
        if (!CacheKey.CAMERA_PING_REACHABLE.equals(key)) {
            return;
        }
        handler.post(this::refreshRecordVisualState);
    }

    @Override
    protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        CameraRecordUiBridge.register(this);
        CameraRecordStateStore.addListener(this);
        if (!laserListenerRegistered) {
            LaserEnableStateHolder.addListener(this);
            laserListenerRegistered = true;
        }
        EasyPlayerClientManger manager = EasyPlayerClientManger.getInstance();
        manager.setMuxerBeganListener(this::syncRecordTimerWithMuxer);
        manager.setMuxerProgressListener(this::updateRecordingDurationIfActive);
        manager.setDurationLimitListener(this::onRecordingDurationLimitReached);
        manager.setMuxerStartFailedListener(() -> {
            resetRecordUi();
            ToastUtils.showShort(R.string.recording_failed);
        });
        if (!commCacheListenerRegistered) {
            MemoryCacheManager.getInstance().addListener(CacheKey.CAMERA_PING_REACHABLE, this);
            commCacheListenerRegistered = true;
        }
        CameraPingHealth.getInstance().probeAsync();
        refreshRecordVisualState();
        syncRecordingWithArmedAndLaser();
    }

    @Override
    protected void onDetachedFromWindow() {
        if (commCacheListenerRegistered) {
            MemoryCacheManager.getInstance().removeListener(CacheKey.CAMERA_PING_REACHABLE, this);
            commCacheListenerRegistered = false;
        }
        if (laserListenerRegistered) {
            LaserEnableStateHolder.removeListener(this);
            laserListenerRegistered = false;
        }
        CameraRecordUiBridge.unregister(this);
        CameraRecordStateStore.removeListener(this);
        EasyPlayerClientManger manager = EasyPlayerClientManger.getInstance();
        manager.setMuxerBeganListener(null);
        manager.setMuxerProgressListener(null);
        manager.setMuxerStartFailedListener(null);
        manager.setDurationLimitListener(null);
        dismissVideoUploadProgress();
        super.onDetachedFromWindow();
        handler.removeCallbacksAndMessages(null);
        if (binding != null) {
            binding.unbind();
            binding = null;
        }

        cameraControllerListener = null;
        recordWorkingArmedChangeListener = null;
        stopRecordListener = null;
    }

    public interface OnRecordWorkingArmedChangeListener {
        void onRecordWorkingArmedChanged(boolean armed);
    }

    public interface CameraControllerListener {
        /**
         * 获取工艺参数
         *
         * @return
         */
        ProcessParametersData getProcessParametersData();
    }

    public interface StopRecordListener {
        /**
         * 停止录制视频的回调
         */
        void callBack();
    }
}
