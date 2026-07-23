package com.lasercyber.lws.ui.bean.http;

import com.google.gson.annotations.SerializedName;

import java.io.Serializable;

import lombok.Data;
import lombok.experimental.Accessors;

/**
 * Worker {@code ApiResult} JSON for {@code POST /v1/devices/:sn/ai-report}.
 */
@Data
@Accessors(chain = true)
public class AiReportApiResult implements Serializable {
    @SerializedName("success")
    private boolean success;
    @SerializedName("code")
    private int code;
    @SerializedName("message")
    private String message;
    @SerializedName("data")
    private Object data;

    public boolean isSuccess() {
        return success || code == 0 || code == 200;
    }
}
