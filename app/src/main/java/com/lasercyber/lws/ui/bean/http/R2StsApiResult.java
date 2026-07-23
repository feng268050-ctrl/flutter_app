package com.lasercyber.lws.ui.bean.http;

import com.google.gson.annotations.SerializedName;

import java.io.Serializable;

import lombok.Data;
import lombok.experimental.Accessors;

/**
 * Worker {@code ApiResult} JSON for {@code POST /v1/storage/r2/sts}.
 * Success follows {@code success === true} only (same rule as {@link ApiResult}).
 */
@Data
@Accessors(chain = true)
public class R2StsApiResult implements Serializable {
    @SerializedName("code")
    private Integer code;
    @SerializedName("success")
    private Boolean success;
    @SerializedName("data")
    private R2StsCredentialsData data;
    @SerializedName("message")
    private String message;

    public boolean isSuccess() {
        return Boolean.TRUE.equals(success);
    }
}
