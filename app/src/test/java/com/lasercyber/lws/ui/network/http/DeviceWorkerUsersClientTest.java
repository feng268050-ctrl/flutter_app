package com.lasercyber.lws.ui.network.http;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.bean.http.DeviceBindingUserItem;
import com.lasercyber.lws.ui.common.config.DeviceApiOriginConfig;
import com.lasercyber.lws.ui.common.device.DeviceIdentity;

import org.junit.After;
import org.junit.Test;

import java.util.List;

import okhttp3.HttpUrl;
import okhttp3.mockwebserver.MockResponse;
import okhttp3.mockwebserver.MockWebServer;

public class DeviceWorkerUsersClientTest {

    @After
    public void tearDown() {
        DeviceApiOriginConfig.resetOriginSelectionForTest();
    }

    @Test
    public void fetch_success_emptyUsers() throws Exception {
        MockWebServer server = new MockWebServer();
        server.start();
        try {
            DeviceApiOriginConfig.setPinnedBaseForTest(HttpUrl.get(server.url("/").toString()));
            server.enqueue(new MockResponse().setBody(
                    "{\"success\":true,\"code\":200,\"data\":[],\"message\":null}"));
            DeviceWorkerUsersClient.Outcome o = DeviceWorkerUsersClient.fetchDeviceUsers("SN123");
            assertEquals("/v1/devices/SN123/users", server.takeRequest().getPath());
            assertTrue(o.isOk());
            assertNotNull(o.getUsers());
            assertTrue(o.getUsers().isEmpty());
        } finally {
            server.shutdown();
        }
    }

    @Test
    public void fetch_success_nonEmptyUsers() throws Exception {
        MockWebServer server = new MockWebServer();
        server.start();
        try {
            DeviceApiOriginConfig.setPinnedBaseForTest(HttpUrl.get(server.url("/").toString()));
            server.enqueue(new MockResponse().setBody(
                    "{\"success\":true,\"data\":[{\"id\":\"1\",\"nickname\":\"a\",\"avatar\":\"\",\"email\":\"x\"}]}"));
            DeviceWorkerUsersClient.Outcome o = DeviceWorkerUsersClient.fetchDeviceUsers("AB");
            assertTrue(o.isOk());
            List<DeviceBindingUserItem> users = o.getUsers();
            assertNotNull(users);
            assertEquals(1, users.size());
            assertEquals("1", users.get(0).getId());
        } finally {
            server.shutdown();
        }
    }

    @Test
    public void fetch_apiNotSuccess_isFailure() throws Exception {
        MockWebServer server = new MockWebServer();
        server.start();
        try {
            DeviceApiOriginConfig.setPinnedBaseForTest(HttpUrl.get(server.url("/").toString()));
            server.enqueue(new MockResponse().setBody(
                    "{\"success\":false,\"code\":400,\"message\":\"bad\",\"data\":null}"));
            DeviceWorkerUsersClient.Outcome o = DeviceWorkerUsersClient.fetchDeviceUsers("SN");
            assertFalse(o.isOk());
        } finally {
            server.shutdown();
        }
    }

    @Test
    public void fetch_unknownSn_skipsRequest() throws Exception {
        MockWebServer server = new MockWebServer();
        server.start();
        try {
            DeviceApiOriginConfig.setPinnedBaseForTest(HttpUrl.get(server.url("/").toString()));
            DeviceWorkerUsersClient.Outcome o = DeviceWorkerUsersClient.fetchDeviceUsers(DeviceIdentity.UNKNOWN_SN);
            assertFalse(o.isOk());
            assertEquals(0, server.getRequestCount());
        } finally {
            server.shutdown();
        }
    }

    @Test
    public void fetch_noPinnedBase_skipsRequest() {
        DeviceApiOriginConfig.setPinnedBaseForTest(null);
        DeviceWorkerUsersClient.Outcome o = DeviceWorkerUsersClient.fetchDeviceUsers("SN");
        assertFalse(o.isOk());
    }
}
