package com.lasercyber.lws.ui.common.version;

import androidx.annotation.Nullable;

/**
 * Settings UI uses {@link #DISPLAY_PLACEHOLDER} when a library version is unknown; that value must not
 * be treated as an installed semver or persisted as the real version.
 */
public final class LibraryVersionHelper {

    /** Shown in device info when {@link #isUnset(String)}. */
    public static final String DISPLAY_PLACEHOLDER = "--";

    private static final String LEGACY_DISPLAY_PLACEHOLDER = "-";

    private LibraryVersionHelper() {
    }

    /** True when there is no meaningful installed library version (null, blank, or UI placeholder). */
    public static boolean isUnset(@Nullable String version) {
        if (version == null) {
            return true;
        }
        String trimmed = version.trim();
        if (trimmed.isEmpty()) {
            return true;
        }
        return DISPLAY_PLACEHOLDER.equals(trimmed) || LEGACY_DISPLAY_PLACEHOLDER.equals(trimmed);
    }

    /** Empty string for Room when unset; otherwise the trimmed version. */
    @Nullable
    public static String normalizeForStorage(@Nullable String version) {
        return isUnset(version) ? "" : version.trim();
    }

    /** Null for semver compare / bundled import when unset; otherwise trimmed version. */
    @Nullable
    public static String normalizeForCompare(@Nullable String version) {
        return isUnset(version) ? null : version.trim();
    }
}
