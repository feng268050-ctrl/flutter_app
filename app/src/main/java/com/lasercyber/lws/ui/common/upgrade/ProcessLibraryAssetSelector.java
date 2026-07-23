package com.lasercyber.lws.ui.common.upgrade;

import androidx.annotation.NonNull;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;

/**
 * Selects process-library xlsx source by device model.
 */
public final class ProcessLibraryAssetSelector {

    private ProcessLibraryAssetSelector() {
    }

    public static final class SelectionResult {
        public final String selectedFileName;
        public final String normalizedModel;
        public final boolean fallbackUsed;

        public SelectionResult(String selectedFileName, String normalizedModel, boolean fallbackUsed) {
            this.selectedFileName = selectedFileName;
            this.normalizedModel = normalizedModel;
            this.fallbackUsed = fallbackUsed;
        }
    }

    @NonNull
    public static String normalizeDeviceModel(String rawModel) {
        if (rawModel == null) {
            return "";
        }
        String trimmed = rawModel.trim();
        if (trimmed.toLowerCase(Locale.ROOT).startsWith("lasercyber")) {
            trimmed = trimmed.substring("lasercyber".length()).trim();
        }
        return collapseWhitespace(trimmed);
    }

    @NonNull
    public static SelectionResult select(List<String> xlsxFiles, String rawModel) {
        if (xlsxFiles == null || xlsxFiles.isEmpty()) {
            return new SelectionResult("", normalizeDeviceModel(rawModel), false);
        }
        if (xlsxFiles.size() == 1) {
            return new SelectionResult(xlsxFiles.get(0), normalizeDeviceModel(rawModel), false);
        }
        String normalizedModel = normalizeDeviceModel(rawModel);
        String normalizedModelForCompare = normalizeForCompare(normalizedModel);
        for (String fileName : xlsxFiles) {
            if (normalizeForCompare(stem(fileName)).equals(normalizedModelForCompare)) {
                return new SelectionResult(fileName, normalizedModel, false);
            }
        }
        ArrayList<String> sorted = new ArrayList<>(xlsxFiles);
        sorted.sort(Comparator.comparing((String v) -> v.toLowerCase(Locale.ROOT)).thenComparing(v -> v));
        return new SelectionResult(sorted.get(0), normalizedModel, true);
    }

    private static String stem(String fileName) {
        int dot = fileName == null ? -1 : fileName.lastIndexOf('.');
        return dot > 0 ? fileName.substring(0, dot) : (fileName == null ? "" : fileName);
    }

    private static String normalizeForCompare(String raw) {
        return collapseWhitespace(raw).toLowerCase(Locale.ROOT);
    }

    private static String collapseWhitespace(String raw) {
        return raw == null ? "" : raw.trim().replaceAll("\\s+", " ");
    }
}
