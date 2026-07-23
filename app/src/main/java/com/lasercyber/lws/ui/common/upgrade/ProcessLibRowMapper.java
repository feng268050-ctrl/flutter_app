package com.lasercyber.lws.ui.common.upgrade;

import android.util.Log;

import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;

import java.util.Map;

/**
 * Maps one data row (column index → cell) to {@link ProcessParametersData} using a header-derived index map.
 * Unknown canonical columns are ignored at apply time (no binding in {@link ProcessLibColumn}).
 */
final class ProcessLibRowMapper {

    private static final String TAG = "ProcessLibRowMapper";

    private ProcessLibRowMapper() {
    }

    static ProcessParametersData mapDataRow(Map<?, ?> row, Map<String, Integer> headerToIndex) {
        ProcessParametersData p = new ProcessParametersData();
        for (ProcessLibColumn col : ProcessLibColumn.values()) {
            Integer idx = headerToIndex.get(col.canonicalHeader());
            if (idx == null) {
                continue;
            }
            Object cell = row.get(idx);
            col.apply(p, cell);
        }
        p.setOriginId(null);
        p.setId(null);
        return p;
    }

    static String nullIfEmptyString(Object cell) {
        if (cell == null) {
            return null;
        }
        String s = cell.toString().trim();
        return s.isEmpty() ? null : s;
    }

    static Integer nullIfEmptyInteger(Object cell) {
        if (cell == null) {
            return 0;
        }
        try {
            String value = cell.toString().trim();
            return value.isEmpty() ? 0 : Integer.parseInt(value);
        } catch (NumberFormatException e) {
            Log.e(TAG, "Integer parse failed: " + cell);
            return 0;
        }
    }

    static Double nullIfEmptyDouble(Object cell) {
        if (cell == null) {
            return null;
        }
        try {
            String value = cell.toString().trim();
            if (value.isEmpty()) {
                return null;
            }
            return Double.parseDouble(value);
        } catch (NumberFormatException e) {
            Log.e(TAG, "Double parse failed: " + cell);
            return null;
        }
    }
}
