package com.lasercyber.lws.ui.bean.http;

import com.google.gson.annotations.SerializedName;

import java.io.Serializable;
import java.util.List;

import lombok.Data;
import lombok.experimental.Accessors;

/**
 * Worker {@code ApiResult} JSON for {@code GET /v1/devices/:sn/users}.
 */
@Data
@Accessors(chain = true)
public class DeviceUsersApiResult implements Serializable {
    @SerializedName("success")
    private Boolean success;
    @SerializedName("code")
    private Integer code;
    @SerializedName("message")
    private String message;
    @SerializedName("data")
    private List<DeviceBindingUserItem> data;

    public boolean isSuccess() {
        return Boolean.TRUE.equals(success);
    }
}
