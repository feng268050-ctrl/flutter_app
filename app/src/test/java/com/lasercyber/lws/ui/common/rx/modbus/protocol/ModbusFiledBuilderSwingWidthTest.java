package com.lasercyber.lws.ui.common.rx.modbus.protocol;

import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.common.constant.ModelConstant;

import org.junit.Assert;
import org.junit.Test;

public class ModbusFiledBuilderSwingWidthTest {

    @Test
    public void encodeSwingWidthRegister_keepsDecimalScaleForNonWideClean() {
        ProcessParametersData row = new ProcessParametersData();
        row.setProcessType(ModelConstant.WELD_CLEAN);
        row.setSwingWidth(3.5d);

        Assert.assertEquals(35, ModbusFiledBuilder.encodeSwingWidthRegister(row));
    }

    @Test
    public void encodeSwingWidthRegister_dividesByFiveForWidthClean() {
        ProcessParametersData row = new ProcessParametersData();
        row.setProcessType(ModelConstant.WIDTH_CLEAN);
        row.setSwingWidth(30d);

        Assert.assertEquals(60, ModbusFiledBuilder.encodeSwingWidthRegister(row));
    }

    @Test
    public void encodeSwingWidthRegister_dividesByFiveBeforeDecimalScaleForWidthClean() {
        ProcessParametersData row = new ProcessParametersData();
        row.setProcessType(ModelConstant.WIDTH_CLEAN);
        row.setSwingWidth(7.5d);

        Assert.assertEquals(15, ModbusFiledBuilder.encodeSwingWidthRegister(row));
    }
}
