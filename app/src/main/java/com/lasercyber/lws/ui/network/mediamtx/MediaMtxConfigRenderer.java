package com.lasercyber.lws.ui.network.mediamtx;

import androidx.annotation.NonNull;

import com.lasercyber.lws.ui.common.config.CameraConfig;

/**
 * Renders MediaMTX YAML for upstream PR0/PR1 pulls and LAN/local fan-out.
 * Tuned for low latency: camera and device are on a direct Ethernet link (no router hop).
 */
public final class MediaMtxConfigRenderer {

    /** Smallest power-of-two queue MediaMTX v1.11 accepts; 0 is unsupported on bundled binary. */
    private static final int LOW_LATENCY_WRITE_QUEUE_SIZE = 32;

    private MediaMtxConfigRenderer() {
    }

    @NonNull
    public static String currentUpstreamPr0RtspUrl() {
        return CameraConfig.getMediaMtxUpstreamPr0RtspUrl();
    }

    @NonNull
    public static String currentUpstreamPr1RtspUrl() {
        return CameraConfig.getMediaMtxUpstreamPr1RtspUrl();
    }

    @NonNull
    public static String renderYaml() {
        return ""
                + "logLevel: info\n"
                + "logDestinations: [stdout]\n"
                + "writeQueueSize: " + LOW_LATENCY_WRITE_QUEUE_SIZE + "\n"
                + "rtspAddress: :" + MediaMtxRelayUrls.RTSP_PORT + "\n"
                + "paths:\n"
                + renderPath(MediaMtxRelayUrls.PATH_PR0, currentUpstreamPr0RtspUrl())
                + renderPath(MediaMtxRelayUrls.PATH_PR1, currentUpstreamPr1RtspUrl());
    }

    @NonNull
    private static String renderPath(@NonNull String path, @NonNull String upstream) {
        return "  " + path + ":\n"
                + "    source: " + upstream + "\n"
                + "    rtspTransport: udp\n"
                + "    sourceOnDemand: no\n";
    }
}
