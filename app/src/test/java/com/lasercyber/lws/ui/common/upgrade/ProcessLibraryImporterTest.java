package com.lasercyber.lws.ui.common.upgrade;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.constant.ProcessDataType;
import com.lasercyber.lws.ui.common.enums.MaterialTypeEnum;

import org.junit.Test;

import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

public class ProcessLibraryImporterTest {

    @Test
    public void filterQuickModeRows_keepsOnlyQuickMode() {
        ProcessParametersData quick = row(ProcessDataType.QUICK_MODE_DATA, "Q1");
        ProcessParametersData engineer = row(ProcessDataType.ENGINEER_MODE_DATA, "E1");
        ProcessParametersData legacyCustom = row(ProcessDataType.ENGINEER_MODE_CUSTOM_DATA, "C1");
        ProcessParametersData video = row(ProcessDataType.VIDEO_PROCESS_DATA, "V1");

        List<ProcessParametersData> filtered = ProcessLibraryImporter.filterQuickModeRows(
                Arrays.asList(quick, engineer, legacyCustom, video, null));

        assertEquals(1, filtered.size());
        assertEquals("Q1", filtered.get(0).getName());
    }

    @Test
    public void filterQuickModeRows_emptyWhenNoQuickMode() {
        ProcessParametersData engineer = row(ProcessDataType.ENGINEER_MODE_DATA, "E1");
        List<ProcessParametersData> filtered = ProcessLibraryImporter.filterQuickModeRows(List.of(engineer));
        assertTrue(filtered.isEmpty());
    }

    @Test
    public void buildMissingEngineerPresets_synthesizesMedianRowPerMaterial() {
        List<ProcessParametersData> quickRows = Arrays.asList(
                quickRow(ModelConstant.CONTINUOUS_WELDING, 1, 1.0, MaterialTypeEnum.STAINLESS_STEEL.getType(), 10),
                quickRow(ModelConstant.CONTINUOUS_WELDING, 2, 1.0, MaterialTypeEnum.STAINLESS_STEEL.getType(), 20),
                quickRow(ModelConstant.CONTINUOUS_WELDING, 2, 2.0, MaterialTypeEnum.STAINLESS_STEEL.getType(), 30),
                quickRow(ModelConstant.CONTINUOUS_WELDING, 2, 3.0, MaterialTypeEnum.STAINLESS_STEEL.getType(), 40),
                quickRow(ModelConstant.CONTINUOUS_WELDING, 3, 3.0, MaterialTypeEnum.STAINLESS_STEEL.getType(), 50),
                quickRow(ModelConstant.CONTINUOUS_WELDING, 1, 1.0, MaterialTypeEnum.CARBON_STEEL.getType(), 11),
                quickRow(ModelConstant.CONTINUOUS_WELDING, 2, 2.0, MaterialTypeEnum.CARBON_STEEL.getType(), 21),
                quickRow(ModelConstant.HAND_CUT, 1, 1.0, MaterialTypeEnum.STAINLESS_STEEL.getType(), 15)
        );

        List<ProcessParametersData> presets = ProcessLibraryImporter.buildMissingEngineerPresets(quickRows, Map.of());

        assertEquals(3, presets.size());
        ProcessParametersData weldingPreset = presets.stream()
                .filter(row -> row.getProcessType() == ModelConstant.CONTINUOUS_WELDING
                        && Objects.equals(row.getMaterialType(), MaterialTypeEnum.STAINLESS_STEEL.getType()))
                .findFirst()
                .orElseThrow();
        assertEquals(Integer.valueOf(ProcessDataType.ENGINEER_MODE_DATA), weldingPreset.getDataType());
        assertEquals(Integer.valueOf(2), weldingPreset.getGear());
        assertEquals(Double.valueOf(2.0), weldingPreset.getThickness());
        assertEquals(Integer.valueOf(30), weldingPreset.getLaserPower());
        assertEquals("Stainless Steel-2mm", weldingPreset.getName());
        assertEquals(1, presets.stream()
                .filter(row -> row.getProcessType() == ModelConstant.CONTINUOUS_WELDING
                        && Objects.equals(row.getMaterialType(), MaterialTypeEnum.CARBON_STEEL.getType()))
                .count());
    }

    @Test
    public void buildMissingEngineerPresets_skipsMaterialsWithExistingEngineerData() {
        List<ProcessParametersData> quickRows = List.of(
                quickRow(ModelConstant.CONTINUOUS_WELDING, 2, 2.0, MaterialTypeEnum.STAINLESS_STEEL.getType(), 20),
                quickRow(ModelConstant.CONTINUOUS_WELDING, 2, 2.0, MaterialTypeEnum.CARBON_STEEL.getType(), 21),
                quickRow(ModelConstant.HAND_CUT, 1, 1.0, MaterialTypeEnum.STAINLESS_STEEL.getType(), 15)
        );

        List<ProcessParametersData> presets = ProcessLibraryImporter.buildMissingEngineerPresets(
                quickRows,
                Map.of(
                        ModelConstant.CONTINUOUS_WELDING,
                        Set.of(MaterialTypeEnum.STAINLESS_STEEL.getType())
                )
        );

        assertEquals(2, presets.size());
        assertEquals(1, presets.stream()
                .filter(row -> row.getProcessType() == ModelConstant.CONTINUOUS_WELDING
                        && Objects.equals(row.getMaterialType(), MaterialTypeEnum.CARBON_STEEL.getType()))
                .count());
        assertEquals(1, presets.stream()
                .filter(row -> row.getProcessType() == ModelConstant.HAND_CUT)
                .count());
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

    private static ProcessParametersData row(int dataType, String name) {
        ProcessParametersData row = new ProcessParametersData();
        row.setDataType(dataType);
        row.setName(name);
        return row;
    }
}
