package com.lasercyber.lws.ui.bean.http;

import com.google.gson.annotations.SerializedName;

import java.io.Serializable;

import lombok.Data;
import lombok.experimental.Accessors;

/**
 * Standard Worker JSON envelope (same shape as TS {@code ApiResult<T>}).
 * <p>
 * Success is determined only by {@code success === true}. Do not infer success from {@code code}.
 */
@Data
@Accessors(chain = true)
public class ApiResult implements Serializable {
    @SerializedName("success")
    private Boolean success;
    @SerializedName("code")
    private Integer code;
    @SerializedName("message")
    private String message;
    @SerializedName("data")
    private Object data;

    public boolean isSuccess() {
        return Boolean.TRUE.equals(success);
    }
}
