package com.lasercyber.lws.ui.common.upgrade;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Builds canonical header → column index from the first sheet row using trim and {@link ProcessLibImportProfile} aliases.
 */
final class ProcessLibHeaderResolver {

    private ProcessLibHeaderResolver() {
    }

    /**
     * @throws IllegalArgumentException on duplicate canonical headers (after alias resolution)
     */
    static Map<String, Integer> resolveHeaderRow(Map<?, ?> row, ProcessLibImportProfile profile) {
        Map<String, Integer> headerToIndex = new LinkedHashMap<>();
        for (Map.Entry<?, ?> entry : row.entrySet()) {
            int columnIndex = ((Number) entry.getKey()).intValue();
            Object rawCell = entry.getValue();
            String raw = rawCell == null ? "" : rawCell.toString().trim();
            if (raw.isEmpty()) {
                continue;
            }
            String canonical = profile.canonicalHeader(raw);
            if (headerToIndex.containsKey(canonical)) {
                throw new IllegalArgumentException(
                        "Duplicate header after normalization: \"" + canonical + "\" (column indices "
                                + headerToIndex.get(canonical) + " and " + columnIndex + ")");
            }
            headerToIndex.put(canonical, columnIndex);
        }
        return headerToIndex;
    }
}
