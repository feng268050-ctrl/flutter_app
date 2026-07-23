package com.lasercyber.lws.ui.bean.http;

import com.google.gson.annotations.SerializedName;

import java.io.Serializable;

import lombok.Data;
import lombok.experimental.Accessors;

/** JSON body for {@code POST /v1/storage/r2/sts}. */
@Data
@Accessors(chain = true)
public class R2StsPostRequest implements Serializable {
    @SerializedName("sn")
    private String sn;
    @SerializedName("ttl_seconds")
    private int ttlSeconds;
}
