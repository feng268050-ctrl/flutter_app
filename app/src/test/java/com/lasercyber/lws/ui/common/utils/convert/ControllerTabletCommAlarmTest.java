package com.lasercyber.lws.ui.common.utils.convert;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.bean.entity.DeviceData;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.bean.entity.WarnTable;
import com.lasercyber.lws.ui.common.constant.AlarmCodeConstants;
import com.lasercyber.lws.ui.common.constant.WarnLevelConstant;

import org.junit.Test;

import java.util.List;

public class ControllerTabletCommAlarmTest {

    @Test
    public void convertToWarnTables_truncatedRead_addsC001() {
        DeviceStatus status = new DeviceStatus();
        status.setModbusStatusReadTruncated(true);

        List<WarnTable> tables = DeviceStatusConvert.convertToWarnTables(status);

        assertTrue(tables.stream().anyMatch(row ->
                AlarmCodeConstants.ALARM_C001.equals(row.getCode())
                        && row.getLevel() != null
                        && row.getLevel() == WarnLevelConstant.SERIOUS));
    }

    @Test
    public void convertToWarnTables_fullRead_omitsC001() {
        DeviceStatus status = new DeviceStatus();
        status.setModbusStatusReadTruncated(false);

        List<WarnTable> tables = DeviceStatusConvert.convertToWarnTables(status);

        assertEquals(0, tables.stream()
                .filter(row -> AlarmCodeConstants.ALARM_C001.equals(row.getCode()))
                .count());
    }

    @Test
    public void isControllerTabletCommTruncated_dataSegmentOnly() {
        DeviceData data = new DeviceData();
        data.setModbusDataReadTruncated(true);

        assertTrue(DeviceStatusConvert.isControllerTabletCommTruncated(new DeviceStatus(), data));
    }
}
