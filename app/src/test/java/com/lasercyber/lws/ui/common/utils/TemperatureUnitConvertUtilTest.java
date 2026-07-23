package com.lasercyber.lws.ui.common.utils;

import com.lasercyber.lws.ui.common.enums.UnitSystem;

import org.junit.Assert;
import org.junit.Test;

public class TemperatureUnitConvertUtilTest {

    @Test
    public void formatSensorCelsius_metric() {
        Assert.assertEquals("25.0 ℃", TemperatureUnitConvertUtil.formatSensorCelsius(25.0, UnitSystem.METRIC.getWireValue()));
    }

    @Test
    public void formatSensorCelsius_imperial() {
        Assert.assertEquals("77.0 °F", TemperatureUnitConvertUtil.formatSensorCelsius(25.0, UnitSystem.IMPERIAL.getWireValue()));
    }

    @Test
    public void invalidPlaceholder_followsUnit() {
        Assert.assertEquals("- ℃", TemperatureUnitConvertUtil.invalidTemperaturePlaceholder(UnitSystem.METRIC.getWireValue()));
        Assert.assertEquals("- °F", TemperatureUnitConvertUtil.invalidTemperaturePlaceholder(UnitSystem.IMPERIAL.getWireValue()));
    }
}
