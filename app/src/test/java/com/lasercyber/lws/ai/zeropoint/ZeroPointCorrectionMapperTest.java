package com.lasercyber.lws.ai.zeropoint;
import com.lasercyber.lws.ai.zeropoint.ZeroPointCorrectionMapper;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class ZeroPointCorrectionMapperTest {

    @Test
    public void uiDelta_invertsSignAndDividesByThree() {
        assertEquals(3, ZeroPointCorrectionMapper.uiDeltaFromOffsetPx(-9.0));
        assertEquals(-4, ZeroPointCorrectionMapper.uiDeltaFromOffsetPx(12.0));
    }

    /** Manual Auto method 2 (zero=0 pulse): absolute target equals uiDeltaFromOffsetPx, not current + uiDelta. */
    @Test
    public void absoluteZeroBaseline_targetFromOffsetAtZeroPulse() {
        int targetUi = ZeroPointCorrectionMapper.uiDeltaFromOffsetPx(-9.0);
        assertEquals(3, targetUi);
        assertEquals(3, ZeroPointCorrectionMapper.applyDelta(6, targetUi - 6));
    }

    @Test
    public void applyDelta_clampsAtPlus30() {
        assertEquals(30, ZeroPointCorrectionMapper.applyDelta(28, 5));
        assertEquals(30, ZeroPointCorrectionMapper.clamp(35));
    }

    @Test
    public void applyDelta_clampsAtMinus30() {
        assertEquals(-30, ZeroPointCorrectionMapper.applyDelta(-28, -5));
        assertEquals(-30, ZeroPointCorrectionMapper.clamp(-35));
    }

    @Test
    public void isWithinPositionTolerance_onlyOffsetX() {
        assertEquals(true, ZeroPointCorrectionMapper.isWithinPositionTolerance(0.0, 0.0));
        assertEquals(true, ZeroPointCorrectionMapper.isWithinPositionTolerance(16.0, -100.0));
        assertEquals(true, ZeroPointCorrectionMapper.isWithinPositionTolerance(-1.0, 999.0));
        assertEquals(false, ZeroPointCorrectionMapper.isWithinPositionTolerance(16.1, 0.0));
        assertEquals(true, ZeroPointCorrectionMapper.isWithinPositionTolerance(0.0, -17.0));
    }
}
