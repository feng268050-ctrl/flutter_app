package com.lasercyber.lws.ui.activitys.quick.mode;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.ui.DoubleWheelViewItem;

import java.util.List;
import java.util.Objects;

/**
 * Resolves Quick Mode gear / thickness (or swing width) after a mode or material switch.
 *
 * <p>Rules:
 * <ul>
 *   <li>Prefer session-carried gear and thickness (or swing) from the previous mode.</li>
 *   <li>If the carried gear is missing in the new library, fall back to the first gear.</li>
 *   <li>If the carried thickness/swing is missing, or has no process row for the resolved gear,
 *       fall back to the first thickness/swing that pairs with that gear (reset this mode's
 *       right-dimension parameter while still inheriting gear).</li>
 * </ul>
 */
public final class QuickModeSelectionResolver {

    private QuickModeSelectionResolver() {
    }

    @Nullable
    public static Integer preferCarryThenLocal(
            @Nullable Integer carry, @Nullable Integer local) {
        return carry != null ? carry : local;
    }

    @Nullable
    public static Double preferCarryThenLocal(
            @Nullable Double carry, @Nullable Double local) {
        return carry != null ? carry : local;
    }

    public static int indexOfGear(
            @Nullable List<DoubleWheelViewItem> list, @Nullable Integer preferredGear) {
        if (preferredGear == null || list == null) {
            return -1;
        }
        for (int i = 0; i < list.size(); i++) {
            if ((int) list.get(i).getValue() == preferredGear) {
                return i;
            }
        }
        return -1;
    }

    public static int indexOfDimension(
            @Nullable List<DoubleWheelViewItem> list,
            @Nullable Double preferred,
            boolean swingWidth) {
        if (preferred == null || list == null) {
            return -1;
        }
        Double preferredKey = swingWidth ? swingWidthKey(preferred) : thicknessKey(preferred);
        for (int i = 0; i < list.size(); i++) {
            Double itemKey = swingWidth
                    ? swingWidthKey(list.get(i).getValue())
                    : thicknessKey(list.get(i).getValue());
            if (Objects.equals(itemKey, preferredKey)) {
                return i;
            }
        }
        return -1;
    }

    /**
     * Picks a right-dimension index that inherits {@code preferred} when a matching process row
     * exists for {@code gear}; otherwise the first dimension that pairs with {@code gear}.
     */
    public static int resolveDimensionIndex(
            @NonNull List<DoubleWheelViewItem> dimensionList,
            @Nullable List<ProcessParametersData> dataList,
            @Nullable Integer materialType,
            @Nullable Integer gear,
            @Nullable Double preferred,
            boolean swingWidth) {
        if (dimensionList.isEmpty()) {
            return 0;
        }
        int preferredIndex = indexOfDimension(dimensionList, preferred, swingWidth);
        if (preferredIndex >= 0
                && hasProcessRow(
                dataList,
                materialType,
                gear,
                dimensionList.get(preferredIndex).getValue(),
                swingWidth)) {
            return preferredIndex;
        }
        for (int i = 0; i < dimensionList.size(); i++) {
            if (hasProcessRow(
                    dataList,
                    materialType,
                    gear,
                    dimensionList.get(i).getValue(),
                    swingWidth)) {
                return i;
            }
        }
        return 0;
    }

    public static boolean hasProcessRow(
            @Nullable List<ProcessParametersData> dataList,
            @Nullable Integer materialType,
            @Nullable Integer gear,
            @Nullable Double dimensionValue,
            boolean swingWidth) {
        if (dataList == null || gear == null) {
            return false;
        }
        for (ProcessParametersData row : dataList) {
            if (!Objects.equals(row.getMaterialType(), materialType)) {
                continue;
            }
            if (!Objects.equals(row.getGear(), gear)) {
                continue;
            }
            if (swingWidth) {
                if (Objects.equals(swingWidthKey(row.getSwingWidth()), swingWidthKey(dimensionValue))) {
                    return true;
                }
            } else if (Objects.equals(thicknessKey(row.getThickness()), thicknessKey(dimensionValue))) {
                return true;
            }
        }
        return false;
    }

    static double thicknessMmOrZero(@Nullable Double thickness) {
        return thickness == null ? 0d : thickness;
    }

    static Double thicknessKey(@Nullable Double thickness) {
        return thicknessMmOrZero(thickness);
    }

    static double swingWidthMmOrZero(@Nullable Double swingWidth) {
        return swingWidth == null ? 0d : swingWidth;
    }

    static Double swingWidthKey(@Nullable Double swingWidth) {
        return swingWidthMmOrZero(swingWidth);
    }
}
