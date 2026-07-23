package com.lasercyber.lws.ai.zeropoint;
import com.lasercyber.lws.ai.zeropoint.ZeroPointDetectTargetMode;

import static org.junit.Assert.assertEquals;

import com.lasercyber.lws.ui.common.constant.ModelConstant;

import org.junit.Test;

public class ZeroPointDetectTargetModeTest {

    @Test
    public void continuousWeldingMapsToLine() {
        assertEquals(ZeroPointDetectTargetMode.LINE,
                ZeroPointDetectTargetMode.resolve(ModelConstant.CONTINUOUS_WELDING));
        assertEquals("line", ZeroPointDetectTargetMode.logName(ZeroPointDetectTargetMode.LINE));
    }

    @Test
    public void pointWeldingMapsToPoint() {
        assertEquals(ZeroPointDetectTargetMode.POINT,
                ZeroPointDetectTargetMode.resolve(ModelConstant.POINT_WELDING));
        assertEquals("point", ZeroPointDetectTargetMode.logName(ZeroPointDetectTargetMode.POINT));
    }

    @Test
    public void otherProcessTypesDefaultToPoint() {
        assertEquals(ZeroPointDetectTargetMode.POINT,
                ZeroPointDetectTargetMode.resolve(ModelConstant.HAND_CUT));
    }
}
