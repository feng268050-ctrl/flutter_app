package com.lasercyber.lws.ui.common.version;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.github.zafarkhaja.semver.Version;

/**
 * Wraps java-semver for all version ordering. Do not implement bespoke version comparison elsewhere.
 */
public final class SemanticVersionHelper {

    private SemanticVersionHelper() {
    }

    @Nullable
    private static String normalize(@Nullable String raw) {
        if (raw == null) {
            return null;
        }
        String t = raw.trim();
        if (t.isEmpty()) {
            return null;
        }
        if (t.length() > 1 && (t.charAt(0) == 'v' || t.charAt(0) == 'V')) {
            return t.substring(1);
        }
        return t;
    }

    @Nullable
    public static Version parse(@Nullable String raw) {
        String n = normalize(raw);
        if (n == null) {
            return null;
        }
        try {
            return Version.valueOf(n);
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * @return negative if a &lt; b, zero if equal, positive if a &gt; b; 0 if either unparsable (caller should treat as no-op).
     */
    public static int compare(@Nullable String a, @Nullable String b) {
        Version va = parse(a);
        Version vb = parse(b);
        if (va == null || vb == null) {
            return 0;
        }
        return va.compareTo(vb);
    }

    /** True if {@code candidate} is strictly greater than {@code baseline} (e.g. bundled vs installed). */
    public static boolean isNewerThan(@Nullable String candidate, @Nullable String baseline) {
        if (candidate == null || candidate.trim().isEmpty()) {
            return false;
        }
        baseline = LibraryVersionHelper.normalizeForCompare(baseline);
        if (baseline == null || baseline.isEmpty()) {
            return true;
        }
        return compare(candidate, baseline) > 0;
    }

    /**
     * Returns normalized display/storage version without prerelease/build suffixes.
     * Strips a leading {@code v}/{@code V}, semver prerelease (e.g. {@code -beta}, {@code -alpha}, {@code -rc.1}),
     * and build metadata after {@code +}. Examples: {@code v1.0.0-beta+exp} -> {@code 1.0.0};
     * {@code v1.0.17-alpha} -> {@code 1.0.17}.
     */
    @Nullable
    public static String toCoreVersion(@Nullable String raw) {
        Version v = parse(raw);
        if (v != null) {
            return v.getMajorVersion() + "." + v.getMinorVersion() + "." + v.getPatchVersion();
        }
        String n = normalize(raw);
        if (n == null) {
            return null;
        }
        int dash = n.indexOf('-');
        int plus = n.indexOf('+');
        int cut = n.length();
        if (dash >= 0) {
            cut = Math.min(cut, dash);
        }
        if (plus >= 0) {
            cut = Math.min(cut, plus);
        }
        String core = n.substring(0, cut).trim();
        return core.isEmpty() ? null : core;
    }

    /**
     * OTA upgrade UI title: non-blank manifest {@code title} when present; otherwise
     * {@link #toCoreVersion(String)} of {@code manifestVersion} (drops {@code -alpha}, {@code -beta}, build metadata, etc.),
     * then trimmed raw {@code manifestVersion}, then {@code "Upgrade"}.
     */
    @NonNull
    public static String resolveOtaUpgradeTitle(@Nullable String manifestTitle, @Nullable String manifestVersion) {
        if (manifestTitle != null && !manifestTitle.trim().isEmpty()) {
            return manifestTitle.trim();
        }
        String core = toCoreVersion(manifestVersion);
        if (core != null && !core.isEmpty()) {
            return core;
        }
        if (manifestVersion != null) {
            String t = manifestVersion.trim();
            if (!t.isEmpty()) {
                return t;
            }
        }
        return "Upgrade";
    }
}
