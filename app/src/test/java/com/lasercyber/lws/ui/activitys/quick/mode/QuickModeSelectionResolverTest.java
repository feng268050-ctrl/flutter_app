package com.lasercyber.lws.ui.activitys.quick.mode;

import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.ui.DoubleWheelViewItem;

import org.junit.After;
import org.junit.Assert;
import org.junit.Test;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class QuickModeSelectionResolverTest {

    @After
    public void tearDown() {
        QuickModeSelectionCarry.clear();
    }

    @Test
    public void preferCarryThenLocal_carryWins() {
        Assert.assertEquals(Integer.valueOf(3),
                QuickModeSelectionResolver.preferCarryThenLocal(3, 1));
        Assert.assertEquals(Double.valueOf(1.5),
                QuickModeSelectionResolver.preferCarryThenLocal(1.5, 0.5));
    }

    @Test
    public void preferCarryThenLocal_fallsBackToLocal() {
        Assert.assertEquals(Integer.valueOf(1),
                QuickModeSelectionResolver.preferCarryThenLocal(null, 1));
        Assert.assertEquals(Double.valueOf(0.5),
                QuickModeSelectionResolver.preferCarryThenLocal(null, 0.5));
    }

    @Test
    public void resolveDimension_inheritsMatchingThicknessForGear() {
        List<ProcessParametersData> rows = Arrays.asList(
                row(1, 1, 0.5),
                row(1, 1, 1.0),
                row(1, 3, 1.0),
                row(1, 3, 2.0));
        List<DoubleWheelViewItem> dimensions = dimensions(0.5, 1.0, 2.0);

        int index = QuickModeSelectionResolver.resolveDimensionIndex(
                dimensions, rows, 1, 3, 2.0, false);
        Assert.assertEquals(2, index);
    }

    @Test
    public void resolveDimension_missingThicknessFallsBackToFirstForGear() {
        // Carried 2.0 does not exist for gear 1; first pair for gear 1 is 0.5
        List<ProcessParametersData> rows = Arrays.asList(
                row(1, 1, 0.5),
                row(1, 1, 1.0),
                row(1, 3, 2.0));
        List<DoubleWheelViewItem> dimensions = dimensions(0.5, 1.0, 2.0);

        int index = QuickModeSelectionResolver.resolveDimensionIndex(
                dimensions, rows, 1, 1, 2.0, false);
        Assert.assertEquals(0, index);
    }

    @Test
    public void resolveDimension_thicknessPresentButNotForGear_fallsBack() {
        // 0.5 exists in the picker list but only under gear 1; gear 3 should use 1.0 first
        List<ProcessParametersData> rows = Arrays.asList(
                row(1, 1, 0.5),
                row(1, 3, 1.0),
                row(1, 3, 2.0));
        List<DoubleWheelViewItem> dimensions = dimensions(0.5, 1.0, 2.0);

        int index = QuickModeSelectionResolver.resolveDimensionIndex(
                dimensions, rows, 1, 3, 0.5, false);
        Assert.assertEquals(1, index);
    }

    @Test
    public void indexOfGear_findsOrMisses() {
        List<DoubleWheelViewItem> gears = new ArrayList<>();
        gears.add(gearItem(1));
        gears.add(gearItem(3));
        Assert.assertEquals(1, QuickModeSelectionResolver.indexOfGear(gears, 3));
        Assert.assertEquals(-1, QuickModeSelectionResolver.indexOfGear(gears, 5));
    }

    private static ProcessParametersData row(int material, int gear, double thickness) {
        ProcessParametersData data = new ProcessParametersData();
        data.setMaterialType(material);
        data.setGear(gear);
        data.setThickness(thickness);
        return data;
    }

    private static List<DoubleWheelViewItem> dimensions(double... values) {
        List<DoubleWheelViewItem> list = new ArrayList<>();
        for (double value : values) {
            DoubleWheelViewItem item = new DoubleWheelViewItem();
            item.setValue(value);
            item.setText(String.valueOf(value));
            list.add(item);
        }
        return list;
    }

    private static DoubleWheelViewItem gearItem(int gear) {
        DoubleWheelViewItem item = new DoubleWheelViewItem();
        item.setValue(gear);
        item.setText(String.valueOf(gear));
        return item;
    }
}
