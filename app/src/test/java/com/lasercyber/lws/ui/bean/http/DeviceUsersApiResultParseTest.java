package com.lasercyber.lws.ui.bean.http;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import org.junit.Assert;
import org.junit.Test;

import java.util.List;

public class DeviceUsersApiResultParseTest {
    private final Gson gson = new GsonBuilder().create();

    @Test
    public void success_emptyArray_parses() {
        DeviceUsersApiResult r = gson.fromJson(
                "{\"success\":true,\"code\":200,\"data\":[],\"message\":null}",
                DeviceUsersApiResult.class);
        Assert.assertTrue(r.isSuccess());
        Assert.assertNotNull(r.getData());
        Assert.assertTrue(r.getData().isEmpty());
    }

    @Test
    public void success_populated_parsesSummaries() {
        DeviceUsersApiResult r = gson.fromJson(
                "{\"success\":true,\"data\":["
                        + "{\"id\":\"u1\",\"nickname\":\"n\",\"avatar\":\"http://a\",\"email\":\"a***@b.com\"}"
                        + "]}",
                DeviceUsersApiResult.class);
        Assert.assertTrue(r.isSuccess());
        List<DeviceBindingUserItem> list = r.getData();
        Assert.assertNotNull(list);
        Assert.assertEquals(1, list.size());
        Assert.assertEquals("u1", list.get(0).getId());
        Assert.assertEquals("n", list.get(0).getNickname());
        Assert.assertEquals("http://a", list.get(0).getAvatar());
        Assert.assertEquals("a***@b.com", list.get(0).getEmail());
    }

    @Test
    public void successFalse_isNotSuccess() {
        DeviceUsersApiResult r = gson.fromJson(
                "{\"success\":false,\"code\":403,\"message\":\"forbidden\",\"data\":null}",
                DeviceUsersApiResult.class);
        Assert.assertFalse(r.isSuccess());
    }
}
