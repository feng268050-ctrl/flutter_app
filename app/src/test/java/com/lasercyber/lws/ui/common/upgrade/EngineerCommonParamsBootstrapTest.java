package com.lasercyber.lws.ui.common.upgrade;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;

import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.constant.ProcessDataType;
import com.lasercyber.lws.ui.common.enums.MaterialTypeEnum;

import org.junit.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.Set;

public class EngineerCommonParamsBootstrapTest {

    @Test
    public void pickMedianQuickModeRow_selectsMiddleGearAndThickness() {
        List<ProcessParametersData> rows = new ArrayList<>();
        rows.add(quickRow(ModelConstant.CONTINUOUS_WELDING, 1, 1.0, 10));
        rows.add(quickRow(ModelConstant.CONTINUOUS_WELDING, 2, 1.0, 20));
        rows.add(quickRow(ModelConstant.CONTINUOUS_WELDING, 2, 2.0, 30));
        rows.add(quickRow(ModelConstant.CONTINUOUS_WELDING, 2, 3.0, 40));
        rows.add(quickRow(ModelConstant.CONTINUOUS_WELDING, 3, 3.0, 50));

        ProcessParametersData picked = EngineerCommonParamsBootstrap.pickMedianQuickModeRow(
                rows, ModelConstant.CONTINUOUS_WELDING);

        assertNotNull(picked);
        assertEquals(Integer.valueOf(2), picked.getGear());
        assertEquals(Double.valueOf(2.0), picked.getThickness());
        assertEquals(Integer.valueOf(30), picked.getLaserPower());
    }

    @Test
    public void pickMedianQuickModeRow_usesSwingWidthForCleanModes() {
        List<ProcessParametersData> rows = new ArrayList<>();
        rows.add(quickRowWithSwing(ModelConstant.WELD_CLEAN, 1, 10.0, 100));
        rows.add(quickRowWithSwing(ModelConstant.WELD_CLEAN, 2, 20.0, 200));
        rows.add(quickRowWithSwing(ModelConstant.WELD_CLEAN, 2, 30.0, 300));
        rows.add(quickRowWithSwing(ModelConstant.WELD_CLEAN, 3, 30.0, 400));

        ProcessParametersData picked = EngineerCommonParamsBootstrap.pickMedianQuickModeRow(
                rows, ModelConstant.WELD_CLEAN);

        assertNotNull(picked);
        assertEquals(Integer.valueOf(2), picked.getGear());
        assertEquals(Double.valueOf(20.0), picked.getSwingWidth());
    }

    @Test
    public void cloneAsEngineerCommonPreset_usesEnglishMaterialName() {
        ProcessParametersData source = quickRow(ModelConstant.POINT_WELDING, 2, 2.0, 55);
        ProcessParametersData clone = EngineerCommonParamsBootstrap.cloneAsEngineerCommonPreset(
                source, ModelConstant.POINT_WELDING);

        assertNotNull(clone);
        assertEquals(Integer.valueOf(ProcessDataType.ENGINEER_MODE_DATA), clone.getDataType());
        assertEquals("Stainless Steel-2mm", clone.getName());
        assertNull(clone.getId());
    }

    @Test
    public void pickMedianQuickModeRow_filtersByMaterialType() {
        List<ProcessParametersData> rows = new ArrayList<>();
        rows.add(quickRow(ModelConstant.CONTINUOUS_WELDING, 1, 1.0, MaterialTypeEnum.STAINLESS_STEEL.getType(), 10));
        rows.add(quickRow(ModelConstant.CONTINUOUS_WELDING, 2, 2.0, MaterialTypeEnum.STAINLESS_STEEL.getType(), 20));
        rows.add(quickRow(ModelConstant.CONTINUOUS_WELDING, 1, 3.0, MaterialTypeEnum.CARBON_STEEL.getType(), 30));
        rows.add(quickRow(ModelConstant.CONTINUOUS_WELDING, 2, 4.0, MaterialTypeEnum.CARBON_STEEL.getType(), 40));

        ProcessParametersData picked = EngineerCommonParamsBootstrap.pickMedianQuickModeRow(
                rows,
                ModelConstant.CONTINUOUS_WELDING,
                MaterialTypeEnum.CARBON_STEEL.getType());

        assertNotNull(picked);
        assertEquals(Integer.valueOf(MaterialTypeEnum.CARBON_STEEL.getType()), picked.getMaterialType());
        assertEquals(Integer.valueOf(1), picked.getGear());
        assertEquals(Double.valueOf(3.0), picked.getThickness());
        assertEquals(Integer.valueOf(30), picked.getLaserPower());
    }

    @Test
    public void buildMedianEngineerPresetsForProcessType_addsOnePresetPerMaterial() {
        List<ProcessParametersData> rows = new ArrayList<>();
        rows.add(quickRow(ModelConstant.CONTINUOUS_WELDING, 1, 1.0, MaterialTypeEnum.STAINLESS_STEEL.getType(), 10));
        rows.add(quickRow(ModelConstant.CONTINUOUS_WELDING, 2, 2.0, MaterialTypeEnum.STAINLESS_STEEL.getType(), 20));
        rows.add(quickRow(ModelConstant.CONTINUOUS_WELDING, 1, 3.0, MaterialTypeEnum.CARBON_STEEL.getType(), 30));
        rows.add(quickRow(ModelConstant.CONTINUOUS_WELDING, 2, 4.0, MaterialTypeEnum.CARBON_STEEL.getType(), 40));
        rows.add(quickRow(ModelConstant.CONTINUOUS_WELDING, 2, 5.0, MaterialTypeEnum.CUSTOMIZE.getType(), 50));

        List<ProcessParametersData> presets = EngineerCommonParamsBootstrap.buildMedianEngineerPresetsForProcessType(
                rows,
                ModelConstant.CONTINUOUS_WELDING,
                Set.of());

        assertEquals(2, presets.size());
        assertEquals(1, presets.stream()
                .filter(row -> Objects.equals(row.getMaterialType(), MaterialTypeEnum.STAINLESS_STEEL.getType()))
                .count());
        assertEquals(1, presets.stream()
                .filter(row -> Objects.equals(row.getMaterialType(), MaterialTypeEnum.CARBON_STEEL.getType()))
                .count());
    }

    @Test
    public void synthesizeMissingEngineerRows_addsOneRowPerProcessTypeAndMaterial() {
        List<ProcessParametersData> source = new ArrayList<>();
        source.add(quickRow(ModelConstant.CONTINUOUS_WELDING, 1, 1.0, MaterialTypeEnum.STAINLESS_STEEL.getType(), 10));
        source.add(quickRow(ModelConstant.CONTINUOUS_WELDING, 2, 2.0, MaterialTypeEnum.STAINLESS_STEEL.getType(), 20));
        source.add(quickRow(ModelConstant.CONTINUOUS_WELDING, 1, 3.0, MaterialTypeEnum.CARBON_STEEL.getType(), 30));
        source.add(quickRow(ModelConstant.HAND_CUT, 1, 1.0, MaterialTypeEnum.STAINLESS_STEEL.getType(), 15));

        List<ProcessParametersData> merged = EngineerCommonParamsBootstrap.synthesizeMissingEngineerRows(source);

        assertEquals(7, merged.size());
        long engineerRows = merged.stream()
                .filter(row -> ProcessDataType.ENGINEER_MODE_DATA == row.getDataType())
                .count();
        assertEquals(3, engineerRows);
        assertEquals(
                "Stainless Steel-1mm",
                merged.stream()
                        .filter(row -> row.getProcessType() == ModelConstant.HAND_CUT
                                && row.getDataType() == ProcessDataType.ENGINEER_MODE_DATA)
                        .findFirst()
                        .orElseThrow()
                        .getName()
        );
    }

    private static ProcessParametersData quickRow(
            int processType,
            int gear,
            double thickness,
            int materialType,
            int laserPower
    ) {
        ProcessParametersData row = new ProcessParametersData();
        row.setProcessType(processType);
        row.setDataType(ProcessDataType.QUICK_MODE_DATA);
        row.setGear(gear);
        row.setThickness(thickness);
        row.setMaterialType(materialType);
        row.setLaserPower(laserPower);
        return row;
    }

    private static ProcessParametersData quickRow(int processType, int gear, double thickness, int laserPower) {
        return quickRow(processType, gear, thickness, MaterialTypeEnum.STAINLESS_STEEL.getType(), laserPower);
    }

    private static ProcessParametersData quickRowWithSwing(
            int processType,
            int gear,
            double swingWidth,
            int laserPower
    ) {
        ProcessParametersData row = quickRow(processType, gear, 0d, laserPower);
        row.setSwingWidth(swingWidth);
        return row;
    }
}
