package com.lasercyber.lws.ui.common.utils;

import static org.junit.Assert.assertEquals;

import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.constant.ProcessDataType;

import org.junit.Test;

public class EngineerCommonlyUsedParameterNamingTest {

    @Test
    public void forBootstrapPreset_usesEnglishMaterialThicknessAndUnit() {
        ProcessParametersData row = quickRow(ModelConstant.CONTINUOUS_WELDING, 2.0, null);

        String name = EngineerCommonlyUsedParameterNaming.forBootstrapPreset(row, true);

        assertEquals("Stainless Steel-2mm", name);
    }

    @Test
    public void forBootstrapPreset_usesSwingWidthForCleanModes() {
        ProcessParametersData row = quickRow(ModelConstant.WELD_CLEAN, null, 20.0);

        String name = EngineerCommonlyUsedParameterNaming.forBootstrapPreset(row, true);

        assertEquals("Stainless Steel-20mm", name);
    }

    @Test
    public void forSaveAsCommon_omitsDimensionForCleanModes() {
        ProcessParametersData row = quickRow(ModelConstant.WELD_CLEAN, null, 20.0);

        String name = EngineerCommonlyUsedParameterNaming.forSaveAsCommon("不锈钢", row, true);

        assertEquals("不锈钢", name);
    }

    @Test
    public void forSaveAsCommon_usesLocalizedMaterialAndThickness() {
        ProcessParametersData row = quickRow(ModelConstant.HAND_CUT, 1.5, null);

        String name = EngineerCommonlyUsedParameterNaming.forSaveAsCommon("不锈钢", row, true);

        assertEquals("不锈钢-1.5mm", name);
    }

    private static ProcessParametersData quickRow(
            int processType,
            Double thickness,
            Double swingWidth
    ) {
        ProcessParametersData row = new ProcessParametersData();
        row.setProcessType(processType);
        row.setDataType(ProcessDataType.QUICK_MODE_DATA);
        row.setMaterialType(1);
        row.setThickness(thickness);
        row.setSwingWidth(swingWidth);
        return row;
    }
}
