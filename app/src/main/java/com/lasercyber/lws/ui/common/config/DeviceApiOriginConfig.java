package com.lasercyber.lws.ui.common.config;

import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ui.BuildConfig;

import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Objects;

import okhttp3.HttpUrl;

/**
 * LaserCyber Worker API bases (HTTP/HTTPS), pinned after network probe, and related WebSocket URLs.
 * <p>
 * Candidate bases are grouped into three environments: {@link #CANDIDATE_BASES_DEBUG} (debuggable APK),
 * {@link #CANDIDATE_BASES_TEST}, and {@link #CANDIDATE_BASES_PROD}; see {@link #orderedCandidateBases()}.
 */
public final class DeviceApiOriginConfig {
    private static final String PROD_HOST = "api-prod.lasercyber.workers.dev";
    private static final String TEST_HOST = "api-test.lasercyber.workers.dev";

    /**
     * Production API origin including {@code https://} (no trailing slash).
     */
    public static final String HTTPS_ORIGIN_PROD = "https://" + PROD_HOST;

    /**
     * Non-release / test API origin including {@code https://} (no trailing slash).
     */
    public static final String HTTPS_ORIGIN_TEST = "https://" + TEST_HOST;

    /** Debuggable builds ({@link BuildConfig#DEBUG}); add more entries here as needed for local dev. */
    private static final String[] CANDIDATE_BASES_DEBUG = new String[]{
            "http://10.0.2.2:8787",
            "http://10.0.1.110:8787",
    };

    /** Non-debug, non-production release channel ({@code !BuildConfig.RELEASE_CHANNEL}). */
    private static final String[] CANDIDATE_BASES_TEST = new String[]{
            "https://api-test.lasercyber.workers.dev",
            "https://lasercyber.hyurl.com/test",
    };

    /** Non-debug, production release channel ({@link BuildConfig#RELEASE_CHANNEL}). */
    private static final String[] CANDIDATE_BASES_PROD = new String[]{
            "https://api-prod.lasercyber.workers.dev",
            "https://lasercyber.hyurl.com/prod",
    };

    private static final Object PIN_LOCK = new Object();
    @Nullable
    private static volatile HttpUrl pinnedBase;

    @Nullable
    private static volatile List<HttpUrl> testCandidatesOverride;

    private DeviceApiOriginConfig() {
    }

    /**
     * Ordered candidate API bases for the current runtime tier (no trailing slash).
     * <p>
     * Uses {@link AppRuntimeEnvironment#getEffectiveTier()}: {@link #CANDIDATE_BASES_DEBUG} (Dev),
     * {@link #CANDIDATE_BASES_TEST} (Test), or {@link #CANDIDATE_BASES_PROD} (Prod). First successful HTTP probe wins.
     */
    public static List<HttpUrl> orderedCandidateBases() {
        List<HttpUrl> o = testCandidatesOverride;
        if (o != null) {
            return o;
        }
        String[] channel;
        switch (AppRuntimeEnvironment.getEffectiveTier()) {
            case DEV:
                channel = CANDIDATE_BASES_DEBUG;
                break;
            case PROD:
                channel = CANDIDATE_BASES_PROD;
                break;
            case TEST:
            default:
                channel = CANDIDATE_BASES_TEST;
                break;
        }
        List<HttpUrl> out = new ArrayList<>(channel.length);
        appendParsedBases(out, channel);
        return Collections.unmodifiableList(out);
    }

    private static void appendParsedBases(List<HttpUrl> out, String[] bases) {
        for (String s : bases) {
            try {
                out.add(stripTrailingSlashOnly(HttpUrl.get(s)));
            } catch (IllegalArgumentException ignored) {
                // skip malformed build-time constant
            }
        }
    }

    /**
     * Root URL used to probe reachability for a candidate ({@code base + "/"} semantics per spec).
     */
    public static HttpUrl rootProbeHttpUrl(HttpUrl base) {
        HttpUrl normalized = stripTrailingSlashOnly(base);
        String s = normalized.toString();
        if (s.endsWith("/")) {
            return Objects.requireNonNull(HttpUrl.parse(s));
        }
        return Objects.requireNonNull(HttpUrl.parse(s + "/"));
    }

    /**
     * Join a path that starts with {@code /} (Worker style) under the pinned base without stripping path prefix.
     */
    public static HttpUrl joinUnderBase(HttpUrl base, String pathStartingWithSlash) {
        if (pathStartingWithSlash == null || pathStartingWithSlash.isEmpty()) {
            throw new IllegalArgumentException("path required");
        }
        String p = pathStartingWithSlash.startsWith("/") ? pathStartingWithSlash.substring(1) : pathStartingWithSlash;
        HttpUrl.Builder b = stripTrailingSlashOnly(base).newBuilder();
        if (!p.isEmpty()) {
            String[] parts = p.split("/");
            for (String part : parts) {
                if (!part.isEmpty()) {
                    b.addPathSegment(part);
                }
            }
        }
        return b.build();
    }

    /**
     * Full URL for the App OTA manifest under {@code /view/lws-app/&lt;manifestJsonFile&gt;} on the pinned Worker API base.
     *
     * @return {@code null} when no successful probe has pinned a base yet
     */
    @Nullable
    public static HttpUrl lwsAppManifestHttpUrl(String manifestJsonFile) {
        if (manifestJsonFile == null || manifestJsonFile.isEmpty()) {
            throw new IllegalArgumentException("manifestJsonFile required");
        }
        HttpUrl pinned = getPinnedBase();
        if (pinned == null) {
            return null;
        }
        return joinUnderBase(pinned, "/view/lws-app/" + manifestJsonFile);
    }

    @Nullable
    public static HttpUrl getPinnedBase() {
        return pinnedBase;
    }

    /**
     * Clears the in-memory pinned Worker API base (e.g. after the default network is lost). Next successful probe
     * must re-pin before callers treat an origin as selected.
     */
    public static void clearPinnedBase() {
        synchronized (PIN_LOCK) {
            pinnedBase = null;
        }
    }

    public static void setPinnedBase(HttpUrl base) {
        synchronized (PIN_LOCK) {
            pinnedBase = stripTrailingSlashOnly(base);
        }
    }

    /**
     * Hostname (and port when non-default) from the pinned base for legacy diagnostics.
     *
     * @throws IllegalStateException when no pin exists yet
     */
    public static String resolveApiHost() {
        HttpUrl p = requirePinnedBase();
        String host = p.host();
        int port = p.port();
        boolean defPort = (p.scheme().equals("https") && port == 443) || (p.scheme().equals("http") && port == 80);
        if (!defPort) {
            return host + ":" + port;
        }
        return host;
    }

    /**
     * Full Worker API origin for the pinned base (e.g. {@code https://host} or {@code http://host:8080/prod}).
     *
     * @return {@code null} if no successful probe has pinned a base yet
     */
    @Nullable
    public static String resolveHttpsApiOrigin() {
        HttpUrl p = getPinnedBase();
        return p == null ? null : stripTrailingSlashOnly(p).toString();
    }

    /**
     * Base URL for Retrofit (must end with {@code /}). After a successful origin probe, matches the pinned Worker API
     * origin; before pin, the first entry in {@link #orderedCandidateBases()}.
     *
     * @throws IllegalStateException if there are no candidates (e.g. empty test override)
     */
    public static String getRetrofitBaseUrl() {
        HttpUrl base = getPinnedBase();
        if (base == null) {
            List<HttpUrl> candidates = orderedCandidateBases();
            if (candidates.isEmpty()) {
                throw new IllegalStateException("no API base candidates for Retrofit");
            }
            base = candidates.get(0);
        }
        return toRetrofitBaseUrlString(base);
    }

    static String toRetrofitBaseUrlString(HttpUrl base) {
        HttpUrl n = stripTrailingSlashOnly(base);
        String s = n.toString();
        return s.endsWith("/") ? s : s + "/";
    }

    /**
     * Device WebSocket URL using the pinned API base.
     *
     * @throws IllegalStateException if no pin exists yet
     */
    public static String buildDeviceWebSocketUrl(String deviceSn) {
        HttpUrl pinned = requirePinnedBase();
        String sn = deviceSn == null ? "" : deviceSn.trim();
        if (sn.isEmpty() || "unknown-sn".equals(sn)) {
            throw new IllegalArgumentException("invalid device sn");
        }
        return buildDeviceWebSocketUrlFromPinned(pinned, sn);
    }

    /**
     * Build WebSocket URL against an explicit base (hostname-only legacy form is not supported here; pass full {@link HttpUrl}).
     */
    public static String buildDeviceWebSocketUrl(String host, String deviceSn) {
        String sn = deviceSn == null ? "" : deviceSn.trim();
        if (sn.isEmpty() || "unknown-sn".equals(sn)) {
            throw new IllegalArgumentException("invalid device sn");
        }
        if (host == null || host.trim().isEmpty()) {
            throw new IllegalArgumentException("invalid host");
        }
        try {
            HttpUrl parsed = HttpUrl.get("https://" + host.trim());
            return buildDeviceWebSocketUrlFromPinned(parsed, sn);
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("invalid host", e);
        }
    }

    static String buildDeviceWebSocketUrlFromPinned(HttpUrl pinned, String snTrimmed) {
        HttpUrl normalized = stripTrailingSlashOnly(pinned);
        String prefix = normalized.toString();
        if (prefix.endsWith("/")) {
            prefix = prefix.substring(0, prefix.length() - 1);
        }
        String wsPrefix = prefix.replaceFirst("^https:", "wss:").replaceFirst("^http:", "ws:");
        return wsPrefix + "/ws/device?sn=" + urlEncode(snTrimmed);
    }

    /**
     * Strip a single trailing {@code /} when the URL has a path (including {@code https://host/}).
     */
    private static HttpUrl stripTrailingSlashOnly(HttpUrl u) {
        String s = u.toString();
        if (!s.endsWith("/")) {
            return u;
        }
        int idx = s.indexOf("://");
        if (idx < 0) {
            return u;
        }
        String afterScheme = s.substring(idx + 3);
        if (!afterScheme.contains("/")) {
            return u;
        }
        return Objects.requireNonNull(HttpUrl.parse(s.substring(0, s.length() - 1)));
    }

    private static HttpUrl requirePinnedBase() {
        HttpUrl p = getPinnedBase();
        if (p == null) {
            throw new IllegalStateException("api origin not selected yet");
        }
        return p;
    }

    private static String urlEncode(String value) {
        try {
            return URLEncoder.encode(value, "UTF-8");
        } catch (UnsupportedEncodingException e) {
            throw new IllegalStateException("utf-8 unsupported", e);
        }
    }

    @VisibleForTesting
    public static void resetOriginSelectionForTest() {
        synchronized (PIN_LOCK) {
            pinnedBase = null;
            testCandidatesOverride = null;
        }
    }

    @VisibleForTesting
    public static void setTestCandidateBases(@Nullable List<HttpUrl> candidates) {
        synchronized (PIN_LOCK) {
            if (candidates == null) {
                testCandidatesOverride = null;
            } else {
                testCandidatesOverride = Collections.unmodifiableList(new ArrayList<>(candidates));
            }
        }
    }

    @VisibleForTesting
    public static void setPinnedBaseForTest(@Nullable HttpUrl base) {
        synchronized (PIN_LOCK) {
            pinnedBase = base == null ? null : stripTrailingSlashOnly(base);
        }
    }
}
