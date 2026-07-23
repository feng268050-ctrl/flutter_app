package com.lasercyber.lws.ui.common.boot;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.bean.entity.DeviceData;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;

import org.junit.After;
import org.junit.Test;

public class BootSelfCheckEvaluatorTest {

    @After
    public void reset() {
        BootSelfCheckEvaluator.resetForTest();
    }

    @Test
    public void emulator_modbusItemsAreSkipped() {
        BootSelfCheckEvaluator.setEmulatorForTest(true);
        assertFalse(BootSelfCheckEvaluator.isModbusSelfCheckAvailable());

        BootSelfCheckEvaluator.ModbusSnapshot snapshot =
                new BootSelfCheckEvaluator.ModbusSnapshot(healthyStatus(), healthyData(), true);

        assertEquals(
                BootSelfCheckStatus.SKIPPED,
                BootSelfCheckEvaluator.evaluateItem(BootSelfCheckItem.CONTROLLER_COMM, snapshot, true));
        assertEquals(
                BootSelfCheckStatus.SKIPPED,
                BootSelfCheckEvaluator.evaluateItem(BootSelfCheckItem.PUMP_COMM, snapshot, true));
    }

    @Test
    public void emulator_cameraSkippedWithoutCameraIp() {
        BootSelfCheckEvaluator.setEmulatorForTest(true);
        BootSelfCheckEvaluator.setCameraHostConfiguredForTest(false);
        assertFalse(BootSelfCheckEvaluator.isCameraSelfCheckApplicable());

        assertEquals(
                BootSelfCheckStatus.SKIPPED,
                BootSelfCheckEvaluator.evaluateItem(
                        BootSelfCheckItem.CAMERA_COMM, null, false));
    }

    @Test
    public void emulator_cameraApplicableWhenCameraIpConfigured() {
        BootSelfCheckEvaluator.setEmulatorForTest(true);
        BootSelfCheckEvaluator.setCameraHostConfiguredForTest(true);
        assertTrue(BootSelfCheckEvaluator.isCameraSelfCheckApplicable());
    }

    @Test
    public void device_modbusAvailableWhenLinkReady() {
        BootSelfCheckEvaluator.setEmulatorForTest(false);
        BootSelfCheckEvaluator.setModbusAvailableForTest(true);
        assertTrue(BootSelfCheckEvaluator.isModbusSelfCheckAvailable());
    }

    @Test
    public void controllerReady_requiresPositiveDeviceType() {
        DeviceStatus status = new DeviceStatus();
        status.setDeviceType(1);
        assertTrue(BootSelfCheckEvaluator.evaluateControllerReady(status));

        status.setDeviceType(0);
        assertFalse(BootSelfCheckEvaluator.evaluateControllerReady(status));
    }

    private void enableDeviceModbusSelfCheck() {
        BootSelfCheckEvaluator.setEmulatorForTest(false);
        BootSelfCheckEvaluator.setModbusAvailableForTest(true);
    }

    @Test
    public void pumpComm_passWhenLaserCommAlarmClear() {
        enableDeviceModbusSelfCheck();
        DeviceStatus status = healthyStatus();
        BootSelfCheckEvaluator.ModbusSnapshot snapshot =
                new BootSelfCheckEvaluator.ModbusSnapshot(status, healthyData(), true);

        assertEquals(
                BootSelfCheckStatus.PASS,
                BootSelfCheckEvaluator.evaluateItem(BootSelfCheckItem.PUMP_COMM, snapshot, true));
    }

    @Test
    public void pumpComm_failWhenLaserCommAlarmActive() {
        enableDeviceModbusSelfCheck();
        DeviceStatus status = healthyStatus();
        status.setLaserAlarmSeg1(1);
        BootSelfCheckEvaluator.ModbusSnapshot snapshot =
                new BootSelfCheckEvaluator.ModbusSnapshot(status, healthyData(), true);

        assertEquals(
                BootSelfCheckStatus.FAIL,
                BootSelfCheckEvaluator.evaluateItem(BootSelfCheckItem.PUMP_COMM, snapshot, true));
    }

    @Test
    public void modbusItems_skippedWhenControllerNotReady() {
        enableDeviceModbusSelfCheck();
        assertEquals(
                BootSelfCheckStatus.SKIPPED,
                BootSelfCheckEvaluator.evaluateItem(BootSelfCheckItem.GUN_COMM, null, false));
    }

    @Test
    public void motorDriverTemp_failWhenAlarmBitSet() {
        enableDeviceModbusSelfCheck();
        DeviceStatus status = healthyStatus();
        status.setGunAlarmSeg2(1 << 1);
        DeviceData data = healthyData();
        BootSelfCheckEvaluator.ModbusSnapshot snapshot =
                new BootSelfCheckEvaluator.ModbusSnapshot(status, data, true);

        assertEquals(
                BootSelfCheckStatus.FAIL,
                BootSelfCheckEvaluator.evaluateItem(BootSelfCheckItem.MOTOR_DRIVER_TEMP, snapshot, true));
    }

    @Test
    public void motorDriverTemp_passWhenHealthy() {
        enableDeviceModbusSelfCheck();
        DeviceStatus status = healthyStatus();
        BootSelfCheckEvaluator.ModbusSnapshot snapshot =
                new BootSelfCheckEvaluator.ModbusSnapshot(status, healthyData(), true);

        assertEquals(
                BootSelfCheckStatus.PASS,
                BootSelfCheckEvaluator.evaluateItem(BootSelfCheckItem.MOTOR_DRIVER_TEMP, snapshot, true));
    }

    private static DeviceStatus healthyStatus() {
        DeviceStatus status = new DeviceStatus();
        status.setDeviceType(1);
        return status;
    }

    private static DeviceData healthyData() {
        DeviceData data = new DeviceData();
        data.setGunDriverBoardTempRaw(250);
        data.setGunMotorTempRaw(250);
        data.setProtectionBoardTempRaw(250);
        data.setCollimatorTempRaw(250);
        return data;
    }
}
