package com.lasercyber.lws.ui.bean.http;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import org.junit.Assert;
import org.junit.Test;

public class ApiResultTest {
    private final Gson gson = new GsonBuilder().create();

    @Test
    public void successFalse_isFailure() {
        ApiResult r = gson.fromJson("{\"success\":false,\"code\":400,\"message\":\"bad\",\"data\":null}",
                ApiResult.class);
        Assert.assertFalse(r.isSuccess());
    }

    @Test
    public void codeAloneWithoutSuccessTrue_isNotSuccess() {
        ApiResult r = gson.fromJson("{\"code\":200}", ApiResult.class);
        Assert.assertFalse(r.isSuccess());
    }

    @Test
    public void bareObject_isNotSuccess() {
        ApiResult r = gson.fromJson("{}", ApiResult.class);
        Assert.assertFalse(r.isSuccess());
    }

    @Test
    public void successTrue_isSuccess() {
        ApiResult r = gson.fromJson("{\"success\":true,\"code\":200,\"data\":null,\"message\":null}",
                ApiResult.class);
        Assert.assertTrue(r.isSuccess());
    }
}
