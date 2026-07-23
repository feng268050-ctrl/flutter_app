package com.lasercyber.lws.ui.common.config;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import org.junit.After;
import org.junit.Test;

import java.util.Collections;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import okhttp3.HttpUrl;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.mockwebserver.MockResponse;
import okhttp3.mockwebserver.MockWebServer;

public class DeviceApiOriginProberTest {

    @After
    public void tearDown() throws Exception {
        DeviceApiOriginProber.resetForTest();
        DeviceApiOriginConfig.resetOriginSelectionForTest();
    }

    @Test
    public void probe_sets_pin_when_candidate_returns_http() throws Exception {
        DeviceApiOriginProber.resetForTest();
        DeviceApiOriginConfig.resetOriginSelectionForTest();
        MockWebServer server = new MockWebServer();
        server.enqueue(new MockResponse().setResponseCode(200));
        server.start();

        HttpUrl base = HttpUrl.get("http://127.0.0.1:" + server.getPort());
        DeviceApiOriginConfig.setTestCandidateBases(Collections.singletonList(base));

        CountDownLatch done = new CountDownLatch(1);
        DeviceApiOriginProber.probeSynchronouslyForTest(null, done::countDown);
        assertTrue(done.await(15, TimeUnit.SECONDS));
        assertNotNull(DeviceApiOriginConfig.getPinnedBase());
        assertEquals(base.toString(), DeviceApiOriginConfig.getPinnedBase().toString());

        server.shutdown();
    }

    @Test
    public void mock_web_server_okhttp_get_succeeds() throws Exception {
        MockWebServer server = new MockWebServer();
        server.enqueue(new MockResponse().setResponseCode(200));
        server.start();
        HttpUrl url = HttpUrl.get("http://127.0.0.1:" + server.getPort() + "/");
        OkHttpClient c = new OkHttpClient.Builder()
                .callTimeout(5, TimeUnit.SECONDS)
                .build();
        try (Response r = c.newCall(new Request.Builder().url(url).get().build()).execute()) {
            assertEquals(200, r.code());
        }
        server.shutdown();
    }
}
