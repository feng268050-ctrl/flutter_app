package com.lasercyber.lws.ui.component.adapter;

import static org.junit.Assert.assertEquals;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.constant.ModelConstant;

import org.junit.Test;

public class ImageButtonStateAdapterTest {

    @Test
    public void resolveAvailableIdleIcon_usesColoredStopWithPlayByMode() {
        assertEquals(R.mipmap.camera_stop_orange_icon,
                ImageButtonStateAdapter.resolveAvailableIdleIcon(ModelConstant.CONTINUOUS_WELDING));
        assertEquals(R.mipmap.camera_stop_green_icon,
                ImageButtonStateAdapter.resolveAvailableIdleIcon(ModelConstant.WELD_CLEAN));
        assertEquals(R.mipmap.camera_stop_blue_icon,
                ImageButtonStateAdapter.resolveAvailableIdleIcon(ModelConstant.HAND_CUT));
    }

    @Test
    public void resolveRecordingIcon_usesPauseBarRunAssetByMode() {
        assertEquals(R.mipmap.camera_run_orange_icon,
                ImageButtonStateAdapter.resolveRecordingIcon(ModelConstant.CONTINUOUS_WELDING));
        assertEquals(R.mipmap.camera_run_green_icon,
                ImageButtonStateAdapter.resolveRecordingIcon(ModelConstant.WELD_CLEAN));
        assertEquals(R.mipmap.camera_run_blue_icon,
                ImageButtonStateAdapter.resolveRecordingIcon(ModelConstant.HAND_CUT));
    }
}
