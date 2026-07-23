package com.lasercyber.lws.ui.common.gpio;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;

public class LedIndicatorManagerTest {

    @Before
    @After
    public void resetState() {
        LedIndicatorManager.resetForTest();
    }

    @Test
    public void bootDefaultsGreenSteadyRedYellowOff() {
        assertEquals(IndicatorMode.STEADY_ON, LedIndicatorManager.getIndicatorMode(LedColor.GREEN));
        assertEquals(IndicatorMode.OFF, LedIndicatorManager.getIndicatorMode(LedColor.RED));
        assertEquals(IndicatorMode.OFF, LedIndicatorManager.getIndicatorMode(LedColor.YELLOW));
    }

    @Test
    public void setIndicatorIsIdempotentWhenHardwareUnavailable() {
        LedIndicatorManager.setIndicator(LedColor.RED, IndicatorMode.BLINK);
        assertEquals(IndicatorMode.OFF, LedIndicatorManager.getIndicatorMode(LedColor.RED));

        LedIndicatorManager.setIndicator(LedColor.RED, IndicatorMode.BLINK);
        assertEquals(IndicatorMode.OFF, LedIndicatorManager.getIndicatorMode(LedColor.RED));
    }

    @Test
    public void syncHardwareToCachedModesDoesNotCrashWhenUnavailable() {
        LedIndicatorManager.syncHardwareToCachedModes();
    }

    @Test
    public void flashTimingConstantsMatchSpec() {
        assertEquals(1000, LedIndicatorManager.FLASH_ON_MS);
        assertEquals(1000, LedIndicatorManager.FLASH_OFF_MS);
    }

    @Test
    public void experimentalPwmBaseFrequencyIs120Hertz() {
        assertEquals(120, LedIndicatorManager.EXPERIMENTAL_PWM_FREQUENCY_HZ);
        assertEquals(400, LedIndicatorManager.EXPERIMENTAL_PWM_MAX_FREQUENCY_HZ);
        assertEquals(120, LedIndicatorManager.getExperimentalPwmFrequencyHz());
        assertEquals(8333, LedIndicatorManager.EXPERIMENTAL_PWM_PERIOD_US);
    }

    @Test
    public void experimentalPwmDutyUsesGammaCorrection() {
        assertEquals(2.0f, LedIndicatorManager.EXPERIMENTAL_PWM_GAMMA, 0.001f);
        assertEquals(0.252f, LedIndicatorManager.experimentalPwmDutyFraction(128), 0.001f);
        assertEquals(2100, LedIndicatorManager.experimentalPwmOnUs(128));
        assertEquals(6233, LedIndicatorManager.experimentalPwmOffUs(128));
        assertEquals(1, LedIndicatorManager.experimentalPwmOnUs(1));
        assertEquals(5126, LedIndicatorManager.experimentalPwmOnUs(200));
        assertEquals(0, LedIndicatorManager.experimentalPwmOnUs(0));
        assertEquals(0, LedIndicatorManager.experimentalPwmOnUs(255));
    }

    @Test
    public void experimentalPwmRaisesFrequencyWhenDutyIsLow() {
        assertEquals(120, LedIndicatorManager.getExperimentalPwmFrequencyHz(200));
        assertEquals(8333, LedIndicatorManager.experimentalPwmPeriodUs(200));

        assertTrue(LedIndicatorManager.getExperimentalPwmFrequencyHz(32) > 120);
        assertEquals(382, LedIndicatorManager.getExperimentalPwmFrequencyHz(32));
        assertEquals(2617, LedIndicatorManager.experimentalPwmPeriodUs(32));
        assertEquals(41, LedIndicatorManager.experimentalPwmOnUs(32));
        assertEquals(2576, LedIndicatorManager.experimentalPwmOffUs(32));

        assertEquals(329, LedIndicatorManager.getExperimentalPwmFrequencyHz(64));
        assertEquals(191, LedIndicatorManager.experimentalPwmOnUs(64));
    }

    @Test
    public void experimentalPwmBrightnessNoOpWhenHardwareUnavailable() {
        LedIndicatorManager.setExperimentalPwmBrightness(LedColor.RED, 200);
        assertEquals(0, LedIndicatorManager.getExperimentalPwmBrightness(LedColor.RED));
    }

    @Test
    public void isHardwareAvailableFalseOnJvmTestHost() {
        assertFalse(LedIndicatorManager.isHardwareAvailable());
    }
}
