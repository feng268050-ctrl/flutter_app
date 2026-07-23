package com.lasercyber.lws.ui.network.http.local;

import org.junit.Assert;
import org.junit.Test;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
/**
 * Hits a live {@link DeviceLocalHttpServer} instance (no Android context required for {@code /lasercyber}).
 */
public class DeviceLocalHttpProbeTest {

    @Test
    public void lasercyber_returnsHello() throws Exception {
        DeviceLocalHttpServer server = new DeviceLocalHttpServer(0);
        server.start();
        try {
            int port = server.getListeningPort();
            HttpURLConnection conn = (HttpURLConnection) new URL("http://127.0.0.1:" + port + "/lasercyber")
                    .openConnection();
            conn.setRequestMethod("GET");
            conn.connect();
            Assert.assertEquals(200, conn.getResponseCode());
            StringBuilder body = new StringBuilder();
            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(conn.getInputStream(), StandardCharsets.UTF_8))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    body.append(line);
                }
            }
            Assert.assertEquals(DeviceLocalHttpServer.LASERCYBER_PROBE_BODY, body.toString());
        } finally {
            server.stop();
        }
    }
}
