package com.lasercyber.lws.ui.common.rx.modbus;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.common.config.ControlCardCommAlarmMode;

import org.junit.After;
import org.junit.Test;

public class ModbusStatusReadHealthTest {

    private static final ControlCardCommAlarmMode SLIDE_WINDOW = ControlCardCommAlarmMode.SLIDE_WINDOW;
    private static final ControlCardCommAlarmMode IMMEDIATE = ControlCardCommAlarmMode.IMMEDIATE;

    @After
    public void tearDown() {
        ModbusStatusReadHealth.getInstance().resetForTest();
    }

    @Test
    public void isFault_twoFailuresInFive_notFault() {
        ModbusStatusReadHealth health = ModbusStatusReadHealth.getInstance();
        health.recordOutcome(false);
        health.recordOutcome(true);
        health.recordOutcome(false);
        health.recordOutcome(true);
        health.recordOutcome(true);

        assertFalse(health.isFault(SLIDE_WINDOW));
    }

    @Test
    public void isFault_threeFailuresInFive_fault() {
        ModbusStatusReadHealth health = ModbusStatusReadHealth.getInstance();
        health.recordOutcome(false);
        health.recordOutcome(true);
        health.recordOutcome(false);
        health.recordOutcome(false);
        health.recordOutcome(true);

        assertTrue(health.isFault(SLIDE_WINDOW));
    }

    @Test
    public void isFault_threeConsecutiveFailuresBeforeWindowFull_fault() {
        ModbusStatusReadHealth health = ModbusStatusReadHealth.getInstance();
        health.recordOutcome(false);
        health.recordOutcome(false);
        health.recordOutcome(false);

        assertTrue(health.isFault(SLIDE_WINDOW));
    }

    @Test
    public void isFault_recoveredAfterFailures_clearsFault() {
        ModbusStatusReadHealth health = ModbusStatusReadHealth.getInstance();
        health.recordOutcome(false);
        health.recordOutcome(false);
        health.recordOutcome(false);
        assertTrue(health.isFault(SLIDE_WINDOW));

        health.recordOutcome(true);
        health.recordOutcome(true);
        health.recordOutcome(true);
        assertFalse(health.isFault(SLIDE_WINDOW));
    }

    @Test
    public void isFault_slidingWindowDropsOldestFailure() {
        ModbusStatusReadHealth health = ModbusStatusReadHealth.getInstance();
        for (int i = 0; i < 3; i++) {
            health.recordOutcome(false);
        }
        assertTrue(health.isFault(SLIDE_WINDOW));

        for (int i = 0; i < 3; i++) {
            health.recordOutcome(true);
        }
        assertFalse(health.isFault(SLIDE_WINDOW));
    }

    @Test
    public void isFault_immediate_singleFailure_fault() {
        ModbusStatusReadHealth health = ModbusStatusReadHealth.getInstance();
        health.recordOutcome(false);

        assertTrue(health.isFault(IMMEDIATE));
    }

    @Test
    public void isFault_immediate_successAfterFailure_clearsFault() {
        ModbusStatusReadHealth health = ModbusStatusReadHealth.getInstance();
        health.recordOutcome(false);
        assertTrue(health.isFault(IMMEDIATE));

        health.recordOutcome(true);
        assertFalse(health.isFault(IMMEDIATE));
    }
}
