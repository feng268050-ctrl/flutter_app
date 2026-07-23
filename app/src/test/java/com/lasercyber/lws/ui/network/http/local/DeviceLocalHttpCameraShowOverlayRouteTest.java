package com.lasercyber.lws.ui.network.http.local;

import org.junit.Assert;
import org.junit.Test;

import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.nio.charset.StandardCharsets;

/** Route-level probe for {@code POST /v1/camera/show-overlay}. */
public class DeviceLocalHttpCameraShowOverlayRouteTest {

    @Test
    public void cameraShowOverlay_withoutAppContext_returnsServerNotReady() throws Exception {
        DeviceLocalHttpServer server = new DeviceLocalHttpServer(0);
        server.start();
        try {
            int port = server.getListeningPort();
            HttpURLConnection conn = (HttpURLConnection)
                    new java.net.URL("http://127.0.0.1:" + port + "/v1/camera/show-overlay").openConnection();
            conn.setRequestMethod("POST");
            conn.setDoOutput(true);
            conn.setRequestProperty("Content-Type", "application/json; charset=utf-8");
            byte[] body = "{\"enable\":1}".getBytes(StandardCharsets.UTF_8);
            conn.setFixedLengthStreamingMode(body.length);
            try (OutputStream out = conn.getOutputStream()) {
                out.write(body);
            }
            Assert.assertEquals(500, conn.getResponseCode());
        } finally {
            server.stop();
        }
    }
}
