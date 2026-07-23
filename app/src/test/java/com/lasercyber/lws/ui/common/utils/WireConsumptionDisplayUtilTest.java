package com.lasercyber.lws.ui.common.utils;

import com.lasercyber.lws.ui.common.enums.UnitSystem;

import org.junit.Assert;
import org.junit.Test;

public class WireConsumptionDisplayUtilTest {

    @Test
    public void format_metricUsesMeters() {
        WireConsumptionDisplayUtil.DisplayValue value =
                WireConsumptionDisplayUtil.format(5000L, UnitSystem.METRIC.getWireValue());
        Assert.assertEquals("5", value.getNumber());
        Assert.assertEquals(" m", value.getUnit());
    }

    @Test
    public void format_imperialUsesFeet() {
        WireConsumptionDisplayUtil.DisplayValue value =
                WireConsumptionDisplayUtil.format(600L, UnitSystem.IMPERIAL.getWireValue());
        Assert.assertEquals("2", value.getNumber());
        Assert.assertEquals(" ft", value.getUnit());
    }

    @Test
    public void format_nullLengthDefaultsToZero() {
        WireConsumptionDisplayUtil.DisplayValue value =
                WireConsumptionDisplayUtil.format((Long) null, UnitSystem.IMPERIAL.getWireValue());
        Assert.assertEquals("0", value.getNumber());
        Assert.assertEquals(" ft", value.getUnit());
    }
}
