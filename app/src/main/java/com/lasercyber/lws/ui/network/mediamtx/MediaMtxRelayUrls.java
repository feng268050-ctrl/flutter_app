package com.lasercyber.lws.ui.network.mediamtx;

import androidx.annotation.NonNull;

/**
 * Canonical RTSP URLs for the device-hosted PR0/PR1 relay (MediaMTX paths {@code camera/pr0}, {@code camera/pr1}).
 */
public final class MediaMtxRelayUrls {

    public static final int RTSP_PORT = 8554;
    public static final String PATH_PR0 = "camera/pr0";
    public static final String PATH_PR1 = "camera/pr1";

    private MediaMtxRelayUrls() {
    }

    @NonNull
    public static String localPr0() {
        return localRelay(PATH_PR0);
    }

    @NonNull
    public static String localPr1() {
        return localRelay(PATH_PR1);
    }

    @NonNull
    public static String localRelay(@NonNull String path) {
        return "rtsp://127.0.0.1:" + RTSP_PORT + "/" + path;
    }

    @NonNull
    public static String lanPr0(@NonNull String deviceLanIp) {
        return lanRelay(deviceLanIp, PATH_PR0);
    }

    @NonNull
    public static String lanPr1(@NonNull String deviceLanIp) {
        return lanRelay(deviceLanIp, PATH_PR1);
    }

    @NonNull
    public static String lanRelay(@NonNull String deviceLanIp, @NonNull String path) {
        return "rtsp://" + deviceLanIp + ":" + RTSP_PORT + "/" + path;
    }

    /**
     * Ingest URL for PR0 recording: local MediaMTX when running, otherwise peer relay at {@code relayPeerHost}.
     */
    @NonNull
    public static String resolvePr0Ingest(boolean localRelayReady, @NonNull String relayPeerHost) {
        return localRelayReady ? localPr0() : lanPr0(relayPeerHost);
    }

    /**
     * Ingest URL for PR1 inference: local MediaMTX when running, otherwise peer relay at {@code relayPeerHost}.
     */
    @NonNull
    public static String resolvePr1Ingest(boolean localRelayReady, @NonNull String relayPeerHost) {
        return localRelayReady ? localPr1() : lanPr1(relayPeerHost);
    }

    /** True for local or peer MediaMTX fan-out reader URLs (no IPC RTSP credentials). */
    public static boolean isMediamtxFanoutUrl(@NonNull String rtspUrl) {
        return rtspUrl.contains("/" + PATH_PR0)
                || rtspUrl.contains("127.0.0.1:" + RTSP_PORT);
    }
}
