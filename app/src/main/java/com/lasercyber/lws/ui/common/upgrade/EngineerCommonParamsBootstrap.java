package com.lasercyber.lws.ui.common.upgrade;

import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.bean.entity.CommonSettings;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.constant.ProcessDataType;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.enums.UnitSystem;
import com.lasercyber.lws.ui.common.enums.MaterialTypeEnum;
import com.lasercyber.lws.ui.common.utils.EngineerCommonlyUsedParameterNaming;

import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Builds engineer-mode common presets from quick-mode rows (median gear + median thickness/swing width).
 */
public final class EngineerCommonParamsBootstrap {

    private EngineerCommonParamsBootstrap() {
    }

    /**
     * Picks one quick-mode row per process type using median gear and median thickness or swing width.
     */
    public static ProcessParametersData pickMedianQuickModeRow(
            List<ProcessParametersData> quickRows,
            int processType
    ) {
        return pickMedianQuickModeRow(quickRows, processType, null);
    }

    /**
     * Picks one quick-mode row for a process type and optional material using median gear and dimension.
     */
    public static ProcessParametersData pickMedianQuickModeRow(
            List<ProcessParametersData> quickRows,
            int processType,
            Integer materialType
    ) {
        if (quickRows == null || quickRows.isEmpty()) {
            return null;
        }
        List<ProcessParametersData> typeRows = quickRows.stream()
                .filter(row -> row != null
                        && Objects.equals(row.getProcessType(), processType)
                        && Objects.equals(row.getDataType(), ProcessDataType.QUICK_MODE_DATA)
                        && (materialType == null || Objects.equals(row.getMaterialType(), materialType)))
                .collect(Collectors.toList());
        if (typeRows.isEmpty()) {
            return null;
        }
        List<Integer> gears = typeRows.stream()
                .map(ProcessParametersData::getGear)
                .filter(Objects::nonNull)
                .distinct()
                .sorted()
                .collect(Collectors.toList());
        if (gears.isEmpty()) {
            return typeRows.get(0);
        }
        Integer medianGear = gears.get(medianIndex(gears.size()));
        List<ProcessParametersData> gearRows = typeRows.stream()
                .filter(row -> Objects.equals(row.getGear(), medianGear))
                .collect(Collectors.toList());
        if (gearRows.isEmpty()) {
            return typeRows.get(0);
        }
        boolean usesSwingWidth = processType == ModelConstant.WELD_CLEAN
                || processType == ModelConstant.WIDTH_CLEAN;
        if (usesSwingWidth) {
            List<Double> swingWidths = gearRows.stream()
                    .map(ProcessParametersData::getSwingWidth)
                    .map(EngineerCommonParamsBootstrap::dimensionKey)
                    .distinct()
                    .sorted()
                    .collect(Collectors.toList());
            Double medianSwing = swingWidths.get(medianIndex(swingWidths.size()));
            for (ProcessParametersData row : gearRows) {
                if (Objects.equals(dimensionKey(row.getSwingWidth()), medianSwing)) {
                    return row;
                }
            }
        } else {
            List<Double> thicknesses = gearRows.stream()
                    .map(ProcessParametersData::getThickness)
                    .map(EngineerCommonParamsBootstrap::dimensionKey)
                    .distinct()
                    .sorted()
                    .collect(Collectors.toList());
            Double medianThickness = thicknesses.get(medianIndex(thicknesses.size()));
            for (ProcessParametersData row : gearRows) {
                if (Objects.equals(dimensionKey(row.getThickness()), medianThickness)) {
                    return row;
                }
            }
        }
        return gearRows.get(0);
    }

    public static ProcessParametersData cloneAsEngineerCommonPreset(ProcessParametersData source, int processType) {
        if (source == null) {
            return null;
        }
        ProcessParametersData clone = source.clone();
        clone.setId(null);
        clone.setOriginId(null);
        clone.setDataType(ProcessDataType.ENGINEER_MODE_DATA);
        clone.setProcessType(processType);
        clone.setName(EngineerCommonlyUsedParameterNaming.forBootstrapPreset(
                source,
                resolveUseMmUnit()
        ));
        return clone;
    }

    private static boolean resolveUseMmUnit() {
        try {
            CommonSettings settings = AppDatabase.getInstance(Utils.getApp()).commonSettingsDao().selectOne();
            if (settings == null || settings.getUnit() == null) {
                return true;
            }
            return UnitSystem.fromWireValue(settings.getUnit()) == UnitSystem.METRIC;
        } catch (Throwable ignored) {
            return true;
        }
    }

    static int medianIndex(int size) {
        if (size <= 0) {
            return 0;
        }
        return (size - 1) / 2;
    }

    private static double dimensionKey(Double value) {
        return value == null ? 0d : value;
    }

    public static List<ProcessParametersData> buildMedianEngineerPresetsForProcessType(
            List<ProcessParametersData> quickRows,
            int processType,
            Collection<Integer> existingMaterialTypes
    ) {
        Set<Integer> existing = existingMaterialTypes == null
                ? Set.of()
                : new HashSet<>(existingMaterialTypes);
        List<ProcessParametersData> presets = new ArrayList<>();
        for (Integer materialType : distinctNonCustomMaterialTypes(quickRows, processType)) {
            if (materialType == null || existing.contains(materialType)) {
                continue;
            }
            ProcessParametersData picked = pickMedianQuickModeRow(quickRows, processType, materialType);
            ProcessParametersData synthesized = cloneAsEngineerCommonPreset(picked, processType);
            if (synthesized != null) {
                presets.add(synthesized);
            }
        }
        return presets;
    }

    static List<Integer> distinctNonCustomMaterialTypes(
            List<ProcessParametersData> quickRows,
            int processType
    ) {
        if (quickRows == null || quickRows.isEmpty()) {
            return List.of();
        }
        return quickRows.stream()
                .filter(row -> row != null
                        && Objects.equals(row.getProcessType(), processType)
                        && Objects.equals(row.getDataType(), ProcessDataType.QUICK_MODE_DATA)
                        && isNonCustomMaterial(row.getMaterialType()))
                .map(ProcessParametersData::getMaterialType)
                .distinct()
                .sorted()
                .collect(Collectors.toList());
    }

    static boolean isNonCustomMaterial(Integer materialType) {
        return materialType != null
                && !Objects.equals(materialType, MaterialTypeEnum.CUSTOMIZE.getType());
    }

    private static boolean hasEngineerPresetForMaterial(
            List<ProcessParametersData> engineerRows,
            int processType,
            int materialType
    ) {
        if (engineerRows == null || engineerRows.isEmpty()) {
            return false;
        }
        for (ProcessParametersData row : engineerRows) {
            if (row != null
                    && Objects.equals(row.getProcessType(), processType)
                    && Objects.equals(row.getMaterialType(), materialType)
                    && ProcessDataType.isEngineerModeDataType(row.getDataType())) {
                return true;
            }
        }
        return false;
    }

    public static List<ProcessParametersData> synthesizeMissingEngineerRows(List<ProcessParametersData> source) {
        if (source == null || source.isEmpty()) {
            return source;
        }
        List<ProcessParametersData> validRows = new ArrayList<>();
        for (ProcessParametersData row : source) {
            if (row != null && row.getProcessType() != null && row.getDataType() != null) {
                validRows.add(row);
            }
        }
        if (validRows.isEmpty()) {
            return validRows;
        }
        List<Integer> quickProcessTypes = validRows.stream()
                .filter(row -> Objects.equals(row.getDataType(), ProcessDataType.QUICK_MODE_DATA))
                .map(ProcessParametersData::getProcessType)
                .distinct()
                .sorted()
                .collect(Collectors.toList());
        if (quickProcessTypes.isEmpty()) {
            return validRows;
        }
        List<ProcessParametersData> engineerRows = validRows.stream()
                .filter(row -> ProcessDataType.isEngineerModeDataType(row.getDataType()))
                .collect(Collectors.toList());
        List<ProcessParametersData> merged = new ArrayList<>(validRows);
        for (Integer processType : quickProcessTypes) {
            if (processType == null) {
                continue;
            }
            for (Integer materialType : distinctNonCustomMaterialTypes(validRows, processType)) {
                if (materialType == null
                        || hasEngineerPresetForMaterial(engineerRows, processType, materialType)) {
                    continue;
                }
                ProcessParametersData picked = pickMedianQuickModeRow(validRows, processType, materialType);
                ProcessParametersData synthesized = cloneAsEngineerCommonPreset(picked, processType);
                if (synthesized != null) {
                    merged.add(synthesized);
                }
            }
        }
        return merged;
    }
}
