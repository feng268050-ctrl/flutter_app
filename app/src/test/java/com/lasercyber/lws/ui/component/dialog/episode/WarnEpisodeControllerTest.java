package com.lasercyber.lws.ui.component.dialog.episode;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.common.enums.AlarmCodeEnums;
import com.lasercyber.lws.ui.common.handler.LensHeavyContaminationWarnAlarm;

import org.junit.After;
import org.junit.Test;

public class WarnEpisodeControllerTest {

    @After
    public void reset() {
        WarnEpisodeController.resetForTest();
        LensHeavyContaminationWarnAlarm.INSTANCE.resetForStop();
    }

    @Test
    public void demoFaultActiveWhileEpisodeArmed() {
        assertFalse(WarnEpisodeController.isDemoFaultActive("C002"));
        WarnEpisodeController.armDemoEpisode("C002");
        assertTrue(WarnEpisodeController.isDemoFaultActive("C002"));
    }

    @Test
    public void operatorAckClearsDemoEpisode() {
        WarnEpisodeController.armDemoEpisode(AlarmCodeEnums.E006.errorCode);
        WarnEpisodeController.acknowledgeOperator(AlarmCodeEnums.E006.errorCode);
        assertFalse(WarnEpisodeController.isDemoFaultActive(AlarmCodeEnums.E006.errorCode));
        assertFalse(WarnEpisodeController.isFaultActive(AlarmCodeEnums.E006.errorCode));
        assertFalse(WarnEpisodeController.isBlockingLaser(AlarmCodeEnums.E006.errorCode));
    }

    @Test
    public void modbusPassiveDialogArmsOncePerCycle() {
        assertTrue(WarnEpisodeController.prepareModbusPassiveDialog(AlarmCodeEnums.E006.errorCode));
        assertTrue(WarnEpisodeController.prepareModbusPassiveDialog(AlarmCodeEnums.E006.errorCode));
        assertTrue(WarnEpisodeController.tryConsumeReminderForDialog(AlarmCodeEnums.E006.errorCode));
        assertFalse(WarnEpisodeController.prepareModbusPassiveDialog(AlarmCodeEnums.E006.errorCode));
    }

    @Test
    public void clearAllForDebugRemovesDemoAndProductionEpisodes() {
        WarnEpisodeController.armDemoEpisode(AlarmCodeEnums.C002.errorCode);
        WarnEpisodeController.armEpisode(
                AlarmCodeEnums.E006.errorCode,
                WarnEpisodePolicy.productionResist());
        assertTrue(WarnEpisodeController.isDemoFaultActive(AlarmCodeEnums.C002.errorCode));
        assertTrue(WarnEpisodeController.isFaultActive(AlarmCodeEnums.E006.errorCode));

        WarnEpisodeController.clearAllForDebug();

        assertFalse(WarnEpisodeController.isDemoFaultActive(AlarmCodeEnums.C002.errorCode));
        assertFalse(WarnEpisodeController.isFaultActive(AlarmCodeEnums.E006.errorCode));
        assertFalse(WarnEpisodeController.isBlockingLaser(AlarmCodeEnums.C002.errorCode));
        assertFalse(WarnEpisodeController.isBlockingLaser(AlarmCodeEnums.E006.errorCode));
    }

    @Test
    public void clearAllForDebugClearsProductionLensEpisode() {
        LensHeavyContaminationWarnAlarm.INSTANCE.armPendingForTest();
        LensHeavyContaminationWarnAlarm.INSTANCE.acknowledgeDialogForTest();
        WarnEpisodeController.notifyFaultActive(
                AlarmCodeEnums.L001.errorCode,
                WarnEpisodePolicy.productionResist());
        assertTrue(LensHeavyContaminationWarnAlarm.INSTANCE.isLaserEnableBlocked());
        assertTrue(WarnEpisodeController.isFaultActive(AlarmCodeEnums.L001.errorCode));

        WarnEpisodeController.clearAllForDebug();

        assertFalse(LensHeavyContaminationWarnAlarm.INSTANCE.isLaserEnableBlocked());
        assertFalse(WarnEpisodeController.isFaultActive(AlarmCodeEnums.L001.errorCode));
    }
}
