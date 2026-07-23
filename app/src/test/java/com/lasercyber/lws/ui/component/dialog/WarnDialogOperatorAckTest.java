package com.lasercyber.lws.ui.component.dialog;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.bean.entity.vo.WarnDialogVo;
import com.lasercyber.lws.ui.common.enums.AlarmCodeEnums;
import com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodeController;

import org.junit.After;
import org.junit.Test;

public class WarnDialogOperatorAckTest {

    @After
    public void reset() {
        WarnEpisodeController.resetForTest();
    }

    @Test
    public void operatorAckClearsDemoEpisode() {
        WarnEpisodeController.armDemoEpisode(AlarmCodeEnums.E006.errorCode);
        WarnDialogVo vo = new WarnDialogVo();
        vo.setErrorCode(AlarmCodeEnums.E006.errorCode);

        WarnDialogUtil.acknowledgeOperatorDismiss(vo);

        assertFalse(WarnEpisodeController.isDemoFaultActive(AlarmCodeEnums.E006.errorCode));
        assertFalse(WarnEpisodeController.isFaultActive(AlarmCodeEnums.E006.errorCode));
        assertFalse(WarnEpisodeController.isBlockingLaser(AlarmCodeEnums.E006.errorCode));
    }

    @Test
    public void operatorAckIgnoresEmptyErrorCode() {
        WarnEpisodeController.armDemoEpisode(AlarmCodeEnums.L001.errorCode);
        WarnDialogVo vo = new WarnDialogVo();

        WarnDialogUtil.acknowledgeOperatorDismiss(vo);

        assertTrue(WarnEpisodeController.isDemoFaultActive(AlarmCodeEnums.L001.errorCode));
    }
}
