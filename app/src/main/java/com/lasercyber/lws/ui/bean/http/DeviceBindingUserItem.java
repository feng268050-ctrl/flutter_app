package com.lasercyber.lws.ui.bean.http;

import com.google.gson.annotations.SerializedName;

import java.io.Serializable;

import lombok.Data;
import lombok.experimental.Accessors;

/**
 * Simplified device-bound user row from {@code GET /v1/devices/:sn/users} {@code data} list.
 */
@Data
@Accessors(chain = true)
public class DeviceBindingUserItem implements Serializable {
    @SerializedName("id")
    private String id;
    @SerializedName("nickname")
    private String nickname;
    @SerializedName("avatar")
    private String avatar;
    /** Masked email as returned by the API. */
    @SerializedName("email")
    private String email;
}
