package com.lasercyber.lws.ui.common.config;

import com.lasercyber.lws.ui.network.mediamtx.MediaMtxRelayUrls;

import org.junit.Assert;
import org.junit.Test;

import java.util.List;

public class CameraConfigPr0RecordingCandidatesTest {

    @Test
    public void emulator_usesPeerRelayOnlyWhenCameraIpConfigured() {
        List<String> urls = CameraConfig.buildPr0RecordingRtspCandidates(
                false, "192.168.0.119", true);
        Assert.assertEquals(1, urls.size());
        Assert.assertEquals("rtsp://192.168.0.119:8554/camera/pr0", urls.get(0));
        Assert.assertFalse(urls.stream().anyMatch(u -> u.contains("/PR1")));
    }

    @Test
    public void emulator_emptyWhenNoPeerRelayCameraIp() {
        List<String> urls = CameraConfig.buildPr0RecordingRtspCandidates(false, null, true);
        Assert.assertTrue(urls.isEmpty());
    }

    @Test
    public void device_prefersLocalRelayThenDirectIpc() {
        List<String> urls = CameraConfig.buildPr0RecordingRtspCandidates(true, null, false);
        Assert.assertEquals(MediaMtxRelayUrls.localPr0(), urls.get(0));
        Assert.assertTrue(urls.contains("rtsp://192.168.1.100/PR0"));
    }

    @Test
    public void device_fallsBackToPeerRelayWhenLocalRelayDown() {
        List<String> urls = CameraConfig.buildPr0RecordingRtspCandidates(
                false, "192.168.0.119", false);
        Assert.assertEquals("rtsp://192.168.0.119:8554/camera/pr0", urls.get(0));
        Assert.assertTrue(urls.contains("rtsp://192.168.1.100/PR0"));
    }
}
