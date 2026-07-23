package com.lasercyber.lws.ui.common.upgrade;

import static org.junit.Assert.assertEquals;

import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.constant.ProcessDataType;

import org.junit.Test;

import java.util.ArrayList;
import java.util.List;

public class QuickModeProcessRowSortTest {

    @Test
    public void sort_weldingRows_byMaterialThicknessGear() {
        List<ProcessParametersData> rows = new ArrayList<>();
        rows.add(weldRow(2, 3.0, 2, 30));
        rows.add(weldRow(1, 1.0, 1, 10));
        rows.add(weldRow(1, 2.0, 1, 20));
        rows.add(weldRow(1, 1.0, 2, 11));

        QuickModeProcessRowSort.sort(rows, ModelConstant.CONTINUOUS_WELDING);

        assertEquals(Integer.valueOf(1), rows.get(0).getMaterialType());
        assertEquals(Double.valueOf(1.0), rows.get(0).getThickness());
        assertEquals(Integer.valueOf(1), rows.get(0).getGear());

        assertEquals(Integer.valueOf(1), rows.get(1).getMaterialType());
        assertEquals(Double.valueOf(1.0), rows.get(1).getThickness());
        assertEquals(Integer.valueOf(2), rows.get(1).getGear());

        assertEquals(Double.valueOf(2.0), rows.get(2).getThickness());
        assertEquals(Integer.valueOf(2), rows.get(3).getMaterialType());
        assertEquals(Double.valueOf(3.0), rows.get(3).getThickness());
    }

    @Test
    public void sort_cleanRows_bySwingWidth() {
        List<ProcessParametersData> rows = new ArrayList<>();
        rows.add(cleanRow(1, 4.0, 2, 400));
        rows.add(cleanRow(1, 1.0, 1, 100));
        rows.add(cleanRow(1, 2.5, 1, 250));

        QuickModeProcessRowSort.sort(rows, ModelConstant.WELD_CLEAN);

        assertEquals(Double.valueOf(1.0), rows.get(0).getSwingWidth());
        assertEquals(Double.valueOf(2.5), rows.get(1).getSwingWidth());
        assertEquals(Double.valueOf(4.0), rows.get(2).getSwingWidth());
    }

    @Test
    public void sort_treatsNullThicknessAndGearAsLastWithinGroup() {
        List<ProcessParametersData> rows = new ArrayList<>();
        rows.add(weldRow(1, null, null, 1));
        rows.add(weldRow(1, 1.0, 1, 2));
        rows.add(weldRow(null, 1.0, 1, 3));

        QuickModeProcessRowSort.sort(rows, ModelConstant.CONTINUOUS_WELDING);

        assertEquals(Integer.valueOf(1), rows.get(0).getMaterialType());
        assertEquals(Integer.valueOf(1), rows.get(1).getMaterialType());
        assertNullMaterial(rows.get(2));
    }

    @Test
    public void sortForImport_groupsByProcessType() {
        List<ProcessParametersData> rows = new ArrayList<>();
        rows.add(cleanRow(1, 3.0, 1, 300));
        rows.add(weldRow(1, 2.0, 1, 200));
        rows.add(weldRow(1, 1.0, 1, 100));

        QuickModeProcessRowSort.sortForImport(rows);

        assertEquals(ModelConstant.CONTINUOUS_WELDING, (int) rows.get(0).getProcessType());
        assertEquals(Double.valueOf(1.0), rows.get(0).getThickness());
        assertEquals(ModelConstant.CONTINUOUS_WELDING, (int) rows.get(1).getProcessType());
        assertEquals(ModelConstant.WELD_CLEAN, (int) rows.get(2).getProcessType());
    }

    @Test
    public void orderQuickModeRowsForPersist_reordersBeforeInsert() {
        List<ProcessParametersData> rows = new ArrayList<>();
        rows.add(weldRow(1, 3.0, 1, 30));
        rows.add(weldRow(1, 1.0, 1, 10));

        List<ProcessParametersData> ordered = ProcessLibraryImporter.orderQuickModeRowsForPersist(rows);

        assertEquals(Double.valueOf(1.0), ordered.get(0).getThickness());
        assertEquals(Double.valueOf(3.0), ordered.get(1).getThickness());
    }

    private static void assertNullMaterial(ProcessParametersData row) {
        assertEquals(null, row.getMaterialType());
    }

    private static ProcessParametersData weldRow(Integer material, Double thickness, Integer gear, int laserPower) {
        ProcessParametersData row = baseRow(ModelConstant.CONTINUOUS_WELDING);
        row.setMaterialType(material);
        row.setThickness(thickness);
        row.setGear(gear);
        row.setLaserPower(laserPower);
        return row;
    }

    private static ProcessParametersData cleanRow(Integer material, Double swingWidth, Integer gear, int laserPower) {
        ProcessParametersData row = baseRow(ModelConstant.WELD_CLEAN);
        row.setMaterialType(material);
        row.setSwingWidth(swingWidth);
        row.setGear(gear);
        row.setLaserPower(laserPower);
        return row;
    }

    private static ProcessParametersData baseRow(int processType) {
        ProcessParametersData row = new ProcessParametersData();
        row.setProcessType(processType);
        row.setDataType(ProcessDataType.QUICK_MODE_DATA);
        return row;
    }
}
