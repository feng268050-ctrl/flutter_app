package com.lasercyber.lws.ui.common.rx.modbus;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.common.config.ControlCardCommAlarmMode;

import org.junit.After;
import org.junit.Test;

public class ModbusDataReadHealthTest {

    private static final ControlCardCommAlarmMode SLIDE_WINDOW = ControlCardCommAlarmMode.SLIDE_WINDOW;

    @After
    public void tearDown() {
        ModbusDataReadHealth.getInstance().resetForTest();
    }

    @Test
    public void isFault_twoFailuresInFive_notFault() {
        ModbusDataReadHealth health = ModbusDataReadHealth.getInstance();
        health.recordOutcome(false);
        health.recordOutcome(true);
        health.recordOutcome(false);
        health.recordOutcome(true);
        health.recordOutcome(true);

        assertFalse(health.isFault(SLIDE_WINDOW));
    }

    @Test
    public void isFault_threeFailuresInFive_fault() {
        ModbusDataReadHealth health = ModbusDataReadHealth.getInstance();
        health.recordOutcome(false);
        health.recordOutcome(true);
        health.recordOutcome(false);
        health.recordOutcome(false);
        health.recordOutcome(true);

        assertTrue(health.isFault(SLIDE_WINDOW));
    }

    @Test
    public void isFault_recoveredAfterFailures_clearsFault() {
        ModbusDataReadHealth health = ModbusDataReadHealth.getInstance();
        health.recordOutcome(false);
        health.recordOutcome(false);
        health.recordOutcome(false);
        assertTrue(health.isFault(SLIDE_WINDOW));

        health.recordOutcome(true);
        health.recordOutcome(true);
        health.recordOutcome(true);
        assertFalse(health.isFault(SLIDE_WINDOW));
    }
}
