package com.lasercyber.lws.ui.network.http.local;

import com.lasercyber.lws.ui.common.ai.video.ProcessVideoAiSessionRegistry;

import org.junit.Assert;
import org.junit.Test;

/**
 * Route-level probe for {@code GET /v1/videos/:video_id/ai} (no Android {@link android.content.Context}).
 */
public class DeviceLocalHttpVideoAiRouteTest {

    @Test
    public void videoAi_withoutAppContext_returnsServerNotReady() throws Exception {
        ProcessVideoAiSessionRegistry.getInstance().resetForTest();
        CameraAiHttpPublisher.resetForTest();
        DeviceLocalHttpServer server = new DeviceLocalHttpServer(0);
        server.start();
        try {
            int port = server.getListeningPort();
            java.net.HttpURLConnection conn = (java.net.HttpURLConnection)
                    new java.net.URL("http://127.0.0.1:" + port + "/v1/videos/test-id/ai").openConnection();
            conn.setRequestMethod("GET");
            conn.connect();
            Assert.assertEquals(500, conn.getResponseCode());
        } finally {
            server.stop();
        }
    }
}
