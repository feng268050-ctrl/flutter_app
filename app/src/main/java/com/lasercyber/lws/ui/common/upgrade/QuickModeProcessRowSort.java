package com.lasercyber.lws.ui.common.upgrade;

import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.common.constant.ModelConstant;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;

/**
 * Canonical sort for quick-mode process library rows: material → thickness/swing width → gear.
 */
public final class QuickModeProcessRowSort {

    private QuickModeProcessRowSort() {
    }

    public static List<ProcessParametersData> sortedCopy(List<ProcessParametersData> rows, int processType) {
        if (rows == null || rows.isEmpty()) {
            return rows == null ? List.of() : List.copyOf(rows);
        }
        List<ProcessParametersData> copy = new ArrayList<>(rows);
        sort(copy, processType);
        return copy;
    }

    public static void sort(List<ProcessParametersData> rows, int processType) {
        if (rows == null || rows.size() <= 1) {
            return;
        }
        rows.sort(comparator(processType));
    }

    /** Sort rows that may span multiple {@code processType} values (import path). */
    public static void sortForImport(List<ProcessParametersData> rows) {
        if (rows == null || rows.size() <= 1) {
            return;
        }
        rows.sort(importComparator());
    }

    static Comparator<ProcessParametersData> comparator(int processType) {
        return (left, right) -> compareRows(left, right, processType, false);
    }

    static Comparator<ProcessParametersData> importComparator() {
        return (left, right) -> compareRows(left, right, 0, true);
    }

    private static int compareRows(
            ProcessParametersData left,
            ProcessParametersData right,
            int fixedProcessType,
            boolean includeProcessType
    ) {
        int c;
        if (includeProcessType) {
            c = compareNullsLast(left.getProcessType(), right.getProcessType());
            if (c != 0) {
                return c;
            }
        }
        c = compareNullsLast(left.getMaterialType(), right.getMaterialType());
        if (c != 0) {
            return c;
        }
        int processType = includeProcessType
                ? Objects.requireNonNullElse(left.getProcessType(), 0)
                : fixedProcessType;
        c = Double.compare(dimensionKey(left, processType), dimensionKey(right, processType));
        if (c != 0) {
            return c;
        }
        return compareNullsLast(left.getGear(), right.getGear());
    }

    static boolean usesSwingWidth(int processType) {
        return processType == ModelConstant.WELD_CLEAN || processType == ModelConstant.WIDTH_CLEAN;
    }

    static double dimensionKey(ProcessParametersData row, int processType) {
        if (usesSwingWidth(processType)) {
            Double swingWidth = row.getSwingWidth();
            return swingWidth == null ? 0d : swingWidth;
        }
        Double thickness = row.getThickness();
        return thickness == null ? 0d : thickness;
    }

    static int compareNullsLast(Integer left, Integer right) {
        if (Objects.equals(left, right)) {
            return 0;
        }
        if (left == null) {
            return 1;
        }
        if (right == null) {
            return -1;
        }
        return Integer.compare(left, right);
    }
}
