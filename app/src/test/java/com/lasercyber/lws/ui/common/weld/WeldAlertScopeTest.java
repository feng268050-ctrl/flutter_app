package com.lasercyber.lws.ui.common.weld;

import androidx.annotation.NonNull;

import com.lasercyber.lws.ui.common.constant.ModelConstant;

import org.junit.Assert;
import org.junit.Test;

public class WeldAlertScopeTest {

    @Test
    public void isWeldModelType_acceptsContinuousAndPointWelding() {
        Assert.assertTrue(WeldAlertScope.isWeldModelType(ModelConstant.CONTINUOUS_WELDING));
        Assert.assertTrue(WeldAlertScope.isWeldModelType(ModelConstant.POINT_WELDING));
        Assert.assertFalse(WeldAlertScope.isWeldModelType(ModelConstant.CNC_CUT));
        Assert.assertFalse(WeldAlertScope.isWeldModelType(ModelConstant.HAND_CUT));
        Assert.assertFalse(WeldAlertScope.isWeldModelType(ModelConstant.WELD_CLEAN));
    }

    @Test
    public void isEligible_matchesWeldModelType() {
        Assert.assertTrue(WeldAlertScope.isEligible(host(ModelConstant.CONTINUOUS_WELDING)));
        Assert.assertTrue(WeldAlertScope.isEligible(host(ModelConstant.POINT_WELDING)));
        Assert.assertFalse(WeldAlertScope.isEligible(host(ModelConstant.CNC_CUT)));
        Assert.assertFalse(WeldAlertScope.isEligible(null));
    }

    private static WeldModeHost host(final int modelType) {
        return new WeldModeHost() {
            @Override
            public int getActiveWeldModelType() {
                return modelType;
            }

            @Override
            public void exitWeldWorkForZeroPointSettings(@NonNull Runnable onDone) {
                onDone.run();
            }
        };
    }
}
