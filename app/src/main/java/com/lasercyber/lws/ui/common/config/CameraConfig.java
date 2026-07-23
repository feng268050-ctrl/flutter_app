package com.lasercyber.lws.ui.common.config;

import android.os.Environment;
import android.util.Base64;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ui.common.utils.AndroidEmulatorUtils;
import com.lasercyber.lws.ui.network.mediamtx.MediaMtxRelayUrls;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;

/**
 * 摄像头配置（IPC 硬件/固件固定参数；IP 可由 ROM {@code /system/etc/model.properties} 覆盖）。
 */
public class CameraConfig {
    /** 摄像头出厂默认 IP（与平板 eth0 同 /24）。 */
    public static final String DEFAULT_CAMERA_IP = "192.168.1.100";
    /**
     * 出厂默认摄像头 IP。运行时应使用 {@link #getCameraIp()}（支持 model.properties 中的 {@code camera_ip}）。
     */
    public static final String CAMERA_IP = DEFAULT_CAMERA_IP;
    /** 摄像头网段子网掩码（/24） */
    public static final String CAMERA_NETMASK = "255.255.255.0";
    /** RTSP 主流路径（实时预览 / 录制 / PR0） */
    public static final String CAMERA_RTSP_MAIN_PATH = "/PR0";
    /** RTSP 子流路径（AI 推理独占 / PR1） */
    public static final String CAMERA_RTSP_SUB_PATH = "/PR1";
    /** IPC HTTP API 默认端口（eth0 直连）。 */
    public static final int DEFAULT_CAMERA_HTTP_PORT = 9000;
    /**
     * 有效摄像头 IP：{@code model.properties} 中的 {@code camera_ip}，否则 {@link #DEFAULT_CAMERA_IP}。
     */
    public static String getCameraIp() {
        String fromRom = DeviceModelConfig.getCameraIp();
        return fromRom != null ? fromRom : DEFAULT_CAMERA_IP;
    }

    /**
     * 摄像头 HTTP API 根地址（端口固定 {@link #DEFAULT_CAMERA_HTTP_PORT}）。
     */
    public static String getBaseCameraAppUrl() {
        return "http://" + getCameraIp() + ":" + DEFAULT_CAMERA_HTTP_PORT + "/";
    }

    /**
     * eth0 摄像头的 HTTP 根地址（{@link com.lasercyber.lws.ui.network.http.local.CameraLanHttpProxy} 上游）。
     * 始终指向 IPC 默认地址，与 {@code camera_ip}（RTSP 中继对端）解耦。
     */
    public static String getUpstreamCameraAppUrl() {
        return "http://" + DEFAULT_CAMERA_IP + ":" + DEFAULT_CAMERA_HTTP_PORT + "/";
    }

    /**
     * MediaMTX {@code paths.camera/pr0.source} upstream URL.
     */
    public static String getMediaMtxUpstreamPr0RtspUrl() {
        return resolveMediaMtxUpstreamRtspUrl(CAMERA_RTSP_MAIN_PATH, MediaMtxRelayUrls.PATH_PR0);
    }

    /**
     * MediaMTX {@code paths.camera/pr1.source} upstream URL.
     */
    public static String getMediaMtxUpstreamPr1RtspUrl() {
        return resolveMediaMtxUpstreamRtspUrl(CAMERA_RTSP_SUB_PATH, MediaMtxRelayUrls.PATH_PR1);
    }

    /**
     * When {@code camera_ip} is the IPC ({@link #DEFAULT_CAMERA_IP}), pull RTSP directly from the camera.
     * Otherwise pull from the peer relay at {@code rtsp://<camera_ip>:8554/<mediamtxPath>}.
     */
    private static String resolveMediaMtxUpstreamRtspUrl(@NonNull String cameraRtspPath,
                                                         @NonNull String mediamtxPath) {
        String host = getCameraIp();
        if (DEFAULT_CAMERA_IP.equals(host)) {
            return "rtsp://" + host + cameraRtspPath;
        }
        return MediaMtxRelayUrls.lanRelay(host, mediamtxPath);
    }

    /** 摄像头 RTSP 主流（与 {@link #CAMERA_RTSP_MAIN_PATH} 一致） */
    public static String getCameraRtspMainUrl() {
        return "rtsp://" + getCameraIp() + CAMERA_RTSP_MAIN_PATH;
    }

    public static String getCameraRtspSubUrl() {
        return "rtsp://" + getCameraIp() + CAMERA_RTSP_SUB_PATH;
    }

    /**
     * 录制专用：主流 URL（IPC 侧通常为 1080p）。
     */
    public static String getRecordingRtspUrl() {
        return getCameraRtspMainUrl();
    }

    /**
     * {@code model.properties} 中显式配置的 {@code camera_ip}，且不是出厂 IPC 默认地址。
     * 用于模拟器/无本机 MediaMTX 时连接对端平板中继 {@code rtsp://<ip>:8554/camera/pr0}。
     */
    @Nullable
    public static String getPeerRelayCameraIp() {
        String fromRom = DeviceModelConfig.getCameraIp();
        if (fromRom == null || fromRom.trim().isEmpty()) {
            return null;
        }
        String trimmed = fromRom.trim();
        return DEFAULT_CAMERA_IP.equals(trimmed) ? null : trimmed;
    }

    public static boolean isPeerRelayCameraIpConfigured() {
        return getPeerRelayCameraIp() != null;
    }

    /**
     * PR0-only RTSP ingest candidates for live preview and process-video recording (never PR1).
     */
    @NonNull
    public static List<String> getPr0IngestCandidates(boolean localRelayReady) {
        return buildPr0RecordingRtspCandidates(
                localRelayReady,
                getPeerRelayCameraIp(),
                AndroidEmulatorUtils.isLikelyEmulator());
    }

    /**
     * PR1-only RTSP ingest candidates for live inference and AI Vision dual-link playback/detect.
     */
    @NonNull
    public static List<String> getPr1IngestCandidates(boolean localRelayReady) {
        return buildPr1InferenceRtspCandidates(
                localRelayReady,
                getPeerRelayCameraIp(),
                AndroidEmulatorUtils.isLikelyEmulator());
    }

    @VisibleForTesting
    @NonNull
    static List<String> buildPr1InferenceRtspCandidates(
            boolean localRelayReady,
            @Nullable String peerRelayCameraIp,
            boolean emulator) {
        LinkedHashSet<String> urls = new LinkedHashSet<>();
        if (emulator) {
            if (peerRelayCameraIp != null) {
                urls.add(MediaMtxRelayUrls.lanPr1(peerRelayCameraIp));
            }
            return new ArrayList<>(urls);
        }
        if (localRelayReady) {
            urls.add(MediaMtxRelayUrls.localPr1());
        } else if (peerRelayCameraIp != null) {
            urls.add(MediaMtxRelayUrls.lanPr1(peerRelayCameraIp));
        }
        urls.add("rtsp://" + DEFAULT_CAMERA_IP + CAMERA_RTSP_SUB_PATH);
        return new ArrayList<>(urls);
    }

    @VisibleForTesting
    @NonNull
    static List<String> buildPr0RecordingRtspCandidates(
            boolean localRelayReady,
            @Nullable String peerRelayCameraIp,
            boolean emulator) {
        LinkedHashSet<String> urls = new LinkedHashSet<>();
        if (emulator) {
            if (peerRelayCameraIp != null) {
                urls.add(MediaMtxRelayUrls.lanPr0(peerRelayCameraIp));
            }
            return new ArrayList<>(urls);
        }
        if (localRelayReady) {
            urls.add(MediaMtxRelayUrls.localPr0());
        } else if (peerRelayCameraIp != null) {
            urls.add(MediaMtxRelayUrls.lanPr0(peerRelayCameraIp));
        }
        urls.add("rtsp://" + DEFAULT_CAMERA_IP + CAMERA_RTSP_MAIN_PATH);
        return new ArrayList<>(urls);
    }

    /**
     * 实时预览：主流经本机 MediaMTX {@code camera/pr0}（勿用 PR1）。
     */
    public static String getLivePreviewRtspUrl() {
        return MediaMtxRelayUrls.localPr0();
    }

    /**
     * AI 推理专用：子流经本机 MediaMTX {@code camera/pr1}（勿用于实时预览）。
     */
    public static String getLiveInferenceRtspUrl() {
        return MediaMtxRelayUrls.localPr1();
    }

    /**
     * 摄像头的用户名
     */
    public static final String CAMERA_USER_NAME = "admin";
    /**
     * 摄像头的密码
     */
    public static final String CAMERA_PASSWORD = "admin";

    /**
     * 默认的视频时长（分钟）
     */
    public static final int DEFAULT_VIDEO_DURATION = 10;
    /**
     * 应用路径
     */
    public static final String APP_PATH = "/lws";
    /**
     * 视频保存路径（约定：外部存储根下 {@code /lws}，空间由产品/设备侧保证）
     */
    public static final String DEFAULT_VIDEO_SAVE_PATH = Environment.getExternalStorageDirectory() + APP_PATH;
    /**
     * 参考分辨率：与当前 IPC 主/子码流一致为 1080p；虚拟 Surface 等默认值用此。
     * 实际每帧宽高仍以解码回调（如 {@code RESULT_VIDEO_SIZE}）为准（部分流为 1920×1088 编码对齐）。
     */
    public static final int VIDEO_RESOLUTION_HEIGHT = 1080;
    /**
     * 见 {@link #VIDEO_RESOLUTION_HEIGHT}。
     */
    public static final int VIDEO_RESOLUTION_WIDTH = 1920;
    /**
     * 视频最大大小 350MB
     */
    public static final int MAX_VIDEO_SIZE = 350 * 1024 * 1024;

    /**
     * C++ {@code StreamDetectPipeline} for **weld** live detect (Quick / Engineer, laser ON).
     * Phase 4: always enabled; Java {@code LivePr1InferenceStreamClient} rollback removed.
     */
    public static boolean isNativeWeldStreamDetectEnabled() {
        return true;
    }

    /**
     * C++ detect parallel to Java PR1 playback on **AI Vision** live preview (Phase 3 dual-link).
     * Keep false under 4.4 fallback when RK3566 stress test fails; Java playback still uses PR1.
     */
    public static boolean isNativeAiVisionStreamDetectEnabled() {
        return false;
    }

    /**
     * True when any native {@code StreamDetectPipeline} session may run (weld and/or AI Vision).
     */
    public static boolean isNativeStreamDetectPipelineEnabled() {
        return isNativeWeldStreamDetectEnabled() || isNativeAiVisionStreamDetectEnabled();
    }

    /**
     * Whether AI Vision live RTSP should render stain-detect overlay (native bus only).
     * Under 4.4 fallback → playback-only, overlay hidden.
     */
    public static boolean isAiVisionLiveDetectOverlayEnabled() {
        return isNativeAiVisionStreamDetectEnabled();
    }

    /**
     * Log {@code AiVisionResolutionProfile} tag on decode policy / effective resolution (task 4.5).
     */
    public static boolean isAiVisionResolutionProfileLoggingEnabled() {
        return isAiVisionDualLinkFieldTestLoggingEnabled();
    }

    /**
     * Log live detect path timing to tag {@code LiveDetectPathProfiler} for RK3566 baseline.
     */
    public static boolean isLiveDetectPathProfilingEnabled() {
        return false;
    }

    /**
     * Emit structured dual-link metrics to tag {@code AiVisionDualLink} during RK3566 field test.
     */
    public static boolean isAiVisionDualLinkFieldTestLoggingEnabled() {
        return false;
    }

    /**
     * HTTP Basic 认证头值（由 {@link #CAMERA_USER_NAME} / {@link #CAMERA_PASSWORD} 派生）。
     */
    public static String basicAuthorization() {
        String credential = CAMERA_USER_NAME + ":" + CAMERA_PASSWORD;
        return "Basic " + Base64.encodeToString(
                credential.getBytes(StandardCharsets.UTF_8), Base64.NO_WRAP);
    }

    private CameraConfig() {
    }
}
