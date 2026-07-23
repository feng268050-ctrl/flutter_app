package com.lasercyber.lws.ui.common.config;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;

import org.junit.After;
import org.junit.Test;

import okhttp3.HttpUrl;

public class DeviceApiOriginConfigTest {

    @After
    public void tearDown() {
        DeviceApiOriginProber.resetForTest();
        DeviceApiOriginConfig.resetOriginSelectionForTest();
    }

    @Test
    public void root_probe_url_appends_slash_under_path_prefix() {
        HttpUrl base = HttpUrl.get("http://47.86.53.176:8080/test");
        assertEquals("http://47.86.53.176:8080/test/", DeviceApiOriginConfig.rootProbeHttpUrl(base).toString());
    }

    @Test
    public void root_probe_url_for_host_only_origin() {
        HttpUrl base = HttpUrl.get("https://api-test.lasercyber.workers.dev");
        assertEquals("https://api-test.lasercyber.workers.dev/", DeviceApiOriginConfig.rootProbeHttpUrl(base).toString());
    }

    @Test
    public void join_under_base_preserves_path_prefix() {
        HttpUrl base = HttpUrl.get("http://47.86.53.176:8080/test");
        HttpUrl joined = DeviceApiOriginConfig.joinUnderBase(base, "/v1/storage/r2/sts");
        assertEquals("http://47.86.53.176:8080/test/v1/storage/r2/sts", joined.toString());
    }

    @Test
    public void join_under_base_without_prefix() {
        HttpUrl base = HttpUrl.get("https://api-prod.lasercyber.workers.dev");
        HttpUrl joined = DeviceApiOriginConfig.joinUnderBase(base, "/v1/storage/r2/sts");
        assertEquals("https://api-prod.lasercyber.workers.dev/v1/storage/r2/sts", joined.toString());
    }

    @Test
    public void lws_app_manifest_url_null_without_pin() {
        assertNull(DeviceApiOriginConfig.lwsAppManifestHttpUrl("staging.json"));
    }

    @Test
    public void lws_app_manifest_url_https_host_without_prefix() {
        DeviceApiOriginConfig.setPinnedBase(HttpUrl.get("https://api-prod.lasercyber.workers.dev"));
        HttpUrl u = DeviceApiOriginConfig.lwsAppManifestHttpUrl("release.json");
        assertEquals("https://api-prod.lasercyber.workers.dev/view/lws-app/release.json", u.toString());
    }

    @Test
    public void lws_app_manifest_url_preserves_path_prefix() {
        DeviceApiOriginConfig.setPinnedBase(HttpUrl.get("http://47.86.53.176:8080/prod"));
        HttpUrl u = DeviceApiOriginConfig.lwsAppManifestHttpUrl("staging.json");
        assertEquals("http://47.86.53.176:8080/prod/view/lws-app/staging.json", u.toString());
    }

    @Test
    public void ws_url_from_https_pinned_base() {
        HttpUrl pinned = HttpUrl.get("https://api-test.lasercyber.workers.dev");
        String ws = DeviceApiOriginConfig.buildDeviceWebSocketUrlFromPinned(pinned, "SN 01");
        assertEquals("wss://api-test.lasercyber.workers.dev/ws/device?sn=SN+01", ws);
    }

    @Test
    public void ws_url_from_http_pinned_base_with_prefix() {
        HttpUrl pinned = HttpUrl.get("http://47.86.53.176:8080/prod");
        String ws = DeviceApiOriginConfig.buildDeviceWebSocketUrlFromPinned(pinned, "SN1");
        assertEquals("ws://47.86.53.176:8080/prod/ws/device?sn=SN1", ws);
    }
}
