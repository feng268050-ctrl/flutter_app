package com.lasercyber.lws.ui.common.handler;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.net.URI;

/**
 * Derives HTTPS read URLs for process-video R2 objects when the Worker returns a full {@code coverUrl}
 * on the bucket public host; video uses the same host with {@code objectKey} as path.
 */
public final class ProcessVideoR2PublicUrls {
    private ProcessVideoR2PublicUrls() {
    }

    /**
     * Same scheme/host as {@code coverPublicUrlHttps}, path from {@code objectKey} (leading slash stripped).
     *
     * @return empty string if {@code coverPublicUrlHttps} is unusable
     */
    @NonNull
    public static String publicAssetUrlFromCoverPublicUrl(@Nullable String coverPublicUrlHttps,
            @NonNull String objectKey) {
        return publicAssetUrlFromPublicBaseUrl(coverPublicUrlHttps, objectKey);
    }

    @NonNull
    public static String publicAssetUrlFromPublicBaseUrl(@Nullable String publicBaseUrl,
            @NonNull String objectKey) {
        if (publicBaseUrl == null || publicBaseUrl.isEmpty()) {
            return "";
        }
        try {
            URI u = URI.create(publicBaseUrl.trim());
            String host = u.getHost();
            if (host == null || host.isEmpty()) {
                return "";
            }
            String scheme = u.getScheme() != null ? u.getScheme() : "https";
            String key = objectKey.startsWith("/") ? objectKey.substring(1) : objectKey;
            return scheme + "://" + host + "/" + key;
        } catch (IllegalArgumentException e) {
            return "";
        }
    }
}
