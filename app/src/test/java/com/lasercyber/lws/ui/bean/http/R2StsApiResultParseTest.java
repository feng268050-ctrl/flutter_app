package com.lasercyber.lws.ui.bean.http;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import org.junit.Assert;
import org.junit.Test;

public class R2StsApiResultParseTest {
    private final Gson gson = new GsonBuilder().create();

    @Test
    public void successFalse_surfacesMessage() {
        String json = "{\"success\":false,\"code\":403,\"message\":\"forbidden\",\"data\":null}";
        R2StsApiResult r = gson.fromJson(json, R2StsApiResult.class);
        Assert.assertNotNull(r);
        Assert.assertFalse(r.isSuccess());
        Assert.assertEquals("forbidden", r.getMessage());
        Assert.assertNull(r.getData());
    }

    @Test
    public void successTrue_parsesCredentialData() {
        String json = "{"
                + "\"success\":true,"
                + "\"code\":200,"
                + "\"message\":null,"
                + "\"data\":{"
                + "\"access_key_id\":\"AKIA_TEST\","
                + "\"secret_access_key\":\"secret\","
                + "\"session_token\":\"token\","
                + "\"expires_at\":1710000000000,"
                + "\"endpoint_url\":\"https://acct.r2.cloudflarestorage.com\","
                + "\"bucket\":\"app\","
                + "\"region\":\"auto\""
                + "}"
                + "}";
        R2StsApiResult r = gson.fromJson(json, R2StsApiResult.class);
        Assert.assertNotNull(r);
        Assert.assertTrue(r.isSuccess());
        Assert.assertNotNull(r.getData());
        Assert.assertEquals("AKIA_TEST", r.getData().getAccessKeyId());
        Assert.assertEquals("secret", r.getData().getSecretAccessKey());
        Assert.assertEquals("token", r.getData().getSessionToken());
        Assert.assertEquals(Long.valueOf(1710000000000L), r.getData().getExpiresAt());
        Assert.assertEquals("https://acct.r2.cloudflarestorage.com", r.getData().getEndpointUrl());
        Assert.assertEquals("app", r.getData().getBucket());
        Assert.assertEquals("auto", r.getData().getRegion());
    }

    @Test
    public void successTrue_missingData_isNotSuccessPerCallerLogic() {
        String json = "{\"success\":true,\"code\":200,\"data\":null}";
        R2StsApiResult r = gson.fromJson(json, R2StsApiResult.class);
        Assert.assertTrue(r.isSuccess());
        Assert.assertNull(r.getData());
    }
}
