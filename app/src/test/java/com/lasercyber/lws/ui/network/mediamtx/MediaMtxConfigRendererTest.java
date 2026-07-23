package com.lasercyber.lws.ui.network.mediamtx;

import com.lasercyber.lws.ui.common.config.CameraConfig;

import org.junit.Assert;
import org.junit.Test;

public class MediaMtxConfigRendererTest {

    @Test
    public void renderYaml_includes_pr0_and_pr1_paths() {
        String yaml = MediaMtxConfigRenderer.renderYaml();
        Assert.assertTrue(yaml.contains("camera/pr0"));
        Assert.assertTrue(yaml.contains("camera/pr1"));
        Assert.assertTrue(yaml.contains("sourceOnDemand: no"));
        Assert.assertTrue(yaml.contains("writeQueueSize: 32"));
        Assert.assertTrue(yaml.contains("rtspTransport: udp"));
        Assert.assertTrue(yaml.contains(MediaMtxConfigRenderer.currentUpstreamPr0RtspUrl()));
        Assert.assertTrue(yaml.contains(MediaMtxConfigRenderer.currentUpstreamPr1RtspUrl()));
    }

    @Test
    public void lanRelay_pr0_and_pr1() {
        Assert.assertEquals("rtsp://192.168.0.237:8554/camera/pr0",
                MediaMtxRelayUrls.lanPr0("192.168.0.237"));
        Assert.assertEquals("rtsp://192.168.0.237:8554/camera/pr1",
                MediaMtxRelayUrls.lanPr1("192.168.0.237"));
    }

    @Test
    public void localRelay_pr1() {
        Assert.assertEquals("rtsp://127.0.0.1:8554/camera/pr1", MediaMtxRelayUrls.localPr1());
    }

    @Test
    public void resolvePr0Ingest_peer_when_local_relay_down() {
        Assert.assertEquals("rtsp://192.168.0.237:8554/camera/pr0",
                MediaMtxRelayUrls.resolvePr0Ingest(false, "192.168.0.237"));
    }

    @Test
    public void resolvePr0Ingest_local_when_relay_up() {
        Assert.assertEquals("rtsp://127.0.0.1:8554/camera/pr0",
                MediaMtxRelayUrls.resolvePr0Ingest(true, "192.168.0.237"));
    }
}
