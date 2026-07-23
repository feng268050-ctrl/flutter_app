package com.lasercyber.lws.ui.activitys.device.monitor.fragment;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.SurfaceTexture;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.ResultReceiver;
import android.os.SystemClock;
import android.preference.PreferenceManager;
import android.text.TextUtils;
import android.util.Log;
import android.view.MotionEvent;
import android.view.Surface;
import android.view.TextureView;
import android.view.View;

import com.blankj.utilcode.util.TimeUtils;
import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ui.BuildConfig;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseFragment;
import com.lasercyber.lws.ui.activitys.device.monitor.AiVisionVideoChooseActivity;
import com.lasercyber.lws.ui.activitys.device.monitor.model.ProcessVideoViewModel;
import com.lasercyber.lws.ai.sampling.AiFrameSamplingInterval;
import com.lasercyber.lws.ai.engine.AiEngineCapabilityProfile;
import com.lasercyber.lws.ai.stain.AiStainDetectResultMapper;
import com.lasercyber.lws.ai.engine.AiManager;
import com.lasercyber.lws.ai.engine.AiVisionDualLinkFieldTestLog;
import com.lasercyber.lws.ai.engine.AiVisionResolutionProfileLog;
import com.lasercyber.lws.ai.stain.OpencvStainDetectCoordinator;
import com.lasercyber.lws.ai.model.StainDetectSource;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ui.common.ai.overlay.DetectionOverlayMapper;
import com.lasercyber.lws.ui.common.ai.overlay.OverlayGeometry;
import com.lasercyber.lws.ai.stream.NativeStreamDetectCoordinator;
import com.lasercyber.lws.ai.stream.StreamDetectOverlayBridge;
import com.lasercyber.lws.ai.zeropoint.ZeroPointOverlaySnapshot;
import com.lasercyber.lws.ai.zeropoint.ZeroPointOverlayState;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.bean.entity.ProcessParamsVideo;
import com.lasercyber.lws.ui.bean.event.LensCheckResultEvent;
import com.lasercyber.lws.ui.bean.event.LensClsSnapshotEvent;
import com.lasercyber.lws.ui.bean.event.AiEngineStateEvent;
import com.lasercyber.lws.ui.bean.entity.vo.ProcessParamsVideoVo;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.config.CameraConfig;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.IntentParamsConstants;
import com.lasercyber.lws.ui.network.http.local.CameraAiHttpActiveSignal;
import com.lasercyber.lws.ui.network.http.local.CameraAiHttpPublisher;
import com.lasercyber.lws.ui.common.ai.vision.AiVisionWorkInfoLabels;
import com.lasercyber.lws.ui.common.ai.video.ProcessVideoAiInferencePaths;
import com.lasercyber.lws.ui.common.state.ProcessParametersSnapshotStore;
import com.lasercyber.lws.ui.common.ai.video.ProcessVideoAiSession;
import com.lasercyber.lws.ui.common.ai.video.ProcessVideoAiSessionRegistry;
import com.lasercyber.lws.ui.common.ai.video.ProcessVideoAiTimeline;
import com.lasercyber.lws.ui.common.ai.video.ProcessVideoAiTimelinePersistence;
import com.lasercyber.lws.ui.common.config.AppRuntimeEnvironment;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.LocalVideoPlaybackValidator;
import com.lasercyber.lws.ui.common.utils.VideoCoverExtractor;
import com.lasercyber.lws.ui.common.handler.AiVisionInferenceUploadStateStore;
import com.lasercyber.lws.ui.common.utils.StoragePermissionHelper;
import com.lasercyber.lws.ui.common.utils.SystemSettingUtils;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.common.view.DetectionOverlayView;
import com.lasercyber.lws.ui.databinding.FragmentAiVisionBinding;
import com.lasercyber.lws.ui.network.http.local.overlay.CameraAiOverlayState;
import com.lasercyber.lws.ui.network.mediamtx.MediaMtxRelayCoordinator;
import com.lasercyber.lws.ui.network.mediamtx.MediaMtxRelayUrls;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.FileProvider;
import androidx.lifecycle.ViewModelProvider;
import androidx.media3.common.C;
import androidx.media3.common.Format;
import androidx.media3.common.MediaItem;
import androidx.media3.common.PlaybackException;
import androidx.media3.common.Player;
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector;
import androidx.media3.datasource.DefaultDataSource;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory;

import org.easydarwin.video.Client;
import org.easydarwin.video.EasyPlayerClient;
import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;
import org.greenrobot.eventbus.ThreadMode;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.net.InetAddress;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class AiVisionFragment extends BaseFragment<FragmentAiVisionBinding> {

    private enum SelectedVideoUiMode {
        PROMPT_SELECT,
        IDLE_READY_TO_DETECT,
        IDLE_DETECTION_COMPLETE,
        PLAYBACK
    }

    private static final String TAG = "AiVisionFragment";
    private static final long RECONNECT_DELAY_MS = 2000L;
    private static final long FIRST_FRAME_TIMEOUT_MS = 8000L;
    private static final long HARDWARE_FIRST_FRAME_TIMEOUT_MS = 3000L;
    private static final long HARDWARE_DECODER_COOLDOWN_MS = 60_000L;
    private static final long STOP_PENDING_RETRY_MS = 250L;
    private static final int MAX_START_ATTEMPT_COUNT = 3;
    private static final long TEXTURE_POLL_MS = 50L;
    private static final int TEXTURE_POLL_MAX_ATTEMPTS = 100;
    private static final float MIN_ZOOM = 1.0f;
    private static final float BEST_ZOOM_THRESHOLD = 1.6f;
    private static final float MAX_ZOOM = 2.0f;
    private static final float ZOOM_GESTURE_SENSITIVITY = 1.25f;
    private static final float MIN_PINCH_RATIO = 0.88f;
    private static final float MAX_PINCH_RATIO = 1.12f;
    private static final float PINCH_RATIO_DEAD_ZONE = 0.028f;
    private static final float MIN_ZOOM_UPDATE_DELTA = 0.034f;
    /** Low-pass on two-finger span to reject touch digitizer noise when fingers are still. */
    private static final float PINCH_DISTANCE_SMOOTH_ALPHA = 0.38f;
    /** Snap zoom to a coarse grid so tiny ratio noise does not hunt between adjacent scales. */
    private static final float ZOOM_QUANT_STEP = 0.025f;
    /** Skip redundant TextureView#setTransform when zoom barely changed within this window. */
    private static final long ZOOM_TRANSFORM_MIN_INTERVAL_MS = 20L;
    private static final float ZOOM_TRANSFORM_EPSILON = 0.018f;
    private static final float STATE_DISPLAY_EPSILON = 0.01f;
    private static final long BEST_ZOOM_PAUSE_MS = 500L;
    private static final long BEST_LABEL_FLASH_MS = 120L;
    private static final String PREF_LAST_SELECTED_PROCESS_VIDEO_ROW_ID =
            "last_selected_process_video_row_id";
    private static final long TUTORIAL_START_DELAY_MS = 500L;
    private static final long TUTORIAL_LOOP_DELAY_MS = 1200L;
    private static final long TUTORIAL_ANIM_MS = 700L;
    private static final int TUTORIAL_PAGE_COUNT = 3;
    private static final long VIDEO_CONTROL_AUTO_HIDE_MS = 3000L;
    /** Matches finger dots / stage height in fragment_ai_vision.xml (stage 198dp, dots 78dp). */
    private static final float TUTORIAL_SPREAD_END_X = 128f;
    private static final float TUTORIAL_PINCH_START_X = 128f;
    private static final float TUTORIAL_PINCH_END_X = 38f;
    private static final long DOUBLE_TAP_TIMEOUT_MS = 300L;
    private static final float DOUBLE_TAP_SLOP_PX = 80f;
    private static final int AI_FRAME_SAMPLE_WIDTH = 640;
    private static final int AI_FRAME_SAMPLE_HEIGHT = 360;
            private static final long OFFLINE_VIDEO_OVERLAY_INTERVAL_MS = 250L;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final Matrix videoTransform = new Matrix();
    private final Runnable bestFlashRestoreTask = () -> {
        if (binding != null) {
            binding.tvZoomState.animate()
                    .alpha(1f)
                    .scaleX(1f)
                    .scaleY(1f)
                    .setDuration(BEST_LABEL_FLASH_MS)
                    .start();
        }
    };
    private EasyPlayerClient playerClient;
    private Surface playerSurface;
    @Nullable
    private ExoPlayer selectedVideoPlayer;
    @Nullable
    private String selectedVideoPlaybackPath;
    private boolean selectedVideoPausedByUser;
    private boolean selectedVideoPlaybackFailed;
    @Nullable
    private ProcessParamsVideoVo selectedProcessVideo;
    private ProcessVideoViewModel processVideoViewModel;
    @Nullable
    private String activeInferenceCacheKey;
    @Nullable
    private ProcessVideoAiSession selectedVideoAiSession;
    private boolean sourcePlaybackReachedEos;
    private boolean replayingDetectionOverlay;
    @Nullable
    private ProcessVideoAiTimeline replayTimeline;
    @Nullable
    private String replayClassificationLine;
    private SelectedVideoUiMode selectedVideoUiMode = SelectedVideoUiMode.PROMPT_SELECT;
    private int coverLoadGeneration;
    private long lastAppliedProcessVideoRowId;
    private boolean offlineInferenceProgressVisible;
    /** Guards {@link #updateVideoActionUiInternal()} against ExoPlayer listener reentrancy. */
    private boolean updatingVideoActionUi;
    private final Runnable updateVideoActionUiTask = this::updateVideoActionUiInternal;
    private boolean isActive;
    private int retryCount;
    private int liveStartAttemptCount;
    private String lastStreamFailureReason;
    private long streamStartElapsedMs;
    private Boolean previousWaitingIFrame;
    private final ZeroPointOverlayState.Listener zeroPointOverlayListener = this::applyZeroPointOverlay;
    private final StreamDetectOverlayBridge.Listener streamDetectOverlayListener =
            new StreamDetectOverlayBridge.Listener() {
                @Override
                public void onStreamDetectOverlayChanged(
                        @Nullable OpencvStainDetectResult stain, long frameId) {
                    mainHandler.post(AiVisionFragment.this::updateLiveInferenceOverlay);
                }

                @Override
                public void onStreamDetectPipelineError(@NonNull String detail) {
                    mainHandler.post(AiVisionFragment.this::updateLiveInferenceOverlay);
                }
            };
    @Nullable
    private volatile String overlayClassificationLine;
    @Nullable
    private volatile String overlayEngineDetailLine;
    @Nullable
    private final Runnable reconnectTask = this::startStream;
    private final Runnable deferredStartAfterStopTask = this::scheduleStartWhenTextureReady;
    @Nullable
    private Runnable firstFrameTimeoutTask;
    @Nullable
    private Runnable hardwareFirstFrameTimeoutTask;
    private final Runnable liveInferenceOverlayTask = this::updateLiveInferenceOverlay;
    private final Runnable offlineInferenceOverlayTask = this::updateOfflineInferenceOverlay;
    private final Runnable selectedVideoPlaybackTickTask = this::tickSelectedVideoPlayback;
    private final Runnable bestPauseTask = () -> bestPauseActive = false;
    private final Runnable hideSelectedVideoControlTask = this::hideSelectedVideoControl;
    private final Runnable zoomTutorialStartTask = this::showZoomTutorialOnEnter;
    private final Runnable zoomTutorialTask = this::runZoomTutorialStep;
    private float currentZoom = MIN_ZOOM;
    private float panX;
    private float panY;
    private boolean isPinching;
    private boolean didPinchInCurrentGesture;
    private boolean bestPauseActive;
    private boolean bestPauseConsumedForGesture;
    private float pinchLastDistance;
    /** Smoothed two-finger distance for stable pinch ratio (see {@link #updatePinchZoom}). */
    private float pinchDistanceSmoothed;
    private long lastZoomTransformApplyElapsedMs;
    private float lastAppliedZoomForThrottle = Float.NaN;
    private long lastTapUpTime;
    private float lastTapUpX;
    private float lastTapUpY;
    private int zoomTutorialPage;
    private final List<String> liveRtspCandidates = new ArrayList<>();
    private int liveRtspCandidateIndex;
    private int playerGeneration;
    private int previewSessionId;
    private int activeStreamSessionId;
    private boolean streamStarted;
    private boolean networkPrepared;
    private boolean currentStreamPreferSoftwareDecoder;
    private static volatile long hardwareDecoderUnhealthyUntilElapsedMs;
    private static volatile boolean playerStopInProgress;
    private boolean startPendingAfterStop;
    @Nullable
    private String liveRtspActiveUrl;
    private final ActivityResultLauncher<Intent> chooseVideoLauncher =
            registerForActivityResult(new ActivityResultContracts.StartActivityForResult(), result -> {
                if (result.getResultCode() != Activity.RESULT_OK || result.getData() == null) {
                    return;
                }
                Object extra = result.getData().getSerializableExtra(
                        IntentParamsConstants.AI_VISION_SELECTED_PROCESS_VIDEO);
                if (extra instanceof ProcessParamsVideoVo) {
                    applySelectedProcessVideo((ProcessParamsVideoVo) extra, false);
                }
            });
    private final ActivityResultLauncher<String[]> requestVideoReadPerm =
            registerForActivityResult(new ActivityResultContracts.RequestMultiplePermissions(), granted -> {
                if (!StoragePermissionHelper.allGranted(granted)) {
                    ToastUtils.showShort(R.string.lws_video_storage_permission_required);
                    return;
                }
                startSelectedVideoOfflineInference();
            });
    private final TextureView.SurfaceTextureListener previewSurfaceTextureListener =
            new TextureView.SurfaceTextureListener() {
                @Override
                public void onSurfaceTextureAvailable(SurfaceTexture surface, int width, int height) {
                    Log.i(TAG, "Surface available session=" + previewSessionId
                            + " size=" + width + "x" + height);
                }

                @Override
                public void onSurfaceTextureSizeChanged(SurfaceTexture surface, int width, int height) {
                    applyZoomTransform();
                }

                @Override
                public boolean onSurfaceTextureDestroyed(SurfaceTexture surface) {
                    Log.i(TAG, "Surface destroyed session=" + activeStreamSessionId);
                    startPendingAfterStop = false;
                    stopPreview("surface-destroyed");
                    return true;
                }

                @Override
                public void onSurfaceTextureUpdated(SurfaceTexture surface) {
                }
            };

    @Override
    protected int getLayoutId() {
        return R.layout.fragment_ai_vision;
    }

    @Override
    protected void initView() {
        processVideoViewModel = new ViewModelProvider(this).get(ProcessVideoViewModel.class);
        clearAiVisionInfoValues();
        binding.playerAiSelectedVideoView.setPlayer(null);
        showSelectedVideoStatus(R.string.ai_vision_select_video_first);
        binding.btnChooseVideo.setOnClickListener(view -> {
            GlobalSoundManager.playClickSound();
            chooseVideoLauncher.launch(new Intent(requireContext(), AiVisionVideoChooseActivity.class));
        });
        binding.btnReplayInferenceVideo.setOnClickListener(view -> {
            GlobalSoundManager.playClickSound();
            replayDetectionOverlay();
        });
        binding.btnRedetectVideo.setOnClickListener(view -> {
            GlobalSoundManager.playClickSound();
            forceReinferSelectedVideo();
        });
        binding.btnDetectVideo.setOnClickListener(view -> {
            GlobalSoundManager.playClickSound();
            startDetectionForSelectedVideo();
        });
        binding.btnSelectedVideoPlayPause.setOnClickListener(view -> {
            GlobalSoundManager.playClickSound();
            toggleSelectedVideoPlayback();
        });
        updateVideoActionUi();
        initZoomControls();
        binding.btnZoomTutorialPagePrev.setOnClickListener(view -> showTutorialPage(zoomTutorialPage - 1));
        binding.btnZoomTutorialPageNext.setOnClickListener(view -> {
            if (zoomTutorialPage >= TUTORIAL_PAGE_COUNT - 1) {
                dismissZoomTutorial();
            } else {
                showTutorialPage(zoomTutorialPage + 1);
            }
        });
        binding.tvZoomTutorialNext.setOnClickListener(view -> {
            if (zoomTutorialPage >= TUTORIAL_PAGE_COUNT - 1) {
                dismissZoomTutorial();
            } else {
                showTutorialPage(zoomTutorialPage + 1);
            }
        });
        binding.tvZoomTutorialSkip.setOnClickListener(view -> dismissZoomTutorial());
        binding.textureVisionView.setSurfaceTextureListener(previewSurfaceTextureListener);
    }

    private void ensurePlayerClient() {
        if (playerClient != null || binding == null || playerStopInProgress) {
            return;
        }
        TextureView textureView = binding.textureVisionView;
        if (!textureView.isAvailable() || textureView.getSurfaceTexture() == null) {
            Log.i(TAG, "Defer EasyPlayerClient create until TextureView surface is available");
            return;
        }
        releasePlayerSurface("replace-before-create");
        playerSurface = new Surface(textureView.getSurfaceTexture());
        final int generation = ++playerGeneration;
        playerClient = new EasyPlayerClient(
                requireContext(),
                playerSurface,
                new ResultReceiver(new Handler(Looper.getMainLooper())) {
                    @Override
                    protected void onReceiveResult(int resultCode, Bundle resultData) {
                        if (generation != playerGeneration || !isActive || binding == null) {
                            return;
                        }
                        if (resultCode == EasyPlayerClient.RESULT_VIDEO_DISPLAYED) {
                            int sessionId = activeStreamSessionId;
                            if (!isCurrentStreamSession(sessionId)) {
                                Log.i(TAG, "Ignore VIDEO_DISPLAYED from stale session=" + sessionId
                                        + " current=" + activeStreamSessionId);
                                return;
                            }
                            cancelFirstFrameTimeout();
                            cancelHardwareFirstFrameTimeout();
                            retryCount = 0;
                            liveStartAttemptCount = 0;
                            lastStreamFailureReason = null;
                            binding.tvVideoStatus.setVisibility(View.GONE);
                            scheduleAiFrameSampling();
                            refreshWorkInformationPanel();
                            long firstFrameMs = streamStartElapsedMs == 0L
                                    ? -1L
                                    : SystemClock.elapsedRealtime() - streamStartElapsedMs;
                            Context vctx = getContext();
                            int decodeType = -1;
                            if (resultData != null
                                    && resultData.containsKey(EasyPlayerClient.KEY_VIDEO_DECODE_TYPE)) {
                                decodeType = resultData.getInt(EasyPlayerClient.KEY_VIDEO_DECODE_TYPE, -1);
                            }
                            Log.i(TAG,
                                    "VIDEO_DISPLAYED decodeType=" + decodeType
                                            + " firstFrameMs=" + firstFrameMs
                                            + " (0=fallback/lite+PTS pacing, 1=MediaCodec)"
                                            + " profile=" + liveProfileLabel(vctx, liveRtspActiveUrl)
                                            + " candidate=" + liveCandidateProgress()
                                            + " session=" + sessionId
                                            + " preferSoftware=" + currentStreamPreferSoftwareDecoder
                                            + " nativeDetect="
                                            + CameraConfig.isNativeAiVisionStreamDetectEnabled());
                            if (decodeType == 1) {
                                markHardwareDecoderHealthy();
                            }
                            AiVisionDualLinkFieldTestLog.logPlaybackFirstFrame(
                                    firstFrameMs,
                                    decodeType,
                                    0,
                                    0,
                                    liveProfileLabel(vctx, liveRtspActiveUrl));
                        } else if (resultCode == EasyPlayerClient.RESULT_VIDEO_SIZE && resultData != null) {
                            int sessionId = activeStreamSessionId;
                            if (!isCurrentStreamSession(sessionId)) {
                                return;
                            }
                            int width = resultData.getInt(EasyPlayerClient.EXTRA_VIDEO_WIDTH, 0);
                            int height = resultData.getInt(EasyPlayerClient.EXTRA_VIDEO_HEIGHT, 0);
                            AiManager.getInstance().updateFrameSize(width, height);
                            Context szCtx = getContext();
                            Log.i(TAG, "LIVE_VIDEO_SIZE " + width + "x" + height
                                    + " url=" + liveRtspActiveUrl
                                    + " candidate=" + liveCandidateProgress()
                                    + " profile=" + liveProfileLabel(szCtx, liveRtspActiveUrl)
                                    + " session=" + sessionId);
                            AiVisionResolutionProfileLog.logPlaybackDecode(
                                    width,
                                    height,
                                    -1,
                                    liveProfileLabel(szCtx, liveRtspActiveUrl),
                                    liveRtspActiveUrl != null ? liveRtspActiveUrl : "");
                        } else if (resultCode == EasyPlayerClient.RESULT_TIMEOUT) {
                            onStreamFailed(
                                    activeStreamSessionId,
                                    getString(R.string.live_video_failed),
                                    getString(R.string.ai_vision_stream_failure_player_timeout));
                        } else if (resultCode == EasyPlayerClient.RESULT_UNSUPPORTED_VIDEO) {
                            onStreamFailed(
                                    activeStreamSessionId,
                                    getString(R.string.live_video_failed),
                                    getString(R.string.ai_vision_stream_failure_unsupported_video));
                        } else if (resultCode == EasyPlayerClient.RESULT_EVENT) {
                            if (isBenignRtspEvent(resultData)) {
                                return;
                            }
                            String detail = "";
                            if (resultData != null) {
                                String msg = resultData.getString("event-msg");
                                if (!TextUtils.isEmpty(msg)) {
                                    detail = msg;
                                } else if (resultData.containsKey("errorcode")) {
                                    detail = "code=" + resultData.getInt("errorcode");
                                }
                            }
                            Log.w(TAG, "RTSP EVENT failure" + (detail.isEmpty() ? "" : ": " + detail));
                            onStreamFailed(
                                    activeStreamSessionId,
                                    getString(R.string.live_video_failed),
                                    getString(R.string.ai_vision_stream_failure_rtsp_event,
                                            detail.isEmpty()
                                                    ? getString(R.string.unknown_text)
                                                    : detail));
                        }
                    }
                },
                null,
                null);
        playerClient.setAudioEnable(false);
        playerClient.setLowLatencyMode(true);
        playerClient.setAllowVideoDecoderLiteFallback(true);
        boolean preferSoftwareDecoder = isHardwareDecoderCoolingDown();
        playerClient.setPreferVideoDecoderLite(preferSoftwareDecoder);
        currentStreamPreferSoftwareDecoder = preferSoftwareDecoder;
        Log.i(TAG, "Decoder strategy preferSoftware=" + preferSoftwareDecoder
                + " hardwareCooldownRemainingMs=" + hardwareDecoderCooldownRemainingMs());
    }

    @Override
    protected void initData() {
        processVideoViewModel.init(getContext());
        restoreLastSelectedProcessVideo();
    }

    @Override
    public void onResume() {
        super.onResume();
        if (selectedProcessVideo != null) {
            if (isOfflineInferenceInProgress()) {
                syncSelectedVideoPlaybackAfterReapply();
            } else {
                presentIdleStateForSelectedVideo();
            }
        } else {
            restoreLastSelectedProcessVideo();
        }
        if (!EventBus.getDefault().isRegistered(this)) {
            EventBus.getDefault().register(this);
        }
        refreshAiOverlayFromCapabilities();
        applyAiVisionPreviewModes();
        isActive = true;
        ZeroPointOverlayState.getInstance().addListener(zeroPointOverlayListener);
        if (CameraConfig.isNativeAiVisionStreamDetectEnabled()) {
            StreamDetectOverlayBridge.getInstance().ensureSubscribed();
            StreamDetectOverlayBridge.getInstance().addListener(streamDetectOverlayListener);
        }
        networkPrepared = false;
        retryCount = 0;
        liveStartAttemptCount = 0;
        lastStreamFailureReason = null;
        liveRtspCandidates.clear();
        liveRtspCandidateIndex = 0;
        resetZoomToDefault();
        mainHandler.removeCallbacks(zoomTutorialStartTask);
        // Zoom Gesture Guide is temporarily disabled. Keep the tutorial code/resources
        // in place so the feature can be restored without rebuilding the UI.
        // mainHandler.postDelayed(zoomTutorialStartTask, TUTORIAL_START_DELAY_MS);
        refreshWorkInformationPanel();
        if (selectedProcessVideo == null) {
            overrideLowLatencyPrefs(true);
            if (binding != null) {
                binding.tvVideoStatus.setText(R.string.live_video_loading);
                binding.tvVideoStatus.setVisibility(View.VISIBLE);
            }
            prepareNetworkAndStartStream();
        }
    }

    @Override
    public void onPause() {
        isActive = false;
        ZeroPointOverlayState.getInstance().removeListener(zeroPointOverlayListener);
        if (CameraConfig.isNativeAiVisionStreamDetectEnabled()) {
            StreamDetectOverlayBridge.getInstance().removeListener(streamDetectOverlayListener);
        }
        networkPrepared = false;
        startPendingAfterStop = false;
        mainHandler.removeCallbacks(reconnectTask);
        mainHandler.removeCallbacks(deferredStartAfterStopTask);
        cancelFirstFrameTimeout();
        mainHandler.removeCallbacks(bestPauseTask);
        mainHandler.removeCallbacks(bestFlashRestoreTask);
        mainHandler.removeCallbacks(zoomTutorialStartTask);
        mainHandler.removeCallbacks(zoomTutorialTask);
        dismissZoomTutorial();
        stopAiFrameSampling();
        removeTexturePoll();
        stopPreview("pause");
        clearAiVisionPreviewModes();
        overrideLowLatencyPrefs(false);
        pauseSelectedVideoPlayback();
        cancelSelectedVideoInference(false);
        if (EventBus.getDefault().isRegistered(this)) {
            EventBus.getDefault().unregister(this);
        }
        super.onPause();
    }

    @Override
    public void onDestroyView() {
        isActive = false;
        networkPrepared = false;
        startPendingAfterStop = false;
        mainHandler.removeCallbacks(reconnectTask);
        mainHandler.removeCallbacks(deferredStartAfterStopTask);
        cancelFirstFrameTimeout();
        mainHandler.removeCallbacks(bestPauseTask);
        mainHandler.removeCallbacks(bestFlashRestoreTask);
        mainHandler.removeCallbacks(zoomTutorialStartTask);
        mainHandler.removeCallbacks(zoomTutorialTask);
        mainHandler.removeCallbacks(updateVideoActionUiTask);
        dismissZoomTutorial();
        stopAiFrameSampling();
        removeTexturePoll();
        stopPreview("destroy-view");
        releaseSelectedVideoPlayer();
        cancelSelectedVideoInference(false);
        if (binding != null) {
            binding.textureVisionView.setSurfaceTextureListener(null);
        }
        super.onDestroyView();
    }

    private Runnable texturePollRunnable;
    private int texturePollAttempt;

    private void prepareNetworkAndStartStream() {
        if (selectedProcessVideo != null) {
            return;
        }
        Context ctx = getContext();
        if (ctx == null) {
            return;
        }
        Context appContext = ctx.getApplicationContext();
        new Thread(() -> {
            SystemSettingUtils.setCameraNetworkSegment();
            logCameraReachability(appContext);
            mainHandler.post(() -> {
                if (!isActive || binding == null || selectedProcessVideo != null) {
                    return;
                }
                networkPrepared = true;
                scheduleStartWhenTextureReady();
            });
        }, "ai-vision-network-setup").start();
    }

    private void logCameraReachability(Context context) {
        try {
            String host = CameraConfig.getCameraIp();
            boolean reachable = InetAddress.getByName(host).isReachable(1000);
            Log.i(TAG, "Camera host reachability host=" + host + " reachable=" + reachable);
        } catch (Exception e) {
            Log.w(TAG, "Camera host reachability check failed", e);
        }
    }

    private void scheduleStartWhenTextureReady() {
        if (selectedProcessVideo != null) {
            return;
        }
        texturePollAttempt = 0;
        removeTexturePoll();
        if (!isActive || binding == null) {
            return;
        }
        if (playerStopInProgress) {
            requestStartAfterPlayerStop("texture-ready");
            return;
        }
        TextureView tv = binding.textureVisionView;
        Runnable tryStart = () -> tryStartAfterSurfaceReady(tv);
        texturePollRunnable = tryStart;
        tv.post(tryStart);
    }

    private void removeTexturePoll() {
        if (texturePollRunnable != null && binding != null) {
            binding.textureVisionView.removeCallbacks(texturePollRunnable);
        }
        texturePollRunnable = null;
        texturePollAttempt = 0;
    }

    private void tryStartAfterSurfaceReady(TextureView tv) {
        texturePollRunnable = null;
        if (!isActive || binding == null) {
            return;
        }
        if (tv.isAvailable()) {
            Context ctx = getContext();
            if (ctx != null) {
                ensureLiveRtspCandidates(ctx);
                Log.i(TAG, "Surface ready, opening " + currentLiveRtspUrl(ctx));
            }
            ensurePlayerClient();
            startStream();
            return;
        }
        texturePollAttempt++;
        if (texturePollAttempt >= TEXTURE_POLL_MAX_ATTEMPTS) {
            String reason = getString(R.string.ai_vision_stream_failure_surface_unavailable);
            Log.w(TAG, "Surface not ready after wait; " + reason);
            recordPreStartFailure(reason);
            return;
        }
        texturePollRunnable = () -> tryStartAfterSurfaceReady(tv);
        tv.postDelayed(texturePollRunnable, TEXTURE_POLL_MS);
    }

    /** RTSP notifies EVENT with "Connecting…" etc.; MUST NOT trigger stop/retry. */
    private static boolean isBenignRtspEvent(@Nullable Bundle resultData) {
        if (resultData == null) {
            return true;
        }
        if (resultData.containsKey("errorcode")) {
            return false;
        }
        String msg = resultData.getString("event-msg");
        if (TextUtils.isEmpty(msg)) {
            return true;
        }
        return msg.contains("连接中") || msg.toLowerCase(Locale.US).contains("connect");
    }

    private void startStream() {
        if (!isActive || binding == null || selectedProcessVideo != null) {
            return;
        }
        if (playerStopInProgress) {
            requestStartAfterPlayerStop("start-stream");
            return;
        }
        if (liveStartAttemptCount >= MAX_START_ATTEMPT_COUNT) {
            Log.w(TAG, "RTSP start skipped: attempts exhausted " + liveStartAttemptCount
                    + "/" + MAX_START_ATTEMPT_COUNT
                    + " reason=" + lastStreamFailureReason);
            return;
        }
        ensurePlayerClient();
        if (playerClient == null) {
            recordPreStartFailure(getString(R.string.ai_vision_stream_failure_surface_unavailable));
            return;
        }
        mainHandler.removeCallbacks(reconnectTask);
        cancelFirstFrameTimeout();
        cancelHardwareFirstFrameTimeout();
        stopAiFrameSampling();
        if (streamStarted) {
            stopPreview("restart");
            requestStartAfterPlayerStop("restart");
            return;
        }
        binding.tvVideoStatus.setText(liveStartAttemptCount == 0
                ? R.string.live_video_loading
                : R.string.live_video_retry_hint);
        binding.tvVideoStatus.setVisibility(View.VISIBLE);
        Context ctx = getContext();
        if (ctx == null) {
            return;
        }
        ensureLiveRtspCandidates(ctx);
        String rtspUrl = currentLiveRtspUrl(ctx);
        int sessionId = openPreviewSession("start");
        liveRtspActiveUrl = rtspUrl;
        streamStartElapsedMs = SystemClock.elapsedRealtime();
        liveStartAttemptCount++;
        if (CameraConfig.isNativeAiVisionStreamDetectEnabled()) {
            Log.i(TAG, "duplicate_rtsp=ai_vision_preview playback=EasyPlayerClient"
                    + " detect=StreamDetectPipeline url=" + rtspUrl);
        }
        String user = CameraConfig.CAMERA_USER_NAME;
        String pass = CameraConfig.CAMERA_PASSWORD;
        if (MediaMtxRelayUrls.isMediamtxFanoutUrl(rtspUrl)) {
            user = "";
            pass = "";
        }
        Log.i(TAG, "RTSP start request url=" + rtspUrl
                + " transport=tcp"
                + " retryCount=" + retryCount
                + " startAttempt=" + liveStartAttemptCount + "/" + MAX_START_ATTEMPT_COUNT
                + " candidate=" + liveCandidateProgress()
                + " profile=" + liveProfileLabel(ctx, rtspUrl)
                + " session=" + sessionId);
        EasyPlayerClient client = playerClient;
        int code = client.start(
                rtspUrl,
                Client.TRANSTYPE_TCP,
                0,
                Client.EASY_SDK_VIDEO_FRAME_FLAG,
                user,
                pass);
        if (code != 0) {
            Log.e(TAG, "RTSP start failed, code=" + code);
            onStreamFailed(
                    sessionId,
                    getString(R.string.live_video_failed),
                    getString(R.string.ai_vision_stream_failure_start_code, code));
        } else {
            streamStarted = true;
            scheduleFirstFrameTimeout(sessionId);
            scheduleHardwareFirstFrameTimeoutIfNeeded(sessionId);
            Log.i(TAG, "RTSP start accepted code=0 session=" + sessionId);
        }
    }

    private void requestStartAfterPlayerStop(String reason) {
        if (!isActive || binding == null) {
            return;
        }
        boolean alreadyPending = startPendingAfterStop;
        startPendingAfterStop = true;
        mainHandler.removeCallbacks(deferredStartAfterStopTask);
        mainHandler.postDelayed(deferredStartAfterStopTask, STOP_PENDING_RETRY_MS);
        if (!alreadyPending) {
            Log.i(TAG, "RTSP start deferred until previous player stops reason=" + reason);
        }
    }

    private void stopPreview(String reason) {
        invalidatePreviewSession(reason);
        stopAiFrameSampling();
        stopPlayerAsync(reason);
    }

    private void stopPlayerAsync(String reason) {
        cancelFirstFrameTimeout();
        cancelHardwareFirstFrameTimeout();
        EasyPlayerClient client = playerClient;
        Surface surface = playerSurface;
        playerClient = null;
        playerSurface = null;
        streamStarted = false;
        refreshWorkInformationPanel();
        liveRtspActiveUrl = null;
        playerGeneration++;
        if (client == null) {
            if (surface != null) {
                surface.release();
            }
            return;
        }
        playerStopInProgress = true;
        new Thread(() -> {
            long start = SystemClock.elapsedRealtime();
            Log.i(TAG, "Stopping EasyPlayerClient asynchronously reason=" + reason);
            try {
                client.stop();
            } finally {
                if (surface != null) {
                    surface.release();
                }
                long elapsedMs = SystemClock.elapsedRealtime() - start;
                Log.i(TAG, "EasyPlayerClient stopped reason=" + reason
                        + " elapsedMs=" + elapsedMs);
                mainHandler.post(() -> onPlayerStopCompleted(reason, elapsedMs));
            }
        }, "ai-vision-player-stop").start();
    }

    private void onPlayerStopCompleted(String reason, long elapsedMs) {
        playerStopInProgress = false;
        if (!startPendingAfterStop || !isActive || binding == null) {
            startPendingAfterStop = false;
            return;
        }
        startPendingAfterStop = false;
        mainHandler.removeCallbacks(deferredStartAfterStopTask);
        Log.i(TAG, "Previous player stopped; resuming deferred RTSP start reason="
                + reason + " stopElapsedMs=" + elapsedMs);
        scheduleStartWhenTextureReady();
    }

    private void releasePlayerSurface(String reason) {
        Surface surface = playerSurface;
        playerSurface = null;
        if (surface == null) {
            return;
        }
        try {
            surface.release();
            Log.i(TAG, "Player surface released reason=" + reason);
        } catch (Throwable t) {
            Log.w(TAG, "Player surface release failed reason=" + reason, t);
        }
    }

    private static boolean isHardwareDecoderCoolingDown() {
        return hardwareDecoderCooldownRemainingMs() > 0L;
    }

    private static long hardwareDecoderCooldownRemainingMs() {
        return Math.max(0L, hardwareDecoderUnhealthyUntilElapsedMs - SystemClock.elapsedRealtime());
    }

    private static void markHardwareDecoderHealthy() {
        if (hardwareDecoderUnhealthyUntilElapsedMs != 0L) {
            Log.i(TAG, "Hardware decoder marked healthy; cooldown cleared");
        }
        hardwareDecoderUnhealthyUntilElapsedMs = 0L;
    }

    private static void markHardwareDecoderUnhealthy(String reason) {
        hardwareDecoderUnhealthyUntilElapsedMs =
                SystemClock.elapsedRealtime() + HARDWARE_DECODER_COOLDOWN_MS;
        Log.w(TAG, "Hardware decoder marked unhealthy reason=" + reason
                + " cooldownMs=" + HARDWARE_DECODER_COOLDOWN_MS);
    }

    private int openPreviewSession(String reason) {
        int sessionId = ++previewSessionId;
        activeStreamSessionId = sessionId;
        Log.i(TAG, "Preview session opened session=" + sessionId + " reason=" + reason);
        return sessionId;
    }

    private void invalidatePreviewSession(String reason) {
        if (activeStreamSessionId != 0) {
            Log.i(TAG, "Preview session invalidated session=" + activeStreamSessionId
                    + " reason=" + reason);
        }
        previewSessionId++;
        activeStreamSessionId = 0;
    }

    private boolean isCurrentStreamSession(int sessionId) {
        return sessionId != 0 && sessionId == activeStreamSessionId && sessionId == previewSessionId;
    }

    private void scheduleFirstFrameTimeout(int sessionId) {
        cancelFirstFrameTimeout();
        firstFrameTimeoutTask = () -> handleFirstFrameTimeout(sessionId);
        mainHandler.postDelayed(firstFrameTimeoutTask, FIRST_FRAME_TIMEOUT_MS);
    }

    private void cancelFirstFrameTimeout() {
        if (firstFrameTimeoutTask != null) {
            mainHandler.removeCallbacks(firstFrameTimeoutTask);
            firstFrameTimeoutTask = null;
        }
    }

    private void scheduleHardwareFirstFrameTimeoutIfNeeded(int sessionId) {
        cancelHardwareFirstFrameTimeout();
        if (currentStreamPreferSoftwareDecoder) {
            return;
        }
        hardwareFirstFrameTimeoutTask = () -> handleHardwareFirstFrameTimeout(sessionId);
        mainHandler.postDelayed(hardwareFirstFrameTimeoutTask, HARDWARE_FIRST_FRAME_TIMEOUT_MS);
    }

    private void cancelHardwareFirstFrameTimeout() {
        if (hardwareFirstFrameTimeoutTask != null) {
            mainHandler.removeCallbacks(hardwareFirstFrameTimeoutTask);
            hardwareFirstFrameTimeoutTask = null;
        }
    }

    private void handleHardwareFirstFrameTimeout(int sessionId) {
        if (!isCurrentStreamSession(sessionId)) {
            Log.i(TAG, "Ignore hardware first-frame timeout from stale session=" + sessionId
                    + " current=" + activeStreamSessionId);
            return;
        }
        if (!isActive || binding == null || playerClient == null || !streamStarted) {
            return;
        }
        long elapsedMs = streamStartElapsedMs == 0L
                ? -1L
                : SystemClock.elapsedRealtime() - streamStartElapsedMs;
        markHardwareDecoderUnhealthy("hardware-first-frame-timeout");
        lastStreamFailureReason = getString(
                R.string.ai_vision_stream_failure_first_frame_timeout,
                elapsedMs);
        binding.tvVideoStatus.setText(R.string.live_video_retry_hint);
        binding.tvVideoStatus.setVisibility(View.VISIBLE);
        Log.w(TAG, "Hardware decoder first-frame timeout elapsedMs=" + elapsedMs
                + " session=" + sessionId
                + " cooldownMs=" + HARDWARE_DECODER_COOLDOWN_MS
                + " retryWithSoftware=true");
        invalidatePreviewSession("hardware-first-frame-timeout");
        stopPlayerAsync("hardware-first-frame-timeout");
        mainHandler.removeCallbacks(deferredStartAfterStopTask);
        mainHandler.postDelayed(deferredStartAfterStopTask, STOP_PENDING_RETRY_MS);
    }

    private void handleFirstFrameTimeout(int sessionId) {
        if (!isCurrentStreamSession(sessionId)) {
            Log.i(TAG, "Ignore first-frame timeout from stale session=" + sessionId
                    + " current=" + activeStreamSessionId);
            return;
        }
        if (!isActive || binding == null || playerClient == null || !streamStarted) {
            return;
        }
        long elapsedMs = streamStartElapsedMs == 0L
                ? -1L
                : SystemClock.elapsedRealtime() - streamStartElapsedMs;
        Log.w(TAG, "LIVE_FIRST_FRAME_TIMEOUT elapsedMs=" + elapsedMs
                + " url=" + liveRtspActiveUrl
                + " candidate=" + liveCandidateProgress()
                + " retryCount=" + retryCount
                + " session=" + sessionId);
        onStreamFailed(
                sessionId,
                getString(R.string.live_video_retry_hint),
                getString(R.string.ai_vision_stream_failure_first_frame_timeout, elapsedMs));
    }

    private void scheduleAiFrameSampling() {
        mainHandler.removeCallbacks(liveInferenceOverlayTask);
        if (!isActive || binding == null) {
            return;
        }
        if (!CameraConfig.isNativeAiVisionStreamDetectEnabled()) {
            return;
        }
        Context ctx = getContext();
        AiManager manager = AiManager.getInstance();
        if (ctx != null
                && selectedProcessVideo == null
                && streamStarted
                && isLiveInferSchedulingEnabled(manager)) {
            NativeStreamDetectCoordinator.getInstance().acquireAiVisionLive(ctx);
            mainHandler.post(liveInferenceOverlayTask);
        }
    }

    private void stopAiFrameSampling() {
        mainHandler.removeCallbacks(liveInferenceOverlayTask);
        if (CameraConfig.isNativeAiVisionStreamDetectEnabled()) {
            NativeStreamDetectCoordinator.getInstance().releaseAiVisionLive("preview_stopped");
        }
        AiManager.getInstance().resetRknnAiVisionLiveFrameSampling();
        AiManager.getInstance().resetOpencvAiVisionLiveFrameSampling();
    }

    private void recordPreStartFailure(String reason) {
        if (liveStartAttemptCount < MAX_START_ATTEMPT_COUNT) {
            liveStartAttemptCount++;
        }
        onStreamFailed(getString(R.string.live_video_failed), reason);
    }

    private void onStreamFailed(String statusText, String reason) {
        onStreamFailed(0, statusText, reason);
    }

    private void onStreamFailed(int sessionId, String statusText, String reason) {
        if (!isActive || binding == null) {
            return;
        }
        if (sessionId != 0 && !isCurrentStreamSession(sessionId)) {
            Log.i(TAG, "Ignore stream failure from stale session=" + sessionId
                    + " current=" + activeStreamSessionId
                    + " reason=" + reason);
            return;
        }
        cancelFirstFrameTimeout();
        cancelHardwareFirstFrameTimeout();
        boolean shouldStopPlayer = playerClient != null || streamStarted;
        if (sessionId != 0) {
            invalidatePreviewSession("stream-failed");
        }
        lastStreamFailureReason = TextUtils.isEmpty(reason)
                ? getString(R.string.ai_vision_stream_failure_unknown)
                : reason;
        binding.tvVideoStatus.setText(statusText);
        binding.tvVideoStatus.setVisibility(View.VISIBLE);
        Log.w(TAG, "RTSP attempt failed attempt=" + liveStartAttemptCount
                + "/" + MAX_START_ATTEMPT_COUNT
                + " reason=" + lastStreamFailureReason
                + " candidate=" + liveCandidateProgress()
                + " url=" + liveRtspActiveUrl);
        if (liveStartAttemptCount >= MAX_START_ATTEMPT_COUNT) {
            Log.w(TAG, "RTSP start attempts exhausted: " + liveStartAttemptCount);
            mainHandler.removeCallbacks(reconnectTask);
            mainHandler.removeCallbacks(deferredStartAfterStopTask);
            removeTexturePoll();
            startPendingAfterStop = false;
            if (shouldStopPlayer) {
                stopPreview("attempts-exhausted");
            }
            return;
        }
        if (shouldStopPlayer) {
            stopPreview("attempt-failed");
        }
        if (liveRtspCandidateIndex + 1 < liveRtspCandidates.size()) {
            liveRtspCandidateIndex++;
            String next = liveRtspCandidates.get(liveRtspCandidateIndex);
            Context ctx = getContext();
            Log.w(TAG, "LIVE_RTSP_FALLBACK reason=prior_candidate_failed next="
                    + next
                    + " attempt=" + liveCandidateProgress()
                    + " profile=" + liveProfileLabel(ctx, next));
            mainHandler.removeCallbacks(reconnectTask);
            mainHandler.removeCallbacks(deferredStartAfterStopTask);
            mainHandler.postDelayed(deferredStartAfterStopTask, 300L);
            return;
        }
        retryCount++;
        mainHandler.removeCallbacks(reconnectTask);
        mainHandler.removeCallbacks(deferredStartAfterStopTask);
        mainHandler.postDelayed(deferredStartAfterStopTask, RECONNECT_DELAY_MS);
    }

    private void ensureLiveRtspCandidates(Context context) {
        if (!liveRtspCandidates.isEmpty()) {
            return;
        }
        boolean localRelay = MediaMtxRelayCoordinator.getInstance().isRelayReady();
        liveRtspCandidates.addAll(CameraConfig.getPr1IngestCandidates(localRelay));
        if (!CameraConfig.isNativeAiVisionStreamDetectEnabled()) {
            for (String fallback : CameraConfig.getPr0IngestCandidates(localRelay)) {
                if (!liveRtspCandidates.contains(fallback)) {
                    liveRtspCandidates.add(fallback);
                }
            }
        }
        liveRtspCandidateIndex = 0;
        String policy = CameraConfig.isNativeAiVisionStreamDetectEnabled()
                ? "dual_link_pr1"
                : "sub_then_main";
        String firstUrl = liveRtspCandidates.isEmpty() ? "" : liveRtspCandidates.get(0);
        Log.i(TAG, "LIVE_RTSP_POLICY policy=" + policy
                + " candidates=" + liveRtspCandidates.size()
                + " sub=" + CameraConfig.CAMERA_RTSP_SUB_PATH);
        AiVisionResolutionProfileLog.logDetectPolicy(
                CameraConfig.isNativeWeldStreamDetectEnabled() ? "on" : "off",
                CameraConfig.isNativeAiVisionStreamDetectEnabled() ? "on" : "off",
                CameraConfig.isAiVisionLiveDetectOverlayEnabled() ? "on" : "off");
        AiVisionResolutionProfileLog.logLiveRtspPolicy(
                policy, liveRtspCandidates.size(), firstUrl);
    }

    private String currentLiveRtspUrl(Context context) {
        if (liveRtspCandidates.isEmpty()) {
            ensureLiveRtspCandidates(context);
        }
        if (liveRtspCandidates.isEmpty()) {
            return CameraConfig.getCameraRtspMainUrl();
        }
        int safeIndex = Math.max(0, Math.min(liveRtspCandidateIndex, liveRtspCandidates.size() - 1));
        return liveRtspCandidates.get(safeIndex);
    }

    private String liveCandidateProgress() {
        int n = liveRtspCandidates.size();
        if (n <= 0) {
            return "0/0";
        }
        return (liveRtspCandidateIndex + 1) + "/" + n;
    }

    private static String rtspPathOnly(@Nullable String rtspUrl) {
        if (TextUtils.isEmpty(rtspUrl)) {
            return "";
        }
        int schemeIdx = rtspUrl.indexOf("://");
        String path;
        if (schemeIdx < 0) {
            path = rtspUrl.trim();
        } else {
            int pathIdx = rtspUrl.indexOf('/', schemeIdx + 3);
            path = pathIdx < 0 ? "/" : rtspUrl.substring(pathIdx);
        }
        int q = path.indexOf('?');
        if (q >= 0) {
            path = path.substring(0, q);
        }
        return path;
    }

    private static String liveProfileLabel(@Nullable Context ctx, @Nullable String rtspUrl) {
        if (ctx == null || TextUtils.isEmpty(rtspUrl)) {
            return "unknown";
        }
        String path = rtspPathOnly(rtspUrl);
        String subPath = CameraConfig.CAMERA_RTSP_SUB_PATH;
        String mainPath = CameraConfig.CAMERA_RTSP_MAIN_PATH;
        if (path.contains(MediaMtxRelayUrls.PATH_PR1) || path.equals(subPath)) {
            return "sub";
        }
        if (path.equals(mainPath)) {
            return "main";
        }
        return "other";
    }

    private void restoreLastSelectedProcessVideo() {
        if (processVideoViewModel == null || getContext() == null) {
            showNoSelectedVideoState(false);
            return;
        }
        long rowId = aiVisionPrefs(requireContext())
                .getLong(PREF_LAST_SELECTED_PROCESS_VIDEO_ROW_ID, 0L);
        if (rowId <= 0L) {
            showNoSelectedVideoState(false);
            return;
        }
        processVideoViewModel.selectById(rowId, row -> handler.post(() -> {
            if (binding == null) {
                return;
            }
            if (row == null || row.getId() <= 0L || !isUsableProcessVideo(row)) {
                clearLastSelectedProcessVideo();
                showNoSelectedVideoState(true);
                return;
            }
            applySelectedProcessVideo(toProcessParamsVideoVo(row), false);
        }));
    }

    private boolean isUsableProcessVideo(ProcessParamsVideo row) {
        String videoPath = row.getVideoPath();
        if (TextUtils.isEmpty(videoPath)) {
            return false;
        }
        File file = new File(videoPath.trim()).getAbsoluteFile();
        return file.exists() && file.length() > 0L;
    }

    private void showNoSelectedVideoState(boolean releaseCurrentWork) {
        selectedProcessVideo = null;
        lastAppliedProcessVideoRowId = 0L;
        sourcePlaybackReachedEos = false;
        replayingDetectionOverlay = false;
        selectedVideoUiMode = SelectedVideoUiMode.PROMPT_SELECT;
        offlineInferenceProgressVisible = false;
        if (releaseCurrentWork) {
            releaseSelectedVideoPlayer();
            cancelSelectedVideoInference(true);
        } else {
            clearOfflineInferenceOverlay();
        }
        clearAiVisionInfoValues();
        showSelectedVideoStatus(R.string.ai_vision_select_video_first);
        hideVideoCover();
        clearReplayTimelineState();
        updateVideoActionUi();
        if (isActive && selectedProcessVideo == null) {
            prepareNetworkAndStartStream();
        }
    }

    private void clearAiVisionInfoValues() {
        if (binding == null) {
            return;
        }
        applyWorkInformationDisplay(AiVisionWorkInfoLabels.unavailable());
        binding.tvRecordingTimeValue.setText("");
    }

    private void applyWorkInformationDisplay(@NonNull AiVisionWorkInfoLabels.Display display) {
        if (binding == null) {
            return;
        }
        binding.tvProcessTypeValue.setText(display.processType);
        binding.tvMaterialTypeValue.setText(display.materialType);
    }

    private boolean shouldBindWorkInfoFromLiveSnapshot() {
        return streamStarted && isActive && !isProcessVideoDetectSessionActive();
    }

    private void refreshWorkInformationPanel() {
        if (binding == null) {
            return;
        }
        if (shouldBindWorkInfoFromLiveSnapshot()) {
            applyWorkInformationDisplay(
                    AiVisionWorkInfoLabels.fromSnapshot(ProcessParametersSnapshotStore.getSnapshot()));
            return;
        }
        if (selectedProcessVideo != null) {
            applyWorkInformationDisplay(AiVisionWorkInfoLabels.fromVideo(selectedProcessVideo));
            return;
        }
        applyWorkInformationDisplay(AiVisionWorkInfoLabels.unavailable());
    }

    private void persistLastSelectedProcessVideo(ProcessParamsVideoVo processVideo) {
        Context ctx = getContext();
        if (ctx == null || processVideo == null || processVideo.getId() <= 0L) {
            return;
        }
        aiVisionPrefs(ctx).edit()
                .putLong(PREF_LAST_SELECTED_PROCESS_VIDEO_ROW_ID, processVideo.getId())
                .apply();
    }

    private void clearLastSelectedProcessVideo() {
        Context ctx = getContext();
        if (ctx == null) {
            return;
        }
        aiVisionPrefs(ctx).edit()
                .remove(PREF_LAST_SELECTED_PROCESS_VIDEO_ROW_ID)
                .apply();
    }

    private static ProcessParamsVideoVo toProcessParamsVideoVo(ProcessParamsVideo row) {
        ProcessParamsVideoVo vo = new ProcessParamsVideoVo();
        vo.setId(row.getId());
        vo.setVideoPath(row.getVideoPath());
        vo.setProcessType(row.getProcessType());
        vo.setMaterialType(row.getMaterialType());
        vo.setProcessParametersJson(row.getProcessParametersJson());
        vo.setFileSize(row.getFileSize());
        vo.setDuration(row.getDuration());
        vo.setCreateTime(row.getCreateTime());
        vo.setVideoId(row.getVideoId());
        vo.setResolution(row.getResolution());
        vo.setUploadStatus(row.getUploadStatus());
        vo.setUploadProgress(row.getUploadProgress());
        vo.setCoverUrl(row.getCoverUrl());
        vo.setVideoUrl(row.getVideoUrl());
        return vo;
    }

    private boolean isSelectedVideoPlaybackEnded() {
        if (isProcessVideoDetectSessionActive()) {
            return sourcePlaybackReachedEos;
        }
        if (selectedVideoAiSession != null
                && selectedVideoAiSession.isRunning()
                && !replayingDetectionOverlay) {
            return sourcePlaybackReachedEos;
        }
        return selectedVideoPlayer != null
                && selectedVideoPlayer.getPlaybackState() == Player.STATE_ENDED;
    }

    @Nullable
    private File resolvePersistedTimelineFile(@Nullable ProcessParamsVideoVo processVideo) {
        if (processVideo == null || getContext() == null) {
            return null;
        }
        File sourceVideo = resolveSelectedProcessVideoFile(processVideo);
        if (!isUsableFile(sourceVideo)) {
            return null;
        }
        String cacheKey = buildInferenceCacheKey(processVideo, sourceVideo);
        return ProcessVideoAiInferencePaths.inferenceTimelineJson(
                requireContext().getApplicationContext(),
                processVideo,
                cacheKey);
    }

    private boolean hasReplayTimelineAvailable() {
        if (selectedVideoAiSession != null && !selectedVideoAiSession.getTimeline().snapshotFrames().isEmpty()) {
            return true;
        }
        File timelineFile = resolvePersistedTimelineFile(selectedProcessVideo);
        return ProcessVideoAiTimelinePersistence.hasReplayData(timelineFile);
    }

    @Nullable
    private ProcessVideoAiTimelinePersistence.LoadedTimeline loadReplayTimelineIfNeeded(boolean forceReload) {
        if (!forceReload && replayTimeline != null) {
            return new ProcessVideoAiTimelinePersistence.LoadedTimeline(
                    replayTimeline, replayClassificationLine);
        }
        if (selectedVideoAiSession != null && !selectedVideoAiSession.getTimeline().snapshotFrames().isEmpty()) {
            replayTimeline = null;
            replayClassificationLine = selectedVideoAiSession.getClassificationLine();
            return null;
        }
        File timelineFile = resolvePersistedTimelineFile(selectedProcessVideo);
        if (timelineFile == null) {
            return null;
        }
        ProcessVideoAiTimelinePersistence.LoadedTimeline loaded =
                ProcessVideoAiTimelinePersistence.load(timelineFile);
        if (loaded == null) {
            replayTimeline = null;
            replayClassificationLine = null;
            return null;
        }
        replayTimeline = loaded.timeline;
        replayClassificationLine = loaded.classificationLine;
        return loaded;
    }

    private void clearReplayTimelineState() {
        replayTimeline = null;
        replayClassificationLine = null;
    }

    private void refreshReplayTimelineFromDisk() {
        replayTimeline = null;
        loadReplayTimelineIfNeeded(true);
    }

    @Nullable
    private ProcessVideoAiTimeline resolvePlaybackTimeline() {
        if (selectedVideoAiSession != null) {
            return selectedVideoAiSession.getTimeline();
        }
        if (replayTimeline != null) {
            return replayTimeline;
        }
        loadReplayTimelineIfNeeded(false);
        return replayTimeline;
    }

    private boolean isPlayingSourceRecording() {
        if (selectedProcessVideo == null || TextUtils.isEmpty(selectedVideoPlaybackPath)) {
            return true;
        }
        File source = resolveSelectedProcessVideoFile(selectedProcessVideo);
        return source != null
                && selectedVideoPlaybackPath.equals(source.getAbsolutePath());
    }

    /**
     * True when a selected process video is known playable without disk I/O on the main thread.
     * During active ExoPlayer playback {@link #selectedVideoPlaybackPath} is already validated.
     */
    private boolean hasUsableSelectedVideoSource() {
        if (selectedProcessVideo == null) {
            return false;
        }
        if (!TextUtils.isEmpty(selectedVideoPlaybackPath)) {
            return true;
        }
        return isUsableFile(resolveSelectedProcessVideoFile(selectedProcessVideo));
    }

    /** Coalesced UI refresh; safe to call from ExoPlayer listener callbacks. */
    private void postUpdateVideoActionUi() {
        mainHandler.removeCallbacks(updateVideoActionUiTask);
        mainHandler.post(updateVideoActionUiTask);
    }

    private void updateVideoActionUi() {
        updateVideoActionUiInternal();
    }

    private void updateVideoActionUiInternal() {
        if (binding == null || updatingVideoActionUi) {
            return;
        }
        updatingVideoActionUi = true;
        try {
            applyVideoActionUiLocked();
        } finally {
            updatingVideoActionUi = false;
        }
    }

    private void applyVideoActionUiLocked() {
        if (binding == null) {
            return;
        }
        binding.btnDetectVideo.setVisibility(View.GONE);
        binding.layoutPostEosActions.setVisibility(View.GONE);
        switch (selectedVideoUiMode) {
            case PROMPT_SELECT:
                hideVideoCover();
                showSelectedVideoStatus(R.string.ai_vision_select_video_first);
                break;
            case IDLE_READY_TO_DETECT:
                hideSelectedVideoStatus();
                binding.btnDetectVideo.setVisibility(View.VISIBLE);
                binding.btnDetectVideo.setEnabled(!isOfflineInferenceInProgress());
                hideSelectedVideoControl();
                break;
            case IDLE_DETECTION_COMPLETE:
                hideSelectedVideoStatus();
                binding.layoutPostEosActions.setVisibility(View.VISIBLE);
                binding.btnReplayInferenceVideo.setEnabled(hasReplayTimelineAvailable());
                binding.btnRedetectVideo.setEnabled(!isOfflineInferenceInProgress());
                hideSelectedVideoControl();
                break;
            case PLAYBACK:
                hideSelectedVideoStatus();
                updatePostEosPlaybackActions();
                break;
            default:
                break;
        }
        updateSelectedVideoPlayPauseButton();
    }

    /** Replay / Re-detect while source playback is active and has reached EOS. */
    private void updatePostEosPlaybackActions() {
        if (binding == null || selectedVideoUiMode != SelectedVideoUiMode.PLAYBACK) {
            return;
        }
        boolean hasVideo = hasUsableSelectedVideoSource();
        boolean busy = isOfflineInferenceInProgress();
        boolean showPostEosActions = hasVideo && sourcePlaybackReachedEos && !selectedVideoPlaybackFailed;
        binding.layoutPostEosActions.setVisibility(showPostEosActions ? View.VISIBLE : View.GONE);
        binding.btnReplayInferenceVideo.setEnabled(showPostEosActions && hasReplayTimelineAvailable());
        binding.btnRedetectVideo.setEnabled(showPostEosActions && !busy);
        if (showPostEosActions) {
            hideSelectedVideoControl();
        }
    }

    private void onProcessVideoAiSessionFinalized(@NonNull ProcessVideoAiSession session, boolean timelineReady) {
        if (binding == null || session != selectedVideoAiSession) {
            return;
        }
        if (timelineReady) {
            activeInferenceCacheKey = session.getCacheKey();
            refreshReplayTimelineFromDisk();
        }
        if (sourcePlaybackReachedEos) {
            if (timelineReady && selectedVideoUiMode == SelectedVideoUiMode.PLAYBACK) {
                selectedVideoUiMode = SelectedVideoUiMode.IDLE_DETECTION_COMPLETE;
                stopProcessVideoDetectPlayback();
                File sourceVideo = resolveSelectedProcessVideoFile(selectedProcessVideo);
                if (isUsableFile(sourceVideo)) {
                    loadSelectedVideoCover(sourceVideo);
                }
            }
            if (timelineReady) {
                applyTemporalSummaryOverlayOnCover();
            }
            updateVideoActionUi();
        }
    }

    private void applyTemporalSummaryOverlayOnCover() {
        if (binding == null || isLiveRtspOverlayActive()) {
            return;
        }
        ProcessVideoAiTimeline timeline = resolvePlaybackTimeline();
        if (timeline == null) {
            showSelectedVideoOverlayIdleStatus();
            return;
        }
        ProcessVideoAiTimeline.Frame summary = timeline.findTemporalSummaryFrame();
        if (summary == null) {
            showSelectedVideoOverlayIdleStatus();
            return;
        }
        List<DetectionOverlayView.Box> boxes = new ArrayList<>();
        if (summary.hasDetection()) {
            boxes.addAll(summary.toOverlayBoxes());
        }
        String status = pickTimelineOverlayStatus(summary);
        String message = pickTimelineOverlayMessage(summary);
        applyDetectionOverlay(boxes, status, message, false, summary);
    }

    @Nullable
    private ProcessVideoAiTimeline.Frame resolveRecordedVideoBoxFrame(
            @Nullable ProcessVideoAiTimeline timeline,
            long positionMs) {
        if (timeline == null) {
            return null;
        }
        ProcessVideoAiTimeline.Frame summary = timeline.findTemporalSummaryFrame();
        if (summary != null && !isProcessVideoDetectSessionActive()) {
            if (!summary.hasDetection()) {
                return null;
            }
            if (replayingDetectionOverlay) {
                if (positionMs >= summary.timeMs) {
                    return summary;
                }
                return frameWithDetectionAt(timeline, positionMs);
            }
            if (sourcePlaybackReachedEos) {
                return summary;
            }
        }
        return frameWithDetectionAt(timeline, positionMs);
    }

    @Nullable
    private static ProcessVideoAiTimeline.Frame frameWithDetectionAt(
            @NonNull ProcessVideoAiTimeline timeline,
            long positionMs) {
        ProcessVideoAiTimeline.Frame at = timeline.findFrameAt(positionMs);
        if (at == null || at.temporalSummary || !at.hasDetection()) {
            return null;
        }
        return at;
    }

    @Nullable
    private ProcessVideoAiTimeline.Frame resolveRecordedVideoStatusFrame(
            @Nullable ProcessVideoAiTimeline timeline,
            long positionMs) {
        if (timeline == null) {
            return null;
        }
        if (!isProcessVideoDetectSessionActive()) {
            ProcessVideoAiTimeline.Frame summary = timeline.findTemporalSummaryFrame();
            if (summary != null && (replayingDetectionOverlay || sourcePlaybackReachedEos)) {
                if (replayingDetectionOverlay && positionMs < summary.timeMs) {
                    return timeline.findFrameAt(positionMs);
                }
                return summary;
            }
        }
        return timeline.findFrameAt(positionMs);
    }

    private void handleSourcePlaybackEnded() {
        if (binding == null
                || selectedVideoPlayer == null
                || sourcePlaybackReachedEos
                || replayingDetectionOverlay
                || !isPlayingSourceRecording()) {
            return;
        }
        sourcePlaybackReachedEos = true;
        selectedVideoPlayer.setPlayWhenReady(false);
        selectedVideoPlayer.pause();
        stopSelectedVideoPlaybackTicks();
        mainHandler.removeCallbacks(offlineInferenceOverlayTask);
        if (selectedVideoAiSession != null) {
            selectedVideoAiSession.onPlaybackEnded();
            activeInferenceCacheKey = selectedVideoAiSession.getCacheKey();
            refreshReplayTimelineFromDisk();
        }
        postUpdateVideoActionUi();
    }

    private void onCompositedDetectPlaybackEnded(@NonNull ProcessVideoAiSession session) {
        if (binding == null || session != selectedVideoAiSession || sourcePlaybackReachedEos) {
            return;
        }
        handleCompositedDetectPlaybackEnded();
    }

    private void handleCompositedDetectPlaybackEnded() {
        sourcePlaybackReachedEos = true;
        stopSelectedVideoPlaybackTicks();
        mainHandler.removeCallbacks(offlineInferenceOverlayTask);
        releaseExoPlayerOnly();
        clearOfflineInferenceOverlay();
        selectedVideoUiMode = SelectedVideoUiMode.IDLE_DETECTION_COMPLETE;
        refreshReplayTimelineFromDisk();
        File sourceVideo = resolveSelectedProcessVideoFile(selectedProcessVideo);
        if (isUsableFile(sourceVideo)) {
            loadSelectedVideoCover(sourceVideo);
        }
        postUpdateVideoActionUi();
    }

    /** Runs on the main looper after ExoPlayer ENDED; must not run inside player listener stack. */
    private void finishInferenceReplayPlayback() {
        if (binding == null || selectedVideoPlayer == null || !replayingDetectionOverlay) {
            return;
        }
        replayingDetectionOverlay = false;
        sourcePlaybackReachedEos = true;
        selectedVideoUiMode = SelectedVideoUiMode.IDLE_DETECTION_COMPLETE;
        mainHandler.removeCallbacks(offlineInferenceOverlayTask);
        clearOfflineInferenceOverlay();
        selectedVideoPlayer.setPlayWhenReady(false);
        selectedVideoPlayer.pause();
        releaseExoPlayerOnly();
        File sourceVideo = resolveSelectedProcessVideoFile(selectedProcessVideo);
        if (isUsableFile(sourceVideo)) {
            loadSelectedVideoCover(sourceVideo);
        }
        postUpdateVideoActionUi();
    }

    private boolean isProcessVideoDetectSessionActive() {
        return selectedVideoAiSession != null
                && selectedVideoAiSession.isRunning()
                && !replayingDetectionOverlay;
    }

    private void stopProcessVideoDetectPlayback() {
        // ExoPlayer released separately via releaseExoPlayerOnly / releaseSelectedVideoPlayer.
    }

    private void startProcessVideoDetectPlayback() {
        if (binding == null || selectedProcessVideo == null) {
            return;
        }
        clearOfflineInferenceOverlay();
        hideVideoCover();
        selectedVideoPausedByUser = false;
        // Playback (ExoPlayer) and inference (ProcessVideoAiSession + MediaMetadataRetriever) are
        // independent — same split as GET /stream + GET /ai on the HTTP path.
        playSelectedProcessVideo();
        startSelectedVideoPlaybackTicks();
        mainHandler.post(offlineInferenceOverlayTask);
    }

    private void hidePostEosActions() {
        if (binding != null) {
            binding.layoutPostEosActions.setVisibility(View.GONE);
        }
    }

    private void hideIdleDetectAction() {
        if (binding != null) {
            binding.btnDetectVideo.setVisibility(View.GONE);
        }
    }

    private void presentIdleStateForSelectedVideo() {
        if (binding == null || selectedProcessVideo == null) {
            showNoSelectedVideoState(false);
            return;
        }
        File sourceVideo = resolveSelectedProcessVideoFile(selectedProcessVideo);
        if (!isUsableFile(sourceVideo)) {
            clearLastSelectedProcessVideo();
            showNoSelectedVideoState(true);
            return;
        }
        cancelSelectedVideoInference(false);
        stopProcessVideoDetectPlayback();
        releaseExoPlayerOnly();
        replayingDetectionOverlay = false;
        clearOfflineInferenceOverlay();
        activeInferenceCacheKey = buildInferenceCacheKey(selectedProcessVideo, sourceVideo);
        refreshReplayTimelineFromDisk();
        if (hasReplayTimelineAvailable()) {
            sourcePlaybackReachedEos = true;
            selectedVideoUiMode = SelectedVideoUiMode.IDLE_DETECTION_COMPLETE;
        } else {
            clearReplayTimelineState();
            sourcePlaybackReachedEos = false;
            selectedVideoUiMode = SelectedVideoUiMode.IDLE_READY_TO_DETECT;
        }
        loadSelectedVideoCover(sourceVideo);
        updateVideoActionUi();
    }

    private void startDetectionForSelectedVideo() {
        if (selectedProcessVideo == null) {
            ToastUtils.showShort(R.string.ai_vision_select_video_first);
            return;
        }
        if (isOfflineInferenceInProgress()) {
            return;
        }
        startSelectedVideoOfflineInference(false);
    }

    private void loadSelectedVideoCover(@NonNull File videoFile) {
        if (binding == null) {
            return;
        }
        final int generation = ++coverLoadGeneration;
        binding.ivSelectedVideoCover.setVisibility(View.VISIBLE);
        binding.playerAiSelectedVideoView.setVisibility(View.INVISIBLE);
        ThreadPoolManager.getExecutor().execute(() -> {
            Bitmap cover = null;
            try {
                cover = VideoCoverExtractor.probeVideoFile(videoFile).coverBitmap;
            } catch (Exception e) {
                Log.w(TAG, "AI Vision cover load failed path=" + videoFile.getAbsolutePath(), e);
            }
            final Bitmap coverBitmap = cover;
            handler.post(() -> {
                if (binding == null || generation != coverLoadGeneration) {
                    recycleCoverBitmapIfNotDisplayed(coverBitmap);
                    return;
                }
                clearDisplayedCoverBitmap();
                binding.ivSelectedVideoCover.setImageBitmap(coverBitmap);
            });
        });
    }

    private void recycleCoverBitmapIfNotDisplayed(@Nullable Bitmap bitmap) {
        if (bitmap == null || bitmap.isRecycled()) {
            return;
        }
        if (binding != null) {
            Drawable drawable = binding.ivSelectedVideoCover.getDrawable();
            if (drawable instanceof BitmapDrawable
                    && ((BitmapDrawable) drawable).getBitmap() == bitmap) {
                return;
            }
        }
        bitmap.recycle();
    }

    private void clearDisplayedCoverBitmap() {
        if (binding == null) {
            return;
        }
        Drawable drawable = binding.ivSelectedVideoCover.getDrawable();
        binding.ivSelectedVideoCover.setImageDrawable(null);
        if (drawable instanceof BitmapDrawable) {
            Bitmap bitmap = ((BitmapDrawable) drawable).getBitmap();
            if (bitmap != null && !bitmap.isRecycled()) {
                bitmap.recycle();
            }
        }
    }

    private void hideVideoCover() {
        coverLoadGeneration++;
        if (binding == null) {
            return;
        }
        clearDisplayedCoverBitmap();
        binding.ivSelectedVideoCover.setVisibility(View.GONE);
        binding.playerAiSelectedVideoView.setVisibility(View.VISIBLE);
    }

    private void applySelectedProcessVideo(ProcessParamsVideoVo processVideo) {
        applySelectedProcessVideo(processVideo, false);
    }

    private void applySelectedProcessVideo(ProcessParamsVideoVo processVideo, boolean forceInference) {
        stopPreview("process-video-selected");
        selectedProcessVideo = processVideo;
        if (binding == null || processVideo == null) {
            return;
        }
        long rowId = processVideo.getId();
        lastAppliedProcessVideoRowId = rowId;
        selectedVideoPausedByUser = false;
        selectedVideoPlaybackFailed = false;
        sourcePlaybackReachedEos = false;
        replayingDetectionOverlay = false;
        persistLastSelectedProcessVideo(processVideo);
        Long createTime = processVideo.getCreateTime();
        binding.tvRecordingTimeValue.setText(createTime == null
                ? ""
                : TimeUtils.date2String(new Date(createTime), "yyyy-MM-dd HH:mm"));
        refreshWorkInformationPanel();
        clearReplayTimelineState();
        if (forceInference) {
            startSelectedVideoOfflineInference(true);
            return;
        }
        presentIdleStateForSelectedVideo();
    }

    /** Re-entering the tab while a live detection session is still active. */
    private void syncSelectedVideoPlaybackAfterReapply() {
        selectedVideoUiMode = SelectedVideoUiMode.PLAYBACK;
        hideVideoCover();
        hideIdleDetectAction();
        if (selectedVideoAiSession != null) {
            selectedVideoAiSession.setOnPlaybackEndedListener(this::onCompositedDetectPlaybackEnded);
            selectedVideoAiSession.setOnTimelineFrameListener(this::onProcessVideoTimelineFrame);
            startProcessVideoDetectPlayback();
        }
        updateVideoActionUi();
    }

    private void startSelectedVideoOfflineInference() {
        startSelectedVideoOfflineInference(false);
    }

    private void startSelectedVideoOfflineInference(boolean forceReinfer) {
        if (binding == null || selectedProcessVideo == null) {
            return;
        }
        ProcessParamsVideoVo processVideo = selectedProcessVideo;
        String videoPath = processVideo.getVideoPath();
        if (TextUtils.isEmpty(videoPath)) {
            showSelectedVideoStatus(R.string.video_loading_failed_text);
            ToastUtils.showShort(R.string.video_loading_failed_text);
            return;
        }
        File file = new File(videoPath.trim()).getAbsoluteFile();
        if (!file.exists() || file.length() == 0L) {
            showSelectedVideoStatus(R.string.video_loading_failed_text);
            ToastUtils.showShort(R.string.video_loading_failed_text);
            return;
        }
        Context context = getContext();
        if (context == null) {
            return;
        }
        if (StoragePermissionHelper.shouldRequestRuntimeVideoRead(context)) {
            requestVideoReadPerm.launch(StoragePermissionHelper.videoReadPermissions());
            return;
        }
        cancelSelectedVideoInference(true);
        ensureAiEngineForProcessVideo(context);
        ProcessVideoAiSessionRegistry.AcquireResult acquireResult =
                ProcessVideoAiSessionRegistry.getInstance().acquireResult(
                        context.getApplicationContext(),
                        processVideo,
                        file,
                        forceReinfer,
                        ProcessVideoAiSessionRegistry.Holder.UI);
        if (!acquireResult.isSuccess()) {
            showProcessVideoAiStartFailure(acquireResult.failure);
            return;
        }
        selectedVideoAiSession = acquireResult.session;
        selectedVideoAiSession.setOnFinalizeListener(this::onProcessVideoAiSessionFinalized);
        selectedVideoAiSession.setOnTimelineFrameListener(this::onProcessVideoTimelineFrame);
        activeInferenceCacheKey = selectedVideoAiSession.getCacheKey();
        clearReplayTimelineState();
        Log.i(TAG, "AI Vision process-video session start cacheKey=" + activeInferenceCacheKey
                + " forceReinfer=" + forceReinfer);
        sourcePlaybackReachedEos = false;
        replayingDetectionOverlay = false;
        selectedVideoUiMode = SelectedVideoUiMode.PLAYBACK;
        hideVideoCover();
        hidePostEosActions();
        hideIdleDetectAction();
        selectedVideoAiSession.setOnPlaybackEndedListener(this::onCompositedDetectPlaybackEnded);
        startProcessVideoDetectPlayback();
        updateVideoActionUi();
    }

    private void startSelectedVideoPlaybackTicks() {
        mainHandler.removeCallbacks(selectedVideoPlaybackTickTask);
        mainHandler.post(selectedVideoPlaybackTickTask);
    }

    private void stopSelectedVideoPlaybackTicks() {
        mainHandler.removeCallbacks(selectedVideoPlaybackTickTask);
    }

    private void tickSelectedVideoPlayback() {
        if (binding == null || selectedVideoAiSession == null || replayingDetectionOverlay) {
            return;
        }
        if (isProcessVideoDetectSessionActive()) {
            updateOfflineInferenceOverlay();
        }
        if (sourcePlaybackReachedEos) {
            updateVideoActionUi();
        }
    }

    private void onProcessVideoTimelineFrame(long sampleMs, @NonNull ProcessVideoAiTimeline.Frame frame) {
        if (binding == null || selectedVideoAiSession == null) {
            return;
        }
        if (aiEngineCapabilities().isClassificationEnabled()) {
            AiManager.getInstance().publishLastClsSnapshot();
        }
        updateOfflineInferenceOverlay();
    }

    private void forceReinferSelectedVideo() {
        if (binding == null || selectedProcessVideo == null) {
            ToastUtils.showShort(R.string.ai_vision_select_video_first);
            return;
        }
        if (isOfflineInferenceInProgress()) {
            return;
        }
        File sourceVideo = resolveSelectedProcessVideoFile(selectedProcessVideo);
        if (!isUsableFile(sourceVideo)) {
            ToastUtils.showShort(R.string.video_loading_failed_text);
            return;
        }
        sourcePlaybackReachedEos = false;
        replayingDetectionOverlay = false;
        hidePostEosActions();
        hideIdleDetectAction();
        cancelSelectedVideoInference(true);
        activeInferenceCacheKey = null;
        clearReplayTimelineState();
        selectedVideoPausedByUser = false;
        selectedVideoPlaybackFailed = false;
        clearOfflineInferenceOverlay();
        startSelectedVideoOfflineInference(true);
    }

    private static boolean isUsableFile(@Nullable File file) {
        return LocalVideoPlaybackValidator.hasMinimumFileSize(file);
    }

    private void showOfflineInferenceProgress() {
        if (binding == null) {
            return;
        }
        if (!offlineInferenceProgressVisible) {
            offlineInferenceProgressVisible = true;
            binding.tvVideoStatus.setText(R.string.ai_vision_video_analyzing);
            binding.tvVideoStatus.setVisibility(View.GONE);
            binding.tvOfflineInferenceStatus.setText(R.string.ai_vision_video_inferring);
            binding.layoutOfflineInferenceLoading.setVisibility(View.VISIBLE);
            showSelectedVideoOverlayIdleStatus();
        }
        pauseSelectedVideoForOfflineInference();
        updateSelectedVideoPlayPauseButton();
    }



    private void pauseSelectedVideoPlayback() {
        if (isProcessVideoDetectSessionActive() && selectedVideoAiSession != null) {
            selectedVideoAiSession.pausePlaybackClock();
            if (selectedVideoPlayer != null) {
                selectedVideoPlayer.setPlayWhenReady(false);
                selectedVideoPlayer.pause();
            }
            updateSelectedVideoPlayPauseButton();
            return;
        }
        if (selectedVideoPlayer == null) {
            return;
        }
        selectedVideoPlayer.setPlayWhenReady(false);
        selectedVideoPlayer.pause();
        updateSelectedVideoPlayPauseButton();
    }

    private void toggleSelectedVideoPlayback() {
        if (isProcessVideoDetectSessionActive() && selectedVideoAiSession != null) {
            if (sourcePlaybackReachedEos) {
                updateSelectedVideoPlayPauseButton();
                return;
            }
            if (selectedVideoAiSession.isPlaybackPaused()) {
                selectedVideoPausedByUser = false;
                selectedVideoAiSession.resumePlaybackClock();
                if (selectedVideoPlayer != null) {
                    if (selectedVideoPlayer.getPlaybackState() == Player.STATE_ENDED) {
                        selectedVideoPlayer.seekTo(0L);
                    }
                    selectedVideoPlayer.setPlayWhenReady(true);
                    selectedVideoPlayer.play();
                }
            } else {
                selectedVideoPausedByUser = true;
                selectedVideoAiSession.pausePlaybackClock();
                if (selectedVideoPlayer != null) {
                    selectedVideoPlayer.setPlayWhenReady(false);
                    selectedVideoPlayer.pause();
                }
            }
            updateSelectedVideoPlayPauseButton();
            showSelectedVideoControlTemporarily();
            return;
        }
        if (selectedVideoPlayer == null || isOfflineInferenceInProgress()) {
            updateSelectedVideoPlayPauseButton();
            return;
        }
        if (selectedVideoPlaybackFailed) {
            updateSelectedVideoPlayPauseButton();
            return;
        }
        if (selectedVideoPlayer.isPlaying()
                || (selectedVideoPlayer.getPlayWhenReady()
                && selectedVideoPlayer.getPlaybackState() != Player.STATE_ENDED)) {
            selectedVideoPausedByUser = true;
            pauseSelectedVideoPlayback();
            showSelectedVideoControlTemporarily();
            return;
        }
        selectedVideoPausedByUser = false;
        if (selectedVideoPlayer.getPlaybackState() == Player.STATE_ENDED) {
            selectedVideoPlayer.seekTo(0L);
        }
        selectedVideoPlayer.play();
        updateSelectedVideoPlayPauseButton();
        showSelectedVideoControlTemporarily();
    }

    private void replayDetectionOverlay() {
        if (binding == null || selectedProcessVideo == null) {
            return;
        }
        File sourceVideo = resolveSelectedProcessVideoFile(selectedProcessVideo);
        if (!isUsableFile(sourceVideo)) {
            ToastUtils.showShort(R.string.video_loading_failed_text);
            updateVideoActionUi();
            return;
        }
        if (!hasReplayTimelineAvailable()) {
            ToastUtils.showShort(R.string.ai_vision_inference_video_not_ready);
            updateVideoActionUi();
            return;
        }
        loadReplayTimelineIfNeeded(true);
        selectedVideoPausedByUser = false;
        replayingDetectionOverlay = true;
        sourcePlaybackReachedEos = false;
        selectedVideoUiMode = SelectedVideoUiMode.PLAYBACK;
        hideVideoCover();
        hidePostEosActions();
        hideIdleDetectAction();
        clearOfflineInferenceOverlay();
        stopProcessVideoDetectPlayback();
        stopSelectedVideoPlaybackTicks();
        playSelectedProcessVideo();
        mainHandler.post(offlineInferenceOverlayTask);
    }

    private void pauseSelectedVideoForOfflineInference() {
        pauseSelectedVideoPlayback();
    }

    private void hideOfflineInferenceProgressIfIdle() {
        if (binding == null) {
            return;
        }
        if (selectedProcessVideo != null
                && (selectedVideoPlayer != null
                || isProcessVideoDetectSessionActive()
                || selectedVideoUiMode == SelectedVideoUiMode.PLAYBACK)) {
            hideSelectedVideoStatus();
        }
        if (isOfflineInferenceInProgress()) {
            return;
        }
        offlineInferenceProgressVisible = false;
        binding.layoutOfflineInferenceLoading.setVisibility(View.GONE);
        updateSelectedVideoPlayPauseButton();
    }

    private boolean isOfflineInferenceInProgress() {
        return selectedVideoAiSession != null && selectedVideoAiSession.isRunning();
    }

    @Nullable
    private File resolveSelectedProcessVideoFile(@Nullable ProcessParamsVideoVo processVideo) {
        return AiVisionInferenceUploadStateStore.resolveSourceVideo(processVideo);
    }

    private String buildInferenceCacheKey(ProcessParamsVideoVo processVideo, File videoFile) {
        return AiVisionInferenceUploadStateStore.buildInferenceCacheKey(processVideo, videoFile);
    }

    private String buildInferenceCacheKey(ProcessParamsVideoVo processVideo,
                                          File videoFile,
                                          @Nullable String extraSalt) {
        return AiVisionInferenceUploadStateStore.buildInferenceCacheKey(
                processVideo, videoFile, extraSalt);
    }

    private void cancelSelectedVideoInference(boolean clearResult) {
        stopSelectedVideoPlaybackTicks();
        stopProcessVideoDetectPlayback();
        if (selectedVideoAiSession != null) {
            selectedVideoAiSession.setOnPlaybackEndedListener(null);
            selectedVideoAiSession.setOnTimelineFrameListener(null);
            ProcessVideoAiSessionRegistry.getInstance().release(
                    selectedVideoAiSession, ProcessVideoAiSessionRegistry.Holder.UI);
            selectedVideoAiSession = null;
        }
        mainHandler.removeCallbacks(offlineInferenceOverlayTask);
        hideOfflineInferenceProgressIfIdle();
        if (clearResult) {
            offlineInferenceProgressVisible = false;
            if (binding != null) {
                binding.layoutOfflineInferenceLoading.setVisibility(View.GONE);
            }
            activeInferenceCacheKey = null;
            clearReplayTimelineState();
            clearOfflineInferenceOverlay();
        }
    }

    private void playSelectedProcessVideo() {
        playSelectedProcessVideo(false);
    }

    private void playSelectedProcessVideo(boolean pauseForOfflineAnalysis) {
        if (binding == null || selectedProcessVideo == null) {
            return;
        }
        File sourceFile = resolveSelectedProcessVideoFile(selectedProcessVideo);
        if (!isUsableFile(sourceFile)) {
            showSelectedVideoStatus(R.string.video_loading_failed_text);
            ToastUtils.showShort(R.string.video_loading_failed_text);
            return;
        }
        replayingDetectionOverlay = false;
        ThreadPoolManager.getExecutor().execute(() -> {
            if (!LocalVideoPlaybackValidator.isPlayable(sourceFile)) {
                mainHandler.post(() -> {
                    if (!isAdded()) {
                        return;
                    }
                    showSelectedVideoStatus(R.string.video_loading_failed_text);
                    ToastUtils.showShort(R.string.video_loading_failed_text);
                });
                return;
            }
            mainHandler.post(() -> {
                if (!isAdded()) {
                    return;
                }
                playSelectedVideoFile(sourceFile, pauseForOfflineAnalysis);
            });
        });
    }

    private void playSelectedVideoFile(@NonNull File playableFile) {
        playSelectedVideoFile(playableFile, false);
    }

    private void playSelectedVideoFile(@NonNull File playableFile, boolean pauseForOfflineAnalysis) {
        if (binding == null || selectedProcessVideo == null) {
            return;
        }
        Context context = getContext();
        if (context == null) {
            return;
        }
        if (StoragePermissionHelper.shouldRequestRuntimeVideoRead(context)) {
            requestVideoReadPerm.launch(StoragePermissionHelper.videoReadPermissions());
            return;
        }
        String playbackPath = playableFile.getAbsolutePath();
        if (selectedVideoPlayer != null && playbackPath.equals(selectedVideoPlaybackPath)) {
            hideSelectedVideoStatus();
            if (isSelectedVideoPlaybackEnded()) {
                selectedVideoPlayer.seekTo(0L);
                selectedVideoPlayer.setPlayWhenReady(!pauseForOfflineAnalysis);
                if (!pauseForOfflineAnalysis) {
                    selectedVideoPlayer.play();
                }
            } else {
                applySelectedVideoPlaybackUi(pauseForOfflineAnalysis, false);
            }
            return;
        }
        Uri playUri = buildPlayableVideoUri(playableFile);
        if (selectedVideoPlayer != null) {
            selectedVideoPlaybackPath = playbackPath;
            selectedVideoPlaybackFailed = false;
            Log.i(TAG, "AI Vision selected video swap media path=" + playbackPath
                    + " inferenceReplay=" + replayingDetectionOverlay);
            selectedVideoPlayer.setMediaItem(MediaItem.fromUri(playUri));
            selectedVideoPlayer.seekTo(0L);
            selectedVideoPlayer.prepare();
            hideSelectedVideoStatus();
            applySelectedVideoPlaybackUi(pauseForOfflineAnalysis, false);
            return;
        }
        DefaultTrackSelector trackSelector = new DefaultTrackSelector(requireContext());
        trackSelector.setParameters(trackSelector.buildUponParameters()
                .setRendererDisabled(C.TRACK_TYPE_AUDIO, true));
        selectedVideoPlayer = new ExoPlayer.Builder(requireContext())
                .setTrackSelector(trackSelector)
                .setMediaSourceFactory(new DefaultMediaSourceFactory(new DefaultDataSource.Factory(requireContext())))
                .build();
        selectedVideoPlaybackPath = playbackPath;
        selectedVideoPlaybackFailed = false;
        Log.i(TAG, "AI Vision selected video playback start size=" + playableFile.length()
                + " path=" + playbackPath
                + " inferenceReplay=" + replayingDetectionOverlay);
        binding.playerAiSelectedVideoView.setPlayer(selectedVideoPlayer);
        selectedVideoPlayer.setMediaItem(MediaItem.fromUri(playUri));
        selectedVideoPlayer.setRepeatMode(Player.REPEAT_MODE_OFF);
        selectedVideoPlayer.prepare();
        hideSelectedVideoStatus();
        applySelectedVideoPlaybackUi(pauseForOfflineAnalysis, false);
        selectedVideoPlayer.addListener(new Player.Listener() {
            @Override
            public void onPositionDiscontinuity(
                    @NonNull Player.PositionInfo oldPosition,
                    @NonNull Player.PositionInfo newPosition,
                    int reason) {
                if (!replayingDetectionOverlay
                        && !isProcessVideoDetectSessionActive()
                        && selectedVideoAiSession != null
                        && selectedVideoAiSession.isRunning()
                        && reason == Player.DISCONTINUITY_REASON_SEEK) {
                    selectedVideoPlayer.seekTo(oldPosition.positionMs);
                }
            }

            @Override
            public void onPlayerError(@NonNull PlaybackException error) {
                String detail = formatPlaybackFailure(error);
                Log.e(TAG, "AI Vision selected video playback failed path=" + playbackPath
                        + " detail=" + detail, error);
                selectedVideoPlaybackFailed = true;
                showSelectedVideoStatus(getString(R.string.video_loading_failed_text));
                postUpdateVideoActionUi();
                updateSelectedVideoPlayPauseButton();
            }

            @Override
            public void onPlayerErrorChanged(@Nullable PlaybackException error) {
                if (error != null) {
                    Log.e(TAG, "AI Vision selected video playback error changed: "
                            + formatPlaybackFailure(error), error);
                }
            }

            @Override
            public void onPlaybackStateChanged(int playbackState) {
                Log.d(TAG, "AI Vision selected video playback state=" + playbackState
                        + " path=" + playbackPath
                        + " inferenceReplay=" + replayingDetectionOverlay);
                if (playbackState == Player.STATE_ENDED && selectedVideoPlayer != null) {
                    if (replayingDetectionOverlay) {
                        mainHandler.post(AiVisionFragment.this::finishInferenceReplayPlayback);
                    } else if (isPlayingSourceRecording()) {
                        handleSourcePlaybackEnded();
                    }
                }
                if (shouldDriveRecordedVideoOverlay()) {
                    mainHandler.removeCallbacks(offlineInferenceOverlayTask);
                    mainHandler.post(offlineInferenceOverlayTask);
                }
                postUpdateVideoActionUi();
            }

            @Override
            public void onIsPlayingChanged(boolean isPlaying) {
                if (shouldDriveRecordedVideoOverlay()) {
                    mainHandler.removeCallbacks(offlineInferenceOverlayTask);
                    mainHandler.post(offlineInferenceOverlayTask);
                }
                updateSelectedVideoPlayPauseButton();
            }
        });
        updateOfflineInferenceOverlayVisibility(false);
    }

    private Uri buildPlayableVideoUri(@NonNull File playableFile) {
        try {
            return FileProvider.getUriForFile(
                    requireContext(),
                    requireContext().getPackageName() + ".fileprovider",
                    playableFile);
        } catch (IllegalArgumentException e) {
            Log.w(TAG, "FileProvider rejected selected AI Vision video path", e);
            return Uri.fromFile(playableFile);
        }
    }

    private void applySelectedVideoPlaybackUi(boolean pausePlayback, boolean playExportedInferenceVideo) {
        if (binding == null || selectedVideoPlayer == null) {
            return;
        }
        if (pausePlayback) {
            showOfflineInferenceProgress();
        } else if (selectedVideoPlayer.getPlaybackState() == Player.STATE_ENDED) {
            selectedVideoPlayer.setPlayWhenReady(false);
            hideOfflineInferenceProgressIfIdle();
        } else if (selectedVideoPausedByUser) {
            selectedVideoPlayer.setPlayWhenReady(false);
            selectedVideoPlayer.pause();
            hideOfflineInferenceProgressIfIdle();
        } else {
            selectedVideoPlayer.setPlayWhenReady(true);
            hideOfflineInferenceProgressIfIdle();
        }
        updateSelectedVideoPlayPauseButton();
        updateOfflineInferenceOverlayVisibility(playExportedInferenceVideo);
    }

    private void updateSelectedVideoPlayPauseButton() {
        if (binding == null) {
            return;
        }
        boolean hasPlayer = (selectedVideoPlayer != null || isProcessVideoDetectSessionActive())
                && selectedProcessVideo != null;
        boolean inferenceBusy = isOfflineInferenceInProgress();
        boolean postEosPanelVisible = binding.layoutPostEosActions.getVisibility() == View.VISIBLE
                || binding.btnDetectVideo.getVisibility() == View.VISIBLE;
        if (!hasPlayer || inferenceBusy || postEosPanelVisible) {
            hideSelectedVideoControl();
        }
        binding.btnSelectedVideoPlayPause.setEnabled(hasPlayer && !inferenceBusy && !selectedVideoPlaybackFailed);
        boolean compositedPlaying = isProcessVideoDetectSessionActive()
                && selectedVideoAiSession != null
                && !selectedVideoAiSession.isPlaybackPaused()
                && !sourcePlaybackReachedEos
                && selectedVideoPlayer != null
                && (selectedVideoPlayer.isPlaying() || selectedVideoPlayer.getPlayWhenReady());
        boolean exoPlaying = selectedVideoPlayer != null
                && (selectedVideoPlayer.isPlaying() || selectedVideoPlayer.getPlayWhenReady());
        boolean shouldShowPause = hasPlayer
                && !inferenceBusy
                && !isSelectedVideoPlaybackEnded()
                && ((isProcessVideoDetectSessionActive() && compositedPlaying)
                || (!isProcessVideoDetectSessionActive() && exoPlaying && !selectedVideoPausedByUser));
        binding.btnSelectedVideoPlayPause.setImageResource(shouldShowPause
                ? R.drawable.ic_ai_vision_video_pause
                : R.drawable.ic_ai_vision_video_play);
        binding.btnSelectedVideoPlayPause.setContentDescription(getString(shouldShowPause
                ? R.string.ai_vision_video_pause
                : R.string.ai_vision_video_play));
    }

    private void showSelectedVideoControlTemporarily() {
        if (binding == null
                || (selectedVideoPlayer == null && !isProcessVideoDetectSessionActive())
                || selectedProcessVideo == null
                || isOfflineInferenceInProgress()
                || binding.layoutPostEosActions.getVisibility() == View.VISIBLE
                || binding.btnDetectVideo.getVisibility() == View.VISIBLE) {
            return;
        }
        binding.btnSelectedVideoPlayPause.setVisibility(View.VISIBLE);
        mainHandler.removeCallbacks(hideSelectedVideoControlTask);
        mainHandler.postDelayed(hideSelectedVideoControlTask, VIDEO_CONTROL_AUTO_HIDE_MS);
    }

    private void toggleSelectedVideoControlVisibility() {
        if (binding == null
                || (selectedVideoPlayer == null && !isProcessVideoDetectSessionActive())
                || selectedProcessVideo == null
                || isOfflineInferenceInProgress()) {
            return;
        }
        if (binding.btnSelectedVideoPlayPause.getVisibility() == View.VISIBLE) {
            hideSelectedVideoControl();
        } else {
            showSelectedVideoControlTemporarily();
        }
    }

    private void hideSelectedVideoControl() {
        mainHandler.removeCallbacks(hideSelectedVideoControlTask);
        if (binding != null) {
            binding.btnSelectedVideoPlayPause.setVisibility(View.GONE);
        }
    }

    private void updateOfflineInferenceOverlayVisibility(boolean playExportedInferenceVideo) {
        if (binding == null) {
            return;
        }
        if (!isProcessVideoDetectSessionActive()) {
            clearOfflineInferenceOverlay();
        }
    }

    private void showSelectedVideoStatus(int stringRes) {
        if (binding == null) {
            return;
        }
        binding.tvVideoStatus.setText(stringRes);
        binding.tvVideoStatus.setVisibility(View.VISIBLE);
    }

    private void showSelectedVideoStatus(String statusText) {
        if (binding == null) {
            return;
        }
        binding.tvVideoStatus.setText(statusText);
        binding.tvVideoStatus.setVisibility(View.VISIBLE);
    }

    private void hideSelectedVideoStatus() {
        if (binding != null) {
            binding.tvVideoStatus.setVisibility(View.GONE);
        }
    }

    private void releaseExoPlayerOnly() {
        ExoPlayer player = selectedVideoPlayer;
        selectedVideoPlayer = null;
        selectedVideoPlaybackPath = null;
        selectedVideoPausedByUser = false;
        selectedVideoPlaybackFailed = false;
        mainHandler.removeCallbacks(offlineInferenceOverlayTask);
        mainHandler.removeCallbacks(hideSelectedVideoControlTask);
        if (binding != null) {
            binding.playerAiSelectedVideoView.setPlayer(null);
        }
        if (player != null) {
            player.release();
        }
        updateSelectedVideoPlayPauseButton();
    }

    private void releaseSelectedVideoPlayer() {
        stopProcessVideoDetectPlayback();
        releaseExoPlayerOnly();
        sourcePlaybackReachedEos = false;
        replayingDetectionOverlay = false;
        selectedVideoUiMode = SelectedVideoUiMode.PROMPT_SELECT;
        hidePostEosActions();
        hideIdleDetectAction();
        updateSelectedVideoPlayPauseButton();
    }

    private static String formatPlaybackFailure(@NonNull PlaybackException error) {
        StringBuilder sb = new StringBuilder();
        sb.append(PlaybackException.getErrorCodeName(error.errorCode));
        Throwable t = error.getCause();
        int depth = 0;
        while (t != null && depth < 6) {
            sb.append(" | ").append(t.getClass().getSimpleName());
            if (t.getMessage() != null && !t.getMessage().isEmpty()) {
                sb.append(": ").append(t.getMessage());
            }
            t = t.getCause();
            depth++;
        }
        return sb.toString();
    }

    private boolean shouldDriveRecordedVideoOverlay() {
        if (isProcessVideoDetectSessionActive()) {
            return true;
        }
        if (selectedVideoPlayer == null) {
            return false;
        }
        return replayingDetectionOverlay
                || selectedVideoPlayer.isPlaying()
                || selectedVideoPlayer.getPlayWhenReady();
    }

    private long resolveRecordedVideoOverlayPositionMs() {
        if (selectedVideoPlayer != null
                && (isProcessVideoDetectSessionActive() || replayingDetectionOverlay)) {
            return selectedVideoPlayer.getCurrentPosition();
        }
        if (isProcessVideoDetectSessionActive() && selectedVideoAiSession != null) {
            return selectedVideoAiSession.getPlaybackPositionMs();
        }
        if (selectedVideoPlayer != null) {
            return selectedVideoPlayer.getCurrentPosition();
        }
        return 0L;
    }

    private void updateOfflineInferenceOverlay() {
        if (binding == null) {
            return;
        }
        if (selectedVideoPlayer == null
                && !isProcessVideoDetectSessionActive()
                && !replayingDetectionOverlay) {
            return;
        }
        if (sourcePlaybackReachedEos && !replayingDetectionOverlay) {
            return;
        }
        long positionMs = resolveRecordedVideoOverlayPositionMs();
        ProcessVideoAiTimeline timeline = resolvePlaybackTimeline();
        ProcessVideoAiTimeline.Frame statusFrame = resolveRecordedVideoStatusFrame(timeline, positionMs);
        ProcessVideoAiTimeline.Frame boxFrame = resolveRecordedVideoBoxFrame(timeline, positionMs);
        List<DetectionOverlayView.Box> boxes = new ArrayList<>();
        String status = null;
        String message = null;
        if (statusFrame != null) {
            status = pickTimelineOverlayStatus(statusFrame);
            message = pickTimelineOverlayMessage(statusFrame);
        }
        if (boxFrame != null) {
            boxes.addAll(boxFrame.toOverlayBoxes());
            if (appendTimelineStainDetectOverlayBoxes(boxes, boxFrame)
                    && shouldUseStainDetectOverlayStatus(status)) {
                status = OpencvStainDetectResult.OVERLAY_STATUS;
                message = null;
            }
        }
        ProcessVideoAiTimeline.Frame geometryFrame = boxFrame != null ? boxFrame : statusFrame;
        applyDetectionOverlay(boxes, status, message, false, geometryFrame);
        if (!shouldDriveRecordedVideoOverlay()) {
            return;
        }
        mainHandler.removeCallbacks(offlineInferenceOverlayTask);
        mainHandler.postDelayed(offlineInferenceOverlayTask, OFFLINE_VIDEO_OVERLAY_INTERVAL_MS);
    }

    private boolean appendTimelineStainDetectOverlayBoxes(
            @NonNull List<DetectionOverlayView.Box> boxes,
            @NonNull ProcessVideoAiTimeline.Frame frame) {
        if (!AiManager.getInstance().isOpencvStainDetectSessionActive()
                || frame.stainDetect == null
                || !frame.stainDetect.hasTarget()) {
            return false;
        }
        int w = frame.imageWidth > 0 ? frame.imageWidth : AI_FRAME_SAMPLE_WIDTH;
        int h = frame.imageHeight > 0 ? frame.imageHeight : AI_FRAME_SAMPLE_HEIGHT;
        OpencvStainDetectResult lensDet = new OpencvStainDetectResult(
                frame.stainDetect.success,
                frame.stainDetect.code,
                "",
                frame.stainDetect.targetX,
                frame.stainDetect.targetY,
                w,
                h,
                frame.stainDetect.source,
                frame.timeMs);
        boxes.addAll(DetectionOverlayMapper.fromOpencvStainDetect(lensDet, w, h));
        return true;
    }

    private static boolean isLiveInferSchedulingEnabled(@NonNull AiManager manager) {
        return manager.isOpencvStainDetectSessionActive();
    }

    private static boolean shouldUseStainDetectOverlayStatus(@Nullable String status) {
        return status == null || AiStainDetectResultMapper.isNonDisplayOverlayStatus(status);
    }

    @Nullable
    private static String pickTimelineOverlayStatus(@NonNull ProcessVideoAiTimeline.Frame frame) {
        if (!frame.status.trim().isEmpty()
                && !AiStainDetectResultMapper.isNonDisplayOverlayStatus(frame.status)) {
            return frame.status.trim();
        }
        if (frame.level >= 0) {
            return "L" + frame.level;
        }
        return null;
    }

    @Nullable
    private static String pickTimelineOverlayMessage(@NonNull ProcessVideoAiTimeline.Frame frame) {
        String message = frame.message.trim();
        String status = frame.status.trim();
        if (!message.isEmpty() && (status.isEmpty() || !message.equalsIgnoreCase(status))) {
            return message;
        }
        String display = frame.displayMessage();
        return display.isEmpty() ? null : display;
    }

    private void clearOfflineInferenceOverlay() {
        if (binding == null) {
            return;
        }
        mainHandler.removeCallbacks(offlineInferenceOverlayTask);
        if (selectedProcessVideo == null || isLiveRtspOverlayActive()) {
            clearDetectionOverlayLayer();
            hideAiOverlayHudCard();
            return;
        }
        showSelectedVideoOverlayIdleStatus();
    }

    /** Top-right HUD when a process video is selected but Detect / Replay is not active. */
    private void showSelectedVideoOverlayIdleStatus() {
        if (binding == null || selectedProcessVideo == null || isLiveRtspOverlayActive()) {
            return;
        }
        clearDetectionOverlayLayer();
        showAiOverlayHudIdleStatus();
    }

    private void clearDetectionOverlayLayer() {
        if (binding == null) {
            return;
        }
        binding.viewDetectionOverlay.clear();
        binding.viewDetectionOverlay.setVisibility(View.GONE);
    }

    private void hideAiOverlayHudCard() {
        if (binding == null) {
            return;
        }
        binding.layoutAiOverlayHud.setVisibility(View.GONE);
    }

    private void showAiOverlayHudIdleStatus() {
        if (binding == null) {
            return;
        }
        binding.tvAiOverlayHudStatus.setText(formatIdleHudStatusLine());
        binding.tvAiOverlayHudStatus.setVisibility(View.VISIBLE);
        binding.tvAiOverlayHudDetail.setVisibility(View.GONE);
        binding.layoutAiOverlayHud.setVisibility(View.VISIBLE);
    }

    private static long parseLongSafely(@Nullable String value, long fallback) {
        if (value == null) {
            return fallback;
        }
        try {
            return Long.parseLong(value.trim());
        } catch (Exception e) {
            return fallback;
        }
    }

    private static float parseFloatSafely(@Nullable String value, float fallback) {
        if (value == null) {
            return fallback;
        }
        try {
            return Float.parseFloat(value.trim());
        } catch (Exception e) {
            return fallback;
        }
    }


    private void overrideLowLatencyPrefs(boolean enable) {
        if (getContext() == null) {
            return;
        }
        if (enable) {
            boolean current = PreferenceManager.getDefaultSharedPreferences(requireContext())
                    .getBoolean("waiting_i_frame", true);
            previousWaitingIFrame = current;
            if (current) {
                PreferenceManager.getDefaultSharedPreferences(requireContext())
                        .edit()
                        .putBoolean("waiting_i_frame", false)
                        .apply();
            }
            return;
        }
        if (previousWaitingIFrame != null) {
            PreferenceManager.getDefaultSharedPreferences(requireContext())
                    .edit()
                    .putBoolean("waiting_i_frame", previousWaitingIFrame)
                    .apply();
            previousWaitingIFrame = null;
        }
    }

    private void initZoomControls() {
        View.OnTouchListener zoomTouchListener = (view, event) -> {
            handleZoomTouch(event);
            return true;
        };
        binding.layoutAiVideoBox.setOnTouchListener(zoomTouchListener);
        binding.playerAiSelectedVideoView.setOnTouchListener(zoomTouchListener);
        binding.textureVisionView.setOnTouchListener(zoomTouchListener);
        binding.viewDetectionOverlay.setOnTouchListener(zoomTouchListener);
        resetZoomToDefault();
    }

    private void handleZoomTouch(MotionEvent event) {
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
                didPinchInCurrentGesture = false;
                break;
            case MotionEvent.ACTION_POINTER_DOWN:
                if (event.getPointerCount() >= 2) {
                    beginPinch(event);
                }
                break;
            case MotionEvent.ACTION_MOVE:
                if (event.getPointerCount() >= 2) {
                    didPinchInCurrentGesture = true;
                    updatePinchZoom(event);
                }
                break;
            case MotionEvent.ACTION_POINTER_UP:
            case MotionEvent.ACTION_CANCEL:
                isPinching = false;
                bestPauseActive = false;
                pinchDistanceSmoothed = 0f;
                mainHandler.removeCallbacks(bestPauseTask);
                break;
            case MotionEvent.ACTION_UP:
                if (!didPinchInCurrentGesture) {
                    toggleSelectedVideoControlVisibility();
                    handleDoubleTap(event);
                }
                isPinching = false;
                bestPauseActive = false;
                pinchDistanceSmoothed = 0f;
                mainHandler.removeCallbacks(bestPauseTask);
                break;
            default:
                break;
        }
    }

    private void beginPinch(MotionEvent event) {
        float distance = pointerDistance(event);
        if (distance <= 0f) {
            return;
        }
        isPinching = true;
        didPinchInCurrentGesture = true;
        bestPauseActive = false;
        bestPauseConsumedForGesture = false;
        mainHandler.removeCallbacks(bestPauseTask);
        pinchDistanceSmoothed = distance;
        pinchLastDistance = Math.max(distance, 1f);
    }

    private void updatePinchZoom(MotionEvent event) {
        if (!isPinching) {
            beginPinch(event);
            return;
        }
        float distance = pointerDistance(event);
        if (distance <= 0f) {
            return;
        }
        if (bestPauseActive) {
            pinchDistanceSmoothed = distance;
            pinchLastDistance = Math.max(distance, 1f);
            return;
        }
        if (pinchLastDistance <= 0f) {
            pinchDistanceSmoothed = distance;
            pinchLastDistance = Math.max(distance, 1f);
            return;
        }
        pinchDistanceSmoothed = pinchDistanceSmoothed * (1f - PINCH_DISTANCE_SMOOTH_ALPHA)
                + distance * PINCH_DISTANCE_SMOOTH_ALPHA;
        float rawRatio = pinchDistanceSmoothed / pinchLastDistance;
        if (Math.abs(rawRatio - 1f) < PINCH_RATIO_DEAD_ZONE) {
            return;
        }
        float nextZoom = clamp(currentZoom * amplifyPinchRatio(rawRatio), MIN_ZOOM, MAX_ZOOM);
        nextZoom = quantizeZoom(nextZoom);
        if (Math.abs(nextZoom - currentZoom) < MIN_ZOOM_UPDATE_DELTA
                && nextZoom > MIN_ZOOM
                && nextZoom < MAX_ZOOM) {
            return;
        }
        setZoomWithBestPause(nextZoom, pinchDistanceSmoothed);
        if (!bestPauseActive) {
            pinchLastDistance = Math.max(pinchDistanceSmoothed, 1f);
        }
    }

    private void setZoomWithBestPause(float nextZoom, float currentDistance) {
        nextZoom = quantizeZoom(nextZoom);
        if (Math.abs(nextZoom - currentZoom) < 1e-4f) {
            return;
        }
        if (!bestPauseConsumedForGesture
                && currentZoom < BEST_ZOOM_THRESHOLD
                && nextZoom >= BEST_ZOOM_THRESHOLD) {
            currentZoom = BEST_ZOOM_THRESHOLD;
            applyZoomTransform();
            flashBestLabel();
            bestPauseActive = true;
            bestPauseConsumedForGesture = true;
            pinchDistanceSmoothed = currentDistance;
            pinchLastDistance = Math.max(currentDistance, 1f);
            mainHandler.removeCallbacks(bestPauseTask);
            mainHandler.postDelayed(bestPauseTask, BEST_ZOOM_PAUSE_MS);
            return;
        }
        currentZoom = nextZoom;
        applyZoomTransform();
    }

    private void handleDoubleTap(MotionEvent event) {
        long eventTime = event.getEventTime();
        float dx = event.getX() - lastTapUpX;
        float dy = event.getY() - lastTapUpY;
        boolean isDoubleTap = eventTime - lastTapUpTime <= DOUBLE_TAP_TIMEOUT_MS
                && dx * dx + dy * dy <= DOUBLE_TAP_SLOP_PX * DOUBLE_TAP_SLOP_PX;
        lastTapUpTime = eventTime;
        lastTapUpX = event.getX();
        lastTapUpY = event.getY();
        if (isDoubleTap && currentZoom > MIN_ZOOM) {
            resetZoomToDefault();
        }
    }

    private void flashBestLabel() {
        if (binding == null) {
            return;
        }
        mainHandler.removeCallbacks(bestFlashRestoreTask);
        binding.tvZoomState.animate().cancel();
        binding.tvZoomState.setAlpha(1f);
        binding.tvZoomState.setScaleX(1f);
        binding.tvZoomState.setScaleY(1f);
        binding.tvZoomState.animate()
                .alpha(0.55f)
                .scaleX(1.08f)
                .scaleY(1.08f)
                .setDuration(BEST_LABEL_FLASH_MS)
                .start();
        mainHandler.postDelayed(bestFlashRestoreTask, BEST_LABEL_FLASH_MS);
    }

    private static float amplifyPinchRatio(float rawRatio) {
        float amplified = 1f + (rawRatio - 1f) * ZOOM_GESTURE_SENSITIVITY;
        return clamp(amplified, MIN_PINCH_RATIO, MAX_PINCH_RATIO);
    }

    private static float pointerDistance(MotionEvent event) {
        if (event.getPointerCount() < 2) {
            return 0f;
        }
        float dx = event.getX(0) - event.getX(1);
        float dy = event.getY(0) - event.getY(1);
        return (float) Math.sqrt(dx * dx + dy * dy);
    }

    private void resetZoomToDefault() {
        bestPauseActive = false;
        mainHandler.removeCallbacks(bestPauseTask);
        mainHandler.removeCallbacks(bestFlashRestoreTask);
        if (binding != null) {
            binding.tvZoomState.animate().cancel();
            binding.tvZoomState.setAlpha(1f);
            binding.tvZoomState.setScaleX(1f);
            binding.tvZoomState.setScaleY(1f);
        }
        currentZoom = MIN_ZOOM;
        panX = 0f;
        panY = 0f;
        lastAppliedZoomForThrottle = Float.NaN;
        applyZoomTransform();
    }

    /**
     * 仅作用于 {@link TextureView} 与叠加层矩阵；不改变解码分辨率，也不改变传给推理的 I420 宽高
     * （推理推全帧 I420；引擎内 ROI/输入变换由 AI 库 native 层处理；回调 boxes 为全图 xyxy，见对齐文档）。
     */
    private void applyZoomTransform() {
        if (binding == null) {
            return;
        }
        long now = SystemClock.elapsedRealtime();
        if (!Float.isNaN(lastAppliedZoomForThrottle)
                && (now - lastZoomTransformApplyElapsedMs) < ZOOM_TRANSFORM_MIN_INTERVAL_MS
                && Math.abs(currentZoom - lastAppliedZoomForThrottle) < ZOOM_TRANSFORM_EPSILON) {
            return;
        }
        lastZoomTransformApplyElapsedMs = now;
        lastAppliedZoomForThrottle = currentZoom;
        updateCenterPan();
        videoTransform.reset();
        videoTransform.postScale(currentZoom, currentZoom);
        videoTransform.postTranslate(panX, panY);
        binding.textureVisionView.setTransform(videoTransform);

        binding.playerAiSelectedVideoView.setPivotX(0f);
        binding.playerAiSelectedVideoView.setPivotY(0f);
        binding.playerAiSelectedVideoView.setScaleX(currentZoom);
        binding.playerAiSelectedVideoView.setScaleY(currentZoom);
        binding.playerAiSelectedVideoView.setTranslationX(panX);
        binding.playerAiSelectedVideoView.setTranslationY(panY);

        binding.viewDetectionOverlay.setPivotX(0f);
        binding.viewDetectionOverlay.setPivotY(0f);
        binding.viewDetectionOverlay.setScaleX(currentZoom);
        binding.viewDetectionOverlay.setScaleY(currentZoom);
        binding.viewDetectionOverlay.setTranslationX(panX);
        binding.viewDetectionOverlay.setTranslationY(panY);
        updateZoomStateLabel();
        binding.tvZoomRatio.setText(getString(R.string.zoom_ratio_format, currentZoom));
    }

    private void updateZoomStateLabel() {
        if (nearZoom(currentZoom, MIN_ZOOM)) {
            binding.tvZoomState.setText(R.string.zoom_state_default);
            binding.tvZoomState.setVisibility(View.VISIBLE);
        } else if (nearZoom(currentZoom, BEST_ZOOM_THRESHOLD)) {
            binding.tvZoomState.setText(R.string.zoom_state_best);
            binding.tvZoomState.setVisibility(View.VISIBLE);
        } else if (nearZoom(currentZoom, MAX_ZOOM)) {
            binding.tvZoomState.setText(R.string.zoom_state_max);
            binding.tvZoomState.setVisibility(View.VISIBLE);
        } else {
            binding.tvZoomState.setVisibility(View.GONE);
        }
    }

    private static boolean nearZoom(float zoom, float target) {
        return Math.abs(zoom - target) <= STATE_DISPLAY_EPSILON;
    }

    private void updateCenterPan() {
        if (binding == null || currentZoom <= MIN_ZOOM) {
            panX = 0f;
            panY = 0f;
            return;
        }
        int width = binding.playerAiSelectedVideoView.getWidth();
        int height = binding.playerAiSelectedVideoView.getHeight();
        if (width <= 0 || height <= 0) {
            width = binding.textureVisionView.getWidth();
            height = binding.textureVisionView.getHeight();
        }
        if (width <= 0 || height <= 0) {
            return;
        }
        panX = (width - width * currentZoom) / 2f;
        panY = (height - height * currentZoom) / 2f;
    }

    private static float clamp(float value, float min, float max) {
        return Math.max(min, Math.min(max, value));
    }

    private static int clamp(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
    }

    /** Snap zoom to a grid and to the exact "best" product threshold to avoid label/video flicker. */
    private static float quantizeZoom(float z) {
        z = clamp(z, MIN_ZOOM, MAX_ZOOM);
        if (Math.abs(z - BEST_ZOOM_THRESHOLD) <= ZOOM_QUANT_STEP * 0.55f) {
            return BEST_ZOOM_THRESHOLD;
        }
        float q = Math.round(z / ZOOM_QUANT_STEP) * ZOOM_QUANT_STEP;
        return clamp(q, MIN_ZOOM, MAX_ZOOM);
    }

    /** 每次进入 AI Vision 显示教学（不写 prefs，下次进入仍会弹出）。 */
    private void showZoomTutorialOnEnter() {
        // Zoom Gesture Guide is temporarily disabled; leave the implementation
        // commented for quick restoration when the feature is needed again.
//        if (binding == null || getContext() == null) {
//            return;
//        }
//        zoomTutorialPage = 0;
//        binding.layoutZoomTutorial.setVisibility(View.VISIBLE);
//        showTutorialPage(zoomTutorialPage);
    }

    private static SharedPreferences aiVisionPrefs(Context context) {
        return AiVisionInferenceUploadStateStore.prefs(context);
    }

    private void showTutorialPage(int page) {
        if (binding == null || binding.layoutZoomTutorial.getVisibility() != View.VISIBLE) {
            return;
        }
        zoomTutorialPage = Math.max(0, Math.min(TUTORIAL_PAGE_COUNT - 1, page));
        binding.tvZoomTutorialPage.setText(getString(
                R.string.zoom_tutorial_page_format,
                zoomTutorialPage + 1,
                TUTORIAL_PAGE_COUNT
        ));
        binding.btnZoomTutorialPagePrev.setVisibility(zoomTutorialPage == 0 ? View.INVISIBLE : View.VISIBLE);
        boolean isLastPage = zoomTutorialPage == TUTORIAL_PAGE_COUNT - 1;
        binding.tvZoomTutorialNext.setText(isLastPage
                ? R.string.zoom_tutorial_finish
                : R.string.zoom_tutorial_next);
        binding.tvZoomTutorialNext.setTextColor(isLastPage
                ? Color.parseColor("#BFC8FF")
                : Color.WHITE);
        mainHandler.removeCallbacks(zoomTutorialTask);
        runZoomTutorialStep();
    }

    private void runZoomTutorialStep() {
        if (binding == null || binding.layoutZoomTutorial.getVisibility() != View.VISIBLE) {
            return;
        }
        resetTutorialFingers();
        switch (zoomTutorialPage) {
            case 0:
                binding.tvZoomTutorialText.setText(R.string.zoom_tutorial_zoom_in);
                animateTutorialFingers(-TUTORIAL_SPREAD_END_X, TUTORIAL_SPREAD_END_X, 1f);
                break;
            case 1:
                binding.tvZoomTutorialText.setText(R.string.zoom_tutorial_zoom_out);
                binding.viewTutorialFingerLeft.setTranslationX(-TUTORIAL_PINCH_START_X);
                binding.viewTutorialFingerRight.setTranslationX(TUTORIAL_PINCH_START_X);
                animateTutorialFingers(-TUTORIAL_PINCH_END_X, TUTORIAL_PINCH_END_X, 1f);
                break;
            case 2:
                binding.tvZoomTutorialText.setText(R.string.zoom_tutorial_reset);
                animateTutorialDoubleTap();
                break;
            default:
                return;
        }
        mainHandler.postDelayed(zoomTutorialTask, TUTORIAL_LOOP_DELAY_MS);
    }

    private void animateTutorialFingers(float leftX, float rightX, float scale) {
        binding.viewTutorialFingerLeft.animate()
                .translationX(leftX)
                .scaleX(scale)
                .scaleY(scale)
                .setDuration(TUTORIAL_ANIM_MS)
                .start();
        binding.viewTutorialFingerRight.animate()
                .translationX(rightX)
                .scaleX(scale)
                .scaleY(scale)
                .setDuration(TUTORIAL_ANIM_MS)
                .start();
    }

    private void animateTutorialDoubleTap() {
        if (binding == null) {
            return;
        }
        // Use a single finger pulse twice to indicate double-tap reset gesture.
        binding.viewTutorialFingerRight.setAlpha(0f);
        binding.viewTutorialFingerLeft.setTranslationX(0f);
        binding.viewTutorialFingerLeft.setTranslationY(0f);
        binding.viewTutorialFingerLeft.setScaleX(1f);
        binding.viewTutorialFingerLeft.setScaleY(1f);
        binding.viewTutorialFingerLeft.animate()
                .scaleX(0.78f)
                .scaleY(0.78f)
                .setDuration(140L)
                .withEndAction(() -> {
                    if (binding == null) {
                        return;
                    }
                    binding.viewTutorialFingerLeft.animate()
                            .scaleX(1f)
                            .scaleY(1f)
                            .setDuration(120L)
                            .withEndAction(() -> {
                                if (binding == null) {
                                    return;
                                }
                                binding.viewTutorialFingerLeft.animate()
                                        .scaleX(0.78f)
                                        .scaleY(0.78f)
                                        .setDuration(140L)
                                        .withEndAction(() -> {
                                            if (binding == null) {
                                                return;
                                            }
                                            binding.viewTutorialFingerLeft.animate()
                                                    .scaleX(1f)
                                                    .scaleY(1f)
                                                    .setDuration(120L)
                                                    .start();
                                        })
                                        .start();
                            })
                            .start();
                })
                .start();
    }

    private void resetTutorialFingers() {
        if (binding == null) {
            return;
        }
        binding.viewTutorialFingerLeft.animate().cancel();
        binding.viewTutorialFingerRight.animate().cancel();
        binding.viewTutorialFingerLeft.setAlpha(1f);
        binding.viewTutorialFingerRight.setAlpha(1f);
        binding.viewTutorialFingerLeft.setTranslationX(0f);
        binding.viewTutorialFingerRight.setTranslationX(0f);
        binding.viewTutorialFingerLeft.setTranslationY(0f);
        binding.viewTutorialFingerRight.setTranslationY(0f);
        binding.viewTutorialFingerLeft.setScaleX(1f);
        binding.viewTutorialFingerLeft.setScaleY(1f);
        binding.viewTutorialFingerRight.setScaleX(1f);
        binding.viewTutorialFingerRight.setScaleY(1f);
    }

    private void dismissZoomTutorial() {
        if (binding == null) {
            return;
        }
        mainHandler.removeCallbacks(zoomTutorialTask);
        resetTutorialFingers();
        binding.layoutZoomTutorial.setVisibility(View.GONE);
    }

    @Subscribe(threadMode = ThreadMode.MAIN)
    public void onAiEngineStateChanged(AiEngineStateEvent event) {
        if (binding == null || event == null) {
            return;
        }
        AiEngineCapabilityProfile capabilities = aiEngineCapabilities();
        int state = event.getState();
        if (state == 1 && !capabilities.isFocusMonitoringExpected()) {
            applyAiStateWithoutFocusMonitoring();
            return;
        }
        overlayEngineDetailLine = resolveEngineDetailForState(state);
        if (isLiveRtspOverlayActive()) {
            updateLiveInferenceOverlay();
        } else {
            refreshDetectionOverlayHudOnly();
        }
    }

    @Subscribe(threadMode = ThreadMode.MAIN)
    public void onLensCheckResult(LensCheckResultEvent event) {
        if (binding == null || event == null) {
            return;
        }
        if (isProcessVideoDetectSessionActive() || replayingDetectionOverlay) {
            syncActiveDetectionOverlay();
            return;
        }
        if (!isLiveRtspOverlayActive()) {
            return;
        }
        String rawMessage = event.getMessage();
        if (rawMessage == null || rawMessage.trim().isEmpty()) {
            rawMessage = getString(R.string.ai_overlay_result_waiting);
        }
        CameraAiOverlayState.getInstance().updateFromCheckResult(rawMessage, event.getStatus());
        CameraAiOverlayState.Snapshot overlay = CameraAiOverlayState.getInstance().getSnapshot();
        String displayMessage = overlay.displayMessage;
        if (displayMessage.trim().isEmpty()) {
            displayMessage = getString(R.string.ai_overlay_result_waiting);
        }
        applyDetectionOverlay(
                overlay.boxes.isEmpty() ? null : overlay.boxes,
                event.getStatus(),
                displayMessage,
                true);
    }

    @Subscribe(threadMode = ThreadMode.MAIN)
    public void onLensClsSnapshot(LensClsSnapshotEvent event) {
        if (binding == null || event == null) {
            return;
        }
        if (!aiEngineCapabilities().isClassificationEnabled()) {
            overlayClassificationLine = getString(R.string.ai_overlay_cls_disabled);
        } else if (!event.isValid()) {
            overlayClassificationLine = getString(R.string.ai_overlay_cls_waiting);
        } else {
            String className = event.getClassName();
            if (className == null || className.trim().isEmpty()) {
                className = resolveClsClassName(event.getClassId());
            }
            overlayClassificationLine = getString(R.string.ai_overlay_cls_prefix, className, event.getScore());
        }
        if (selectedVideoAiSession != null) {
            selectedVideoAiSession.setClassificationLine(overlayClassificationLine);
        }
        syncActiveDetectionOverlay();
    }

    private String resolveClsClassName(int classId) {
        if (classId == 0) {
            return getString(R.string.ai_overlay_cls_other);
        }
        if (classId == 1) {
            return getString(R.string.ai_overlay_cls_metal);
        }
        return "#" + classId;
    }

    private AiEngineCapabilityProfile aiEngineCapabilities() {
        return AiManager.getInstance().getCapabilities();
    }

    /** True when OpenCV lens_det is unavailable — skip inference upload. */
    private boolean shouldSkipOfflineInferenceForUpload() {
        return !AiManager.getInstance().isOpencvStainDetectSessionActive();
    }

    private void ensureAiEngineForProcessVideo(@NonNull Context context) {
        AiManager manager = AiManager.getInstance();
        if (manager.isOpencvStainDetectSessionActive()) {
            return;
        }
        if (!manager.start(context.getApplicationContext())) {
            Log.w(TAG, "AiManager start for process video failed");
        }
    }

    private void showProcessVideoAiStartFailure(@NonNull ProcessVideoAiSession.CreateFailure failure) {
        switch (failure) {
            case ENGINE_NOT_RUNNING:
                showSelectedVideoStatus(R.string.ai_vision_ai_engine_not_ready);
                ToastUtils.showShort(R.string.ai_vision_ai_engine_not_ready);
                Log.w(TAG, "process video AI blocked: AiManager not running");
                break;
            case OFFLINE_JNI_UNAVAILABLE:
                showSelectedVideoStatus(R.string.ai_vision_offline_inference_not_available);
                ToastUtils.showShort(R.string.ai_vision_offline_inference_not_available);
                break;
            case SOURCE_INVALID:
            case DURATION_UNAVAILABLE:
                showSelectedVideoStatus(R.string.video_loading_failed_text);
                ToastUtils.showShort(R.string.video_loading_failed_text);
                Log.w(TAG, "process video AI blocked: " + failure);
                break;
            case NONE:
            default:
                break;
        }
    }

    private void refreshAiOverlayFromCapabilities() {
        if (binding == null) {
            return;
        }
        AiEngineCapabilityProfile capabilities = aiEngineCapabilities();
        if (!capabilities.isClassificationEnabled()) {
            overlayClassificationLine = getString(R.string.ai_overlay_cls_disabled);
        }
        if (!capabilities.isFocusMonitoringExpected()) {
            applyAiStateWithoutFocusMonitoring();
        } else {
            syncActiveDetectionOverlay();
        }
    }

    private void applyAiStateWithoutFocusMonitoring() {
        DeviceStatus status = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        boolean laserOn = status != null && status.isLaserOn();
        if (laserOn && AiManager.getInstance().isOpencvStainDetectSessionActive()) {
            overlayEngineDetailLine = OpencvStainDetectResult.OVERLAY_STATUS;
        } else if (laserOn && aiEngineCapabilities().isDetectionEnabled()) {
            overlayEngineDetailLine = getString(R.string.ai_overlay_state_stain_detect);
        } else {
            overlayEngineDetailLine = getString(R.string.ai_overlay_state_idle);
        }
        if (isLiveRtspOverlayActive()) {
            updateLiveInferenceOverlay();
        } else {
            refreshDetectionOverlayHudOnly();
        }
    }

    /** Live RTSP preview overlay only — not process-video detect / replay. */
    private boolean isLiveRtspOverlayActive() {
        return streamStarted
                && !isProcessVideoDetectSessionActive()
                && !replayingDetectionOverlay;
    }

    /** Live detect overlay: gated by {@link CameraConfig#isAiVisionLiveDetectOverlayEnabled()}. */
    private boolean isLiveDetectOverlayActive() {
        if (isProcessVideoDetectSessionActive() || replayingDetectionOverlay) {
            return false;
        }
        if (isLiveRtspOverlayActive()) {
            return CameraConfig.isAiVisionLiveDetectOverlayEnabled();
        }
        return CameraConfig.isNativeAiVisionStreamDetectEnabled()
                && NativeStreamDetectCoordinator.getInstance().isAiVisionLiveActive()
                && selectedProcessVideo == null;
    }

    private void applyAiVisionPreviewModes() {
        AiManager manager = AiManager.getInstance();
        if (!manager.isRknnEngineRunning()) {
            return;
        }
        AiEngineCapabilityProfile capabilities = aiEngineCapabilities();
        manager.setAiVisionPreviewClassificationEnabled(capabilities.isClassificationEnabled());
        manager.setAiVisionPreviewDetectionEnabled(capabilities.isDetectionEnabled());
    }

    private void clearAiVisionPreviewModes() {
        AiManager manager = AiManager.getInstance();
        if (!manager.isRknnEngineRunning()) {
            return;
        }
        manager.setAiVisionPreviewClassificationEnabled(false);
        manager.setAiVisionPreviewDetectionEnabled(false);
    }

    private void updateLiveInferenceOverlay() {
        if (!isActive || binding == null || !isLiveDetectOverlayActive()) {
            return;
        }
        if (binding.ivLiveCompositedPreview != null) {
            binding.ivLiveCompositedPreview.setVisibility(View.GONE);
        }
        binding.textureVisionView.setVisibility(View.VISIBLE);
        List<DetectionOverlayView.Box> boxes = new ArrayList<>();
        String status = null;
        String message = null;
        OpencvStainDetectResult stain;
        if (CameraConfig.isNativeAiVisionStreamDetectEnabled()) {
            StreamDetectOverlayBridge overlayBridge = StreamDetectOverlayBridge.getInstance();
            if (overlayBridge.hasPipelineError()) {
                applyDetectionOverlay(null, null,
                        getString(R.string.ai_overlay_result_waiting), true);
                return;
            }
            stain = overlayBridge.getLatestStainIfFresh();
        } else {
            stain = null;
        }
        if (AiManager.getInstance().isOpencvStainDetectSessionActive()
                && stain != null
                && stain.hasTarget()) {
            boxes.addAll(DetectionOverlayMapper.fromOpencvStainDetect(
                    stain, AI_FRAME_SAMPLE_WIDTH, AI_FRAME_SAMPLE_HEIGHT));
            status = OpencvStainDetectResult.OVERLAY_STATUS;
            message = null;
        }
        ZeroPointOverlaySnapshot zeroPoint = ZeroPointOverlayState.getInstance().getSnapshot();
        if (boxes.isEmpty() && zeroPoint == null) {
            applyDetectionOverlay(null, null, null, true);
            return;
        }
        applyDetectionOverlay(boxes, status, message, true);
    }

    private void applyZeroPointOverlay(@Nullable ZeroPointOverlaySnapshot snapshot) {
        if (!isActive || binding == null) {
            return;
        }
        if (snapshot != null && isLiveRtspOverlayActive()) {
            updateZeroPointOverlayContentRect(snapshot);
        }
        binding.viewDetectionOverlay.setZeroPointOverlay(snapshot);
        if (isLiveRtspOverlayActive()) {
            updateLiveInferenceOverlay();
        } else if (snapshot != null) {
            binding.viewDetectionOverlay.setVisibility(View.VISIBLE);
        }
    }

    private void updateZeroPointOverlayContentRect(@NonNull ZeroPointOverlaySnapshot snapshot) {
        if (binding == null) {
            return;
        }
        int viewW = binding.viewDetectionOverlay.getWidth();
        int viewH = binding.viewDetectionOverlay.getHeight();
        if (viewW <= 0 || viewH <= 0) {
            binding.viewDetectionOverlay.post(() -> updateZeroPointOverlayContentRect(snapshot));
            return;
        }
        RectF contentRect = OverlayGeometry.computeFitCenterContentRect(
                viewW, viewH, snapshot.frameWidth, snapshot.frameHeight);
        binding.viewDetectionOverlay.setVideoContentRect(contentRect);
    }

    private void applyDetectionOverlay(
            @Nullable List<DetectionOverlayView.Box> boxes,
            @Nullable String status,
            @Nullable String message,
            boolean engineFallback) {
        applyDetectionOverlay(boxes, status, message, engineFallback, null);
    }

    private void applyDetectionOverlay(
            @Nullable List<DetectionOverlayView.Box> boxes,
            @Nullable String status,
            @Nullable String message,
            boolean engineFallback,
            @Nullable ProcessVideoAiTimeline.Frame timelineFrame) {
        if (binding == null) {
            return;
        }
        ZeroPointOverlaySnapshot zeroPoint = ZeroPointOverlayState.getInstance().getSnapshot();
        if (isRecordedVideoOverlayMappingActive()) {
            updateRecordedVideoOverlayContentRect(timelineFrame);
        } else if (isLiveRtspOverlayActive() && zeroPoint != null) {
            updateZeroPointOverlayContentRect(zeroPoint);
        } else {
            binding.viewDetectionOverlay.setVideoContentRect(null);
        }
        bindDetectionOverlayHud(status, message, engineFallback);
        if (isSelectedVideoHudActive() && pickOverlayStatusLine(status) == null) {
            showAiOverlayHudIdleStatus();
        }
        boolean hasBoxes = boxes != null && !boxes.isEmpty();
        boolean hasHud = overlayHasHudContent(status, message, engineFallback)
                || isSelectedVideoHudActive();
        boolean hasZeroPoint = zeroPoint != null;
        if (!hasBoxes && !hasHud && !hasZeroPoint) {
            clearDetectionOverlayLayer();
            hideAiOverlayHudCard();
            return;
        }
        if (hasBoxes || hasZeroPoint) {
            binding.viewDetectionOverlay.setVisibility(View.VISIBLE);
            binding.viewDetectionOverlay.setBoxes(boxes);
            binding.viewDetectionOverlay.setZeroPointOverlay(zeroPoint);
        } else {
            clearDetectionOverlayLayer();
        }
    }

    private boolean isSelectedVideoHudActive() {
        return selectedProcessVideo != null
                && !isLiveRtspOverlayActive()
                && (isProcessVideoDetectSessionActive() || replayingDetectionOverlay || isSelectedVideoOverlayResident());
    }

    /** Selected process video is on screen (cover or player) but Detect is not running. */
    private boolean isSelectedVideoOverlayResident() {
        return selectedProcessVideo != null
                && !isLiveRtspOverlayActive()
                && !isProcessVideoDetectSessionActive()
                && !replayingDetectionOverlay;
    }

    @NonNull
    private String formatIdleHudStatusLine() {
        return getString(R.string.ai_overlay_hud_status_prefix, getString(R.string.ai_overlay_hud_status_idle));
    }

    /** Recorded-video overlay: map normalized boxes through fit-center video bounds in the player. */
    private boolean isRecordedVideoOverlayMappingActive() {
        return isProcessVideoDetectSessionActive()
                || replayingDetectionOverlay
                || (selectedVideoPlayer != null
                && selectedProcessVideo != null
                && !isLiveRtspOverlayActive());
    }

    private void updateRecordedVideoOverlayContentRect(@Nullable ProcessVideoAiTimeline.Frame frame) {
        if (binding == null) {
            return;
        }
        int viewW = binding.viewDetectionOverlay.getWidth();
        int viewH = binding.viewDetectionOverlay.getHeight();
        if (viewW <= 0 || viewH <= 0) {
            binding.viewDetectionOverlay.setVideoContentRect(null);
            return;
        }
        int videoW = resolveSourceVideoWidth(frame);
        int videoH = resolveSourceVideoHeight(frame);
        RectF contentRect = OverlayGeometry.computeFitCenterContentRect(
                viewW, viewH, videoW, videoH);
        binding.viewDetectionOverlay.setVideoContentRect(contentRect);
    }

    private int resolveSourceVideoWidth(@Nullable ProcessVideoAiTimeline.Frame frame) {
        int fromPlayer = readSelectedVideoPlayerWidth();
        if (fromPlayer > 0) {
            return fromPlayer;
        }
        if (frame != null && frame.imageWidth > 0) {
            return frame.imageWidth;
        }
        return parseVideoDimensionFromMetadata(true);
    }

    private int resolveSourceVideoHeight(@Nullable ProcessVideoAiTimeline.Frame frame) {
        int fromPlayer = readSelectedVideoPlayerHeight();
        if (fromPlayer > 0) {
            return fromPlayer;
        }
        if (frame != null && frame.imageHeight > 0) {
            return frame.imageHeight;
        }
        return parseVideoDimensionFromMetadata(false);
    }

    private int readSelectedVideoPlayerWidth() {
        if (selectedVideoPlayer == null) {
            return 0;
        }
        Format format = selectedVideoPlayer.getVideoFormat();
        return format != null ? format.width : 0;
    }

    private int readSelectedVideoPlayerHeight() {
        if (selectedVideoPlayer == null) {
            return 0;
        }
        Format format = selectedVideoPlayer.getVideoFormat();
        return format != null ? format.height : 0;
    }

    private int parseVideoDimensionFromMetadata(boolean width) {
        if (selectedProcessVideo == null) {
            return 0;
        }
        String resolution = selectedProcessVideo.getResolution();
        if (TextUtils.isEmpty(resolution)) {
            return 0;
        }
        int sep = resolution.indexOf('x');
        if (sep <= 0) {
            return 0;
        }
        try {
            if (width) {
                return Integer.parseInt(resolution.substring(0, sep).trim());
            }
            return Integer.parseInt(resolution.substring(sep + 1).trim());
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    /** Refresh HUD lines only (classification / engine) while keeping current boxes. */
    private void refreshDetectionOverlayHudOnly() {
        if (binding == null) {
            return;
        }
        OpencvStainDetectResult stain = null;
        if (CameraConfig.isNativeAiVisionStreamDetectEnabled()) {
            stain = StreamDetectOverlayBridge.getInstance().getLatestStainIfFresh();
        }
        if (stain != null && stain.hasTarget() && isLiveRtspOverlayActive()) {
            bindDetectionOverlayHud(OpencvStainDetectResult.OVERLAY_STATUS, null, true);
            return;
        }
        ProcessVideoAiTimeline.Frame frame = null;
        ProcessVideoAiTimeline timeline = resolvePlaybackTimeline();
        if (selectedVideoPlayer != null && timeline != null) {
            frame = timeline.findFrameAt(selectedVideoPlayer.getCurrentPosition());
        }
        if (frame != null) {
            bindDetectionOverlayHud(
                    pickTimelineOverlayStatus(frame),
                    pickTimelineOverlayMessage(frame),
                    false);
        } else if (isSelectedVideoOverlayResident()) {
            showAiOverlayHudIdleStatus();
        } else {
            bindDetectionOverlayHud(null, null, isLiveRtspOverlayActive());
        }
    }

    private void bindDetectionOverlayHud(
            @Nullable String status,
            @Nullable String message,
            boolean engineFallback) {
        if (binding == null) {
            return;
        }
        String statusLine = pickOverlayStatusLine(status);
        String detailLine = pickOverlayDetailLine(status, message);
        boolean residentEngineState = false;
        if (engineFallback
                && statusLine == null
                && detailLine == null
                && overlayEngineDetailLine != null) {
            statusLine = overlayEngineDetailLine;
            residentEngineState = true;
        }
        String formattedStatus = formatHudStatusLine(statusLine, residentEngineState);
        if (formattedStatus == null || formattedStatus.trim().isEmpty()) {
            binding.tvAiOverlayHudStatus.setVisibility(View.GONE);
        } else {
            binding.tvAiOverlayHudStatus.setText(formattedStatus);
            binding.tvAiOverlayHudStatus.setVisibility(View.VISIBLE);
        }
        if (detailLine != null
                && (formattedStatus == null || !detailLine.equalsIgnoreCase(formattedStatus))) {
            binding.tvAiOverlayHudDetail.setText(detailLine);
            binding.tvAiOverlayHudDetail.setVisibility(View.VISIBLE);
        } else {
            binding.tvAiOverlayHudDetail.setVisibility(View.GONE);
        }
        boolean hasHudContent = binding.tvAiOverlayHudStatus.getVisibility() == View.VISIBLE
                || binding.tvAiOverlayHudDetail.getVisibility() == View.VISIBLE;
        binding.layoutAiOverlayHud.setVisibility(hasHudContent ? View.VISIBLE : View.GONE);
    }

    @Nullable
    private String formatHudStatusLine(@Nullable String statusLine, boolean residentEngineState) {
        if (statusLine == null || statusLine.trim().isEmpty()) {
            return null;
        }
        String trimmed = statusLine.trim();
        if (residentEngineState && OpencvStainDetectResult.OVERLAY_STATUS.equals(trimmed)) {
            return getString(R.string.ai_overlay_hud_state_prefix, trimmed);
        }
        return getString(R.string.ai_overlay_hud_status_prefix, trimmed);
    }

    private void syncActiveDetectionOverlay() {
        if (isLiveRtspOverlayActive()) {
            updateLiveInferenceOverlay();
            return;
        }
        if (isProcessVideoDetectSessionActive() || replayingDetectionOverlay) {
            updateOfflineInferenceOverlay();
            return;
        }
        refreshDetectionOverlayHudOnly();
    }

    private boolean overlayHasHudContent(
            @Nullable String status,
            @Nullable String message,
            boolean engineFallback) {
        if (pickOverlayStatusLine(status) != null || pickOverlayDetailLine(status, message) != null) {
            return true;
        }
        return engineFallback && overlayEngineDetailLine != null;
    }

    @Nullable
    private String resolveEngineDetailForState(int state) {
        if (state == 1) {
            return getString(R.string.ai_overlay_state_monitoring);
        }
        if (state == 2) {
            return getString(R.string.ai_overlay_state_locked);
        }
        return getString(R.string.ai_overlay_state_idle);
    }

    @Nullable
    private static String pickOverlayStatusLine(@Nullable String status) {
        if (status == null || status.trim().isEmpty()) {
            return null;
        }
        if (isProdAiOverlayErrorStatus(status)) {
            return "RUNNING";
        }
        if (AiStainDetectResultMapper.isNonDisplayOverlayStatus(status)) {
            return null;
        }
        return status.trim();
    }

    @Nullable
    private static String pickOverlayDetailLine(@Nullable String status, @Nullable String message) {
        if (message == null || message.trim().isEmpty()) {
            return null;
        }
        if (isProdAiOverlayErrorStatus(status)) {
            return null;
        }
        String msg = message.trim();
        if (status != null && status.trim().equalsIgnoreCase(msg)) {
            return null;
        }
        return msg;
    }

    private static boolean isProdAiOverlayErrorStatus(@Nullable String status) {
        return AppRuntimeEnvironment.getEffectiveTier() == AppRuntimeEnvironment.Tier.PROD
                && status != null
                && "ERROR".equalsIgnoreCase(status.trim());
    }
}
