package com.lasercyber.lws.ui.common.utils;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.common.constant.ModelConstant;

import org.junit.Test;

public class ProcessParameterDisplayRowsTest {

    @Test
    public void rowCountForProcessType_matchesEngineerModePanels() {
        assertEquals(17, ProcessParameterDisplayRows.rowCountForProcessType(
                ModelConstant.CONTINUOUS_WELDING, false));
        assertEquals(12, ProcessParameterDisplayRows.rowCountForProcessType(
                ModelConstant.POINT_WELDING, true));
        assertEquals(10, ProcessParameterDisplayRows.rowCountForProcessType(
                ModelConstant.WELD_CLEAN, false));
        assertEquals(10, ProcessParameterDisplayRows.rowCountForProcessType(
                ModelConstant.WIDTH_CLEAN, false));
        assertEquals(9, ProcessParameterDisplayRows.rowCountForProcessType(
                ModelConstant.HAND_CUT, false));
        assertEquals(9, ProcessParameterDisplayRows.rowCountForProcessType(
                ModelConstant.CNC_CUT, false));
    }

    @Test
    public void continuousWelding_hasMoreRowsThanPointWelding() {
        int continuous = ProcessParameterDisplayRows.rowCountForProcessType(
                ModelConstant.CONTINUOUS_WELDING, false);
        int point = ProcessParameterDisplayRows.rowCountForProcessType(
                ModelConstant.POINT_WELDING, true);
        assertTrue(continuous > point);
        assertEquals(continuous - point, 5);
    }

    @Test
    public void formatThickness_usesMetricDecimal() {
        assertEquals("2.5", ProcessParameterDisplayRows.formatThickness(2.5, true));
    }

    @Test
    public void formatThickness_usesImperialConversion() {
        String imperial = ProcessParameterDisplayRows.formatThickness(25.0, false);
        assertFalse(imperial.isEmpty());
        assertEquals("1", imperial);
    }

    @Test
    public void formatSwingWidth_usesMetricDecimal() {
        assertEquals("3.5", ProcessParameterDisplayRows.formatSwingWidth(3.5, true));
    }

    @Test
    public void formatSwingWidth_usesImperialConversion() {
        String imperial = ProcessParameterDisplayRows.formatSwingWidth(25.0, false);
        assertFalse(imperial.isEmpty());
        assertEquals("1", imperial);
    }
}
