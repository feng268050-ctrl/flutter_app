package com.lasercyber.lws.ui.bean.http;

import com.google.gson.annotations.SerializedName;

import java.io.Serializable;

import lombok.Data;
import lombok.experimental.Accessors;

/** {@code data} object for successful R2 STS {@link R2StsApiResult}. */
@Data
@Accessors(chain = true)
public class R2StsCredentialsData implements Serializable {
    @SerializedName("access_key_id")
    private String accessKeyId;
    @SerializedName("secret_access_key")
    private String secretAccessKey;
    @SerializedName("session_token")
    private String sessionToken;
    /** Unix epoch milliseconds. */
    @SerializedName("expires_at")
    private Long expiresAt;
    @SerializedName("endpoint_url")
    private String endpointUrl;
    @SerializedName("bucket")
    private String bucket;
    /** R2 / product contract: fixed {@code auto} for S3 client region. */
    @SerializedName("region")
    private String region;
    /**
     * 对外读 URL 的 HTTPS 前缀（不含 object key）；与 object key 拼接封面/视频读地址。R2 STS 必填，缺失时客户端报错。
     */
    @SerializedName("public_base_url")
    private String publicBaseUrl;
}
