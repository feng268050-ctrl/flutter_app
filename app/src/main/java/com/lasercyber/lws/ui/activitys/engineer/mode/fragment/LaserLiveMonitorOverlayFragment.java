package com.lasercyber.lws.ui.activitys.engineer.mode.fragment;

import android.graphics.SurfaceTexture;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.ResultReceiver;
import android.os.SystemClock;
import android.util.Log;
import android.view.Surface;
import android.view.TextureView;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.LinearLayout;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ai.stream.StreamDetectOverlayBridge;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.device.monitor.fragment.MachineStatusBaseFragment;
import com.lasercyber.lws.ui.bean.entity.DeviceData;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.ai.overlay.DetectionOverlayMapper;
import com.lasercyber.lws.ui.common.config.CameraConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.common.view.CircleProgressView;
import com.lasercyber.lws.ui.common.view.DetectionOverlayView;
import com.lasercyber.lws.ui.databinding.FragmentLaserLiveMonitorOverlayBinding;
import com.lasercyber.lws.ui.network.mediamtx.MediaMtxRelayCoordinator;
import com.lasercyber.lws.ui.network.mediamtx.MediaMtxRelayUrls;

import org.easydarwin.video.Client;
import org.easydarwin.video.EasyPlayerClient;

import java.util.List;

/**
 * Shared Live Monitor overlay body: PR1 preview + detection boxes + compact gauges.
 * Does not own detect-pipeline lifecycle.
 */
public class LaserLiveMonitorOverlayFragment
        extends MachineStatusBaseFragment<FragmentLaserLiveMonitorOverlayBinding> {

    public static final String ARG_QUICK_MODE_MORE_MONITOR =
            MachineStatusDialogFragment.ARG_QUICK_MODE_MORE_MONITOR;

    private static final String TAG = LogTAGConstant.LaserLiveMonitorOverlay;
    private static final long STALE_CLEAR_MS = StreamDetectOverlayBridge.STALE_RESULT_MS;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    @Nullable
    private EasyPlayerClient playerClient;
    @Nullable
    private Surface playerSurface;
    private int playerGeneration;
    private boolean streamStarted;
    private boolean playerStopInProgress;
    private boolean fragmentActive;
    private boolean previewExpanded;
    private int collapsedPreviewHeightPx;
    @Nullable
    private ViewGroup.LayoutParams dialogContentSavedLp;
    private int dialogContentSavedVisibilityTitle = View.VISIBLE;
    private int dialogContentSavedVisibilityAction = View.VISIBLE;

    private final StreamDetectOverlayBridge.Listener detectListener =
            new StreamDetectOverlayBridge.Listener() {
                @Override
                public void onStreamDetectOverlayChanged(
                        @Nullable OpencvStainDetectResult stain, long frameId) {
                    mainHandler.post(() -> applyDetectResult(stain));
                }

                @Override
                public void onStreamDetectPipelineError(@NonNull String detail) {
                    Log.w(TAG, "stream detect pipeline error: " + detail);
                }
            };

    private final Runnable staleClearTask = () -> {
        if (binding != null) {
            binding.viewDetectionOverlay.clear();
        }
    };

    private final TextureView.SurfaceTextureListener surfaceTextureListener =
            new TextureView.SurfaceTextureListener() {
                @Override
                public void onSurfaceTextureAvailable(
                        @NonNull SurfaceTexture surface, int width, int height) {
                    startPreviewIfReady();
                }

                @Override
                public void onSurfaceTextureSizeChanged(
                        @NonNull SurfaceTexture surface, int width, int height) {
                }

                @Override
                public boolean onSurfaceTextureDestroyed(@NonNull SurfaceTexture surface) {
                    stopPreviewAsync("surface-destroyed");
                    return true;
                }

                @Override
                public void onSurfaceTextureUpdated(@NonNull SurfaceTexture surface) {
                }
            };

    public void prepareForOverlayShow() {
        setDeferGaugeRendering(true);
    }

    @Override
    protected int getLayoutId() {
        return R.layout.fragment_laser_live_monitor_overlay;
    }

    @Override
    protected void initView() {
        super.initView();
        boolean quickModeMoreMonitor = getArguments() != null
                && getArguments().getBoolean(ARG_QUICK_MODE_MORE_MONITOR, false);
        if (quickModeMoreMonitor) {
            relaxClipForGauges();
        }
        collapsedPreviewHeightPx = getResources()
                .getDimensionPixelSize(R.dimen.laser_live_monitor_preview_min_height);
        binding.textureLiveMonitor.setSurfaceTextureListener(surfaceTextureListener);
        binding.tvPreviewStatus.setText(R.string.live_video_loading);
        binding.tvPreviewStatus.setVisibility(View.VISIBLE);
        binding.btnLiveMonitorExpand.setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            setPreviewExpanded(!previewExpanded);
        });
        applyExpandChrome(false);
    }

    @Override
    protected void initData() {
        super.initData();
        fragmentActive = true;
        StreamDetectOverlayBridge bridge = StreamDetectOverlayBridge.getInstance();
        bridge.ensureSubscribed();
        bridge.addListener(detectListener);
        OpencvStainDetectResult fresh = bridge.getLatestStainIfFresh();
        if (fresh != null) {
            applyDetectResult(fresh);
        }
        if (binding.textureLiveMonitor.isAvailable()) {
            startPreviewIfReady();
        }
    }

    @Override
    public void onDestroyView() {
        if (previewExpanded) {
            setPreviewExpanded(false);
        }
        fragmentActive = false;
        mainHandler.removeCallbacks(staleClearTask);
        StreamDetectOverlayBridge.getInstance().removeListener(detectListener);
        stopPreviewAsync("destroy-view");
        if (binding != null) {
            binding.textureLiveMonitor.setSurfaceTextureListener(null);
        }
        super.onDestroyView();
    }

    @Override
    protected void setDeviceData(DeviceData deviceData) {
        if (binding == null) {
            return;
        }
        binding.setDeviceData(deviceData);
    }

    @Override
    protected void setDeviceStatus(DeviceStatus deviceStatus) {
        if (binding == null) {
            return;
        }
        binding.setDeviceStatus(deviceStatus);
    }

    @Override
    protected void setCameraCommFault(boolean cameraCommFault) {
        if (binding == null || streamStarted) {
            return;
        }
        if (cameraCommFault) {
            binding.tvPreviewStatus.setText(R.string.unable_to_open_the_camera_title);
            binding.tvPreviewStatus.setVisibility(View.VISIBLE);
        }
    }

    @Override
    protected CircleProgressView getLeftCircleView() {
        return binding.leftCircleView;
    }

    @Override
    protected CircleProgressView getRightCircleView() {
        return binding.rightCircleView;
    }

    private void relaxClipForGauges() {
        View root = binding.getRoot();
        if (root instanceof ViewGroup group) {
            group.setClipChildren(false);
            group.setClipToPadding(false);
        }
        binding.leftCircleViewContainer.setClipChildren(false);
        binding.leftCircleViewContainer.setClipToPadding(false);
        binding.rightCircleViewContainer.setClipChildren(false);
        binding.rightCircleViewContainer.setClipToPadding(false);
    }

    private void setPreviewExpanded(boolean expanded) {
        if (binding == null || previewExpanded == expanded) {
            return;
        }
        previewExpanded = expanded;
        applyExpandChrome(expanded);
    }

    private void applyExpandChrome(boolean expanded) {
        if (binding == null) {
            return;
        }
        ViewGroup.LayoutParams rootLp = binding.liveMonitorRoot.getLayoutParams();
        if (rootLp != null) {
            rootLp.height = expanded
                    ? ViewGroup.LayoutParams.MATCH_PARENT
                    : collapsedPreviewHeightPx;
            binding.liveMonitorRoot.setLayoutParams(rootLp);
            binding.liveMonitorRoot.setMinimumHeight(
                    expanded ? 0 : collapsedPreviewHeightPx);
        }

        View bodyHost = binding.getRoot().getParent() instanceof View parent ? parent : null;
        if (bodyHost != null) {
            ViewGroup.LayoutParams bodyLp = bodyHost.getLayoutParams();
            if (bodyLp != null) {
                bodyLp.height = expanded
                        ? ViewGroup.LayoutParams.MATCH_PARENT
                        : ViewGroup.LayoutParams.WRAP_CONTENT;
                bodyHost.setLayoutParams(bodyLp);
                bodyHost.setMinimumHeight(expanded ? 0 : collapsedPreviewHeightPx);
            }
        }

        View dialogRoot = binding.getRoot().getRootView();
        View titleSection = dialogRoot.findViewById(R.id.frost_dialog_title_section);
        View actionSection = dialogRoot.findViewById(R.id.frost_dialog_action_section);
        View dialogContent = dialogRoot.findViewById(R.id.frost_dialog_content);
        View bodySlot = dialogRoot.findViewById(R.id.frost_dialog_body_slot);
        View foreground = dialogRoot.findViewById(R.id.frost_dialog_light_foreground);

        if (expanded) {
            if (titleSection != null) {
                dialogContentSavedVisibilityTitle = titleSection.getVisibility();
                titleSection.setVisibility(View.GONE);
            }
            if (actionSection != null) {
                dialogContentSavedVisibilityAction = actionSection.getVisibility();
                actionSection.setVisibility(View.GONE);
            }
            if (dialogContent != null) {
                if (dialogContentSavedLp == null) {
                    dialogContentSavedLp = copyLayoutParams(dialogContent.getLayoutParams());
                }
                int edge = getResources()
                        .getDimensionPixelSize(R.dimen.laser_live_monitor_expanded_edge_inset);
                ViewGroup.LayoutParams lp = dialogContent.getLayoutParams();
                lp.width = ViewGroup.LayoutParams.MATCH_PARENT;
                lp.height = ViewGroup.LayoutParams.MATCH_PARENT;
                if (lp instanceof ViewGroup.MarginLayoutParams marginLp) {
                    marginLp.setMargins(edge, edge, edge, edge);
                }
                dialogContent.setLayoutParams(lp);
            }
            if (bodySlot != null) {
                ViewGroup.LayoutParams lp = bodySlot.getLayoutParams();
                if (lp instanceof LinearLayout.LayoutParams linearLp) {
                    linearLp.height = 0;
                    linearLp.weight = 1f;
                    bodySlot.setLayoutParams(linearLp);
                } else if (lp != null) {
                    lp.height = ViewGroup.LayoutParams.MATCH_PARENT;
                    bodySlot.setLayoutParams(lp);
                }
            }
            if (foreground != null) {
                ViewGroup.LayoutParams lp = foreground.getLayoutParams();
                if (lp != null) {
                    lp.height = ViewGroup.LayoutParams.MATCH_PARENT;
                    foreground.setLayoutParams(lp);
                }
                foreground.setPadding(
                        foreground.getPaddingLeft(),
                        0,
                        foreground.getPaddingRight(),
                        0);
            }
            binding.btnLiveMonitorExpand.setImageResource(R.drawable.ic_live_monitor_fullscreen_exit);
            binding.btnLiveMonitorExpand.setContentDescription(
                    getString(R.string.live_monitor_collapse));
        } else {
            if (titleSection != null) {
                titleSection.setVisibility(dialogContentSavedVisibilityTitle);
            }
            if (actionSection != null) {
                actionSection.setVisibility(dialogContentSavedVisibilityAction);
            }
            if (dialogContent != null && dialogContentSavedLp != null) {
                dialogContent.setLayoutParams(copyLayoutParams(dialogContentSavedLp));
            }
            if (bodySlot != null) {
                ViewGroup.LayoutParams lp = bodySlot.getLayoutParams();
                if (lp instanceof LinearLayout.LayoutParams linearLp) {
                    linearLp.height = ViewGroup.LayoutParams.WRAP_CONTENT;
                    linearLp.weight = 0f;
                    bodySlot.setLayoutParams(linearLp);
                } else if (lp != null) {
                    lp.height = ViewGroup.LayoutParams.WRAP_CONTENT;
                    bodySlot.setLayoutParams(lp);
                }
            }
            if (foreground != null) {
                ViewGroup.LayoutParams lp = foreground.getLayoutParams();
                if (lp != null) {
                    lp.height = ViewGroup.LayoutParams.WRAP_CONTENT;
                    foreground.setLayoutParams(lp);
                }
                int chromePad = getResources()
                        .getDimensionPixelSize(R.dimen.laser_live_monitor_dialog_chrome_pad);
                foreground.setPadding(
                        foreground.getPaddingLeft(),
                        chromePad,
                        foreground.getPaddingRight(),
                        chromePad);
            }
            binding.btnLiveMonitorExpand.setImageResource(R.drawable.ic_live_monitor_fullscreen);
            binding.btnLiveMonitorExpand.setContentDescription(
                    getString(R.string.live_monitor_expand));
        }
        binding.liveMonitorRoot.requestLayout();
    }

    @NonNull
    private static ViewGroup.LayoutParams copyLayoutParams(@NonNull ViewGroup.LayoutParams source) {
        if (source instanceof FrameLayout.LayoutParams frame) {
            return new FrameLayout.LayoutParams(frame);
        }
        if (source instanceof LinearLayout.LayoutParams linear) {
            return new LinearLayout.LayoutParams(linear);
        }
        if (source instanceof ViewGroup.MarginLayoutParams margin) {
            return new ViewGroup.MarginLayoutParams(margin);
        }
        return new ViewGroup.LayoutParams(source);
    }

    private void applyDetectResult(@Nullable OpencvStainDetectResult stain) {
        if (binding == null || !fragmentActive) {
            return;
        }
        mainHandler.removeCallbacks(staleClearTask);
        if (stain == null) {
            binding.viewDetectionOverlay.clear();
            return;
        }
        List<DetectionOverlayView.Box> boxes = DetectionOverlayMapper.fromOpencvStainDetect(
                stain,
                stain.imageWidth,
                stain.imageHeight);
        binding.viewDetectionOverlay.setBoxes(boxes);
        mainHandler.postDelayed(staleClearTask, STALE_CLEAR_MS);
    }

    private void startPreviewIfReady() {
        if (!fragmentActive || binding == null || playerStopInProgress || streamStarted) {
            return;
        }
        TextureView textureView = binding.textureLiveMonitor;
        if (!textureView.isAvailable() || textureView.getSurfaceTexture() == null) {
            return;
        }
        ensurePlayerClient();
        if (playerClient == null) {
            binding.tvPreviewStatus.setText(R.string.unable_to_open_the_camera_title);
            binding.tvPreviewStatus.setVisibility(View.VISIBLE);
            return;
        }
        boolean localRelay = MediaMtxRelayCoordinator.getInstance().isRelayReady();
        List<String> candidates = CameraConfig.getPr1IngestCandidates(localRelay);
        if (candidates.isEmpty()) {
            binding.tvPreviewStatus.setText(R.string.unable_to_open_the_camera_title);
            binding.tvPreviewStatus.setVisibility(View.VISIBLE);
            return;
        }
        String rtspUrl = candidates.get(0);
        String user = CameraConfig.CAMERA_USER_NAME;
        String pass = CameraConfig.CAMERA_PASSWORD;
        if (MediaMtxRelayUrls.isMediamtxFanoutUrl(rtspUrl)) {
            user = "";
            pass = "";
        }
        binding.tvPreviewStatus.setText(R.string.live_video_loading);
        binding.tvPreviewStatus.setVisibility(View.VISIBLE);
        Log.i(TAG, "PR1 preview start url=" + rtspUrl);
        int code = playerClient.start(
                rtspUrl,
                Client.TRANSTYPE_TCP,
                0,
                Client.EASY_SDK_VIDEO_FRAME_FLAG,
                user,
                pass);
        if (code == 0) {
            streamStarted = true;
        } else {
            Log.w(TAG, "PR1 preview start failed code=" + code);
            binding.tvPreviewStatus.setText(R.string.unable_to_open_the_camera_title);
            binding.tvPreviewStatus.setVisibility(View.VISIBLE);
        }
    }

    private void ensurePlayerClient() {
        if (playerClient != null || binding == null || playerStopInProgress) {
            return;
        }
        TextureView textureView = binding.textureLiveMonitor;
        if (!textureView.isAvailable() || textureView.getSurfaceTexture() == null) {
            return;
        }
        releasePlayerSurface();
        playerSurface = new Surface(textureView.getSurfaceTexture());
        final int generation = ++playerGeneration;
        playerClient = new EasyPlayerClient(
                requireContext(),
                playerSurface,
                new ResultReceiver(new Handler(Looper.getMainLooper())) {
                    @Override
                    protected void onReceiveResult(int resultCode, Bundle resultData) {
                        if (generation != playerGeneration || !fragmentActive || binding == null) {
                            return;
                        }
                        if (resultCode == EasyPlayerClient.RESULT_VIDEO_DISPLAYED) {
                            binding.tvPreviewStatus.setVisibility(View.GONE);
                        }
                    }
                },
                null,
                null);
        playerClient.setAudioEnable(false);
        // RK356x MediaCodec can stall after each short-lived dialog Surface is created.
        // Decode directly through VideoDecoderLite so the first IDR is rendered immediately
        // instead of waiting 1.5 s for the MediaCodec first-output fallback.
        playerClient.setPreferVideoDecoderLite(true);
        // Keep normal decode startup for More Monitor. Low-latency mode discards
        // predictive frames before codec setup, then waits for a second keyframe;
        // with a multi-second camera GOP this can leave the preview black for several seconds.
        playerClient.setLowLatencyMode(false);
    }

    private void stopPreviewAsync(@NonNull String reason) {
        streamStarted = false;
        EasyPlayerClient client = playerClient;
        Surface surface = playerSurface;
        playerClient = null;
        playerSurface = null;
        playerGeneration++;
        if (client == null) {
            if (surface != null) {
                try {
                    surface.release();
                } catch (Throwable ignored) {
                }
            }
            return;
        }
        playerStopInProgress = true;
        long startMs = SystemClock.elapsedRealtime();
        new Thread(() -> {
            try {
                Log.i(TAG, "Stopping EasyPlayer asynchronously reason=" + reason);
                client.stop();
            } catch (Throwable t) {
                Log.w(TAG, "EasyPlayer stop threw reason=" + reason, t);
            } finally {
                if (surface != null) {
                    try {
                        surface.release();
                    } catch (Throwable ignored) {
                    }
                }
                long elapsed = SystemClock.elapsedRealtime() - startMs;
                mainHandler.post(() -> {
                    playerStopInProgress = false;
                    Log.i(TAG, "EasyPlayer stopped reason=" + reason + " elapsedMs=" + elapsed);
                    // A transient TextureView Surface replacement (dialog relayout/fullscreen)
                    // may finish while teardown is still running. Resume on its new Surface.
                    startPreviewIfReady();
                });
            }
        }, "laser-live-monitor-stop").start();
    }

    private void releasePlayerSurface() {
        Surface surface = playerSurface;
        playerSurface = null;
        if (surface == null) {
            return;
        }
        try {
            surface.release();
        } catch (Throwable ignored) {
        }
    }
}
