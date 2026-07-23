package com.lasercyber.lws.ui.common.version;

import androidx.annotation.Nullable;

/**
 * Extracts the semver segment from bundled artifact filenames such as {@code 工艺库_v1.0.0-beta.xlsx}
 * or {@code libai_v1.0.0-beta.zip} (pattern {@code _v} + version + extension).
 */
public final class LibraryVersionFilename {

    private LibraryVersionFilename() {
    }

    /**
     * Finds the last {@code _v} / {@code _V} before the final extension and returns the version substring.
     */
    @Nullable
    public static String extractVersionSegment(String fileName) {
        if (fileName == null || fileName.isEmpty()) {
            return null;
        }
        int dot = fileName.lastIndexOf('.');
        String base = dot > 0 ? fileName.substring(0, dot) : fileName;
        int idx = base.toLowerCase().lastIndexOf("_v");
        if (idx < 0) {
            return null;
        }
        return base.substring(idx + 2);
    }
}
