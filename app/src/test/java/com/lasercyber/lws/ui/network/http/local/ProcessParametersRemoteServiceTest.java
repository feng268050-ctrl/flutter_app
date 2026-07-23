package com.lasercyber.lws.ui.network.http.local;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.common.constant.ProcessDataType;

import org.junit.Test;

public class ProcessParametersRemoteServiceTest {

    @Test
    public void mutationResult_fail_hasMessage() {
        ProcessParametersRemoteService.MutationResult r =
                ProcessParametersRemoteService.MutationResult.fail("cannot_delete_default");
        assertFalse(r.success);
        assertEquals("cannot_delete_default", r.message);
    }

    @Test
    public void engineerMode_constants() {
        ProcessParametersData row = new ProcessParametersData();
        row.setDataType(ProcessDataType.ENGINEER_MODE_DATA);
        assertTrue(com.lasercyber.lws.ui.network.ws.DeviceWsProcessParametersPayload
                .isEngineerMode(row.getDataType()));
        row.setDataType(ProcessDataType.QUICK_MODE_DATA);
        assertFalse(com.lasercyber.lws.ui.network.ws.DeviceWsProcessParametersPayload
                .isEngineerMode(row.getDataType()));
    }
}
