package com.lasercyber.lws.ui.common.upgrade;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import com.lasercyber.lws.ui.BuildConfig;
import com.lasercyber.lws.ui.common.config.DeviceApiOriginConfig;
import com.lasercyber.lws.ui.common.network.proxy.ClientPurpose;
import com.lasercyber.lws.ui.common.network.proxy.NetworkHttpClientProvider;
import com.lasercyber.lws.ui.common.network.proxy.NetworkRoutePolicy;
import com.lasercyber.lws.ui.common.version.SemanticVersionHelper;

import java.io.IOException;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

import okhttp3.HttpUrl;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.ResponseBody;

/**
 * Fetches the pinned Worker {@code lws-app} manifest (check-update only).
 * Large ZIP downloads use {@link java.net.HttpURLConnection} separately in {@code UpgradeActivity}.
 */
public final class OtaUpdateManifestService {
    private OtaUpdateManifestService() {
    }

    public static final class ManifestData {
        public final String version;
        public final String url;
        public final String title;
        public final String content;
        public final String filename;
        public final String publishedAt;
        public final String sha512;

        private ManifestData(
                String version,
                String url,
                String title,
                String content,
                String filename,
                String publishedAt,
                String sha512
        ) {
            this.version = version;
            this.url = url;
            this.title = title;
            this.content = content;
            this.filename = filename;
            this.publishedAt = publishedAt;
            this.sha512 = sha512;
        }

        public Map<String, Object> toWsManifestPayload() {
            Map<String, Object> out = new LinkedHashMap<>();
            out.put("version", version);
            out.put("filename", filename);
            out.put("published_at", publishedAt);
            out.put("sha512", sha512);
            out.put("url", url);
            if (!title.isEmpty()) {
                out.put("title", title);
            }
            if (!content.isEmpty()) {
                out.put("content", content);
            }
            return out;
        }
    }

    public static final class CheckResult {
        public final boolean hasUpdate;
        @Nullable
        public final ManifestData manifest;

        private CheckResult(boolean hasUpdate, @Nullable ManifestData manifest) {
            this.hasUpdate = hasUpdate;
            this.manifest = manifest;
        }
    }

    @NonNull
    public static CheckResult checkAgainst(@NonNull String localVersionName) throws IOException {
        ManifestData manifest = fetchManifest();
        boolean hasUpdate = SemanticVersionHelper.compare(manifest.version, localVersionName) > 0;
        return new CheckResult(hasUpdate, hasUpdate ? manifest : null);
    }

    @NonNull
    public static ManifestData fetchManifest() throws IOException {
        HttpUrl manifestHttp = DeviceApiOriginConfig.lwsAppManifestHttpUrl(BuildConfig.LWS_MANIFEST_JSON_FILE);
        if (manifestHttp == null) {
            throw new IOException("no pinned API base yet");
        }
        Request request = new Request.Builder()
                .url(manifestHttp)
                .get()
                .build();
        try (Response response = manifestClient().newCall(request).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("HTTP " + response.code());
            }
            ResponseBody body = response.body();
            String raw = body != null ? body.string() : "";
            if (raw.isEmpty()) {
                throw new IOException("empty manifest");
            }
            Map<String, String> jsonMap = new Gson().fromJson(raw, new TypeToken<Map<String, String>>() {
            }.getType());
            if (jsonMap == null) {
                throw new IOException("invalid manifest json");
            }
            String version = trimToEmpty(jsonMap.get("version"));
            String downloadUrl = trimToEmpty(jsonMap.get("url"));
            if (version.isEmpty() || downloadUrl.isEmpty()) {
                throw new IOException("manifest missing version/url");
            }
            String title = trimToEmpty(jsonMap.get("title"));
            String content = trimToEmpty(jsonMap.get("content"));
            String publishedAt = trimToEmpty(jsonMap.get("published_at"));
            if (publishedAt.isEmpty()) {
                publishedAt = Instant.now().toString();
            }
            String sha512 = trimToEmpty(jsonMap.get("sha512"));
            String filename = trimToEmpty(jsonMap.get("filename"));
            if (filename.isEmpty()) {
                filename = deriveFilename(version, downloadUrl);
            }
            return new ManifestData(version, downloadUrl, title, content, filename, publishedAt, sha512);
        }
    }

    public static boolean isValidInboundSystemManifestPayload(@Nullable Map<String, String> manifest) {
        if (manifest == null) {
            return false;
        }
        return !trimToEmpty(manifest.get("version")).isEmpty()
                && !trimToEmpty(manifest.get("filename")).isEmpty()
                && !trimToEmpty(manifest.get("published_at")).isEmpty()
                && !trimToEmpty(manifest.get("sha512")).isEmpty()
                && !trimToEmpty(manifest.get("url")).isEmpty();
    }

    private static okhttp3.OkHttpClient manifestClient() {
        return NetworkHttpClientProvider.getInstance()
                .getClient(ClientPurpose.OTA_MANIFEST, NetworkRoutePolicy.INTERNET_PROXY_AWARE, null);
    }

    private static String deriveFilename(String version, String url) {
        int slashIdx = url.lastIndexOf('/');
        String last = slashIdx >= 0 && slashIdx + 1 < url.length() ? url.substring(slashIdx + 1) : "";
        if (!last.isEmpty()) {
            return last;
        }
        return version + ".zip";
    }

    private static String trimToEmpty(@Nullable String value) {
        return value == null ? "" : value.trim();
    }

    @VisibleForTesting
    @NonNull
    public static ManifestData manifestDataForTest(
            @NonNull String version,
            @NonNull String url,
            @NonNull String title,
            @NonNull String content,
            @Nullable String sha512
    ) {
        return new ManifestData(
                version,
                url,
                title,
                content,
                deriveFilename(version, url),
                Instant.now().toString(),
                sha512 == null ? "" : sha512);
    }
}
