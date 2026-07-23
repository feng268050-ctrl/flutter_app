package com.lasercyber.lws.ui.network.http.remote;

import static org.junit.Assert.assertEquals;

import com.lasercyber.lws.ui.bean.http.CameraDeviceInfo;

import org.junit.Test;

public class CameraRemoteTest {

    @Test
    public void resolveAppVersionForDisplay_nullInfo_returnsDash() {
        assertEquals(CameraRemote.CAMERA_VERSION_UNAVAILABLE, CameraRemote.resolveAppVersionForDisplay(null));
    }

    @Test
    public void resolveAppVersionForDisplay_blankAppVersion_returnsDash() {
        CameraDeviceInfo info = new CameraDeviceInfo();
        info.setAppVersion("   ");
        assertEquals(CameraRemote.CAMERA_VERSION_UNAVAILABLE, CameraRemote.resolveAppVersionForDisplay(info));
    }

    @Test
    public void resolveAppVersionForDisplay_validAppVersion_returnsTrimmed() {
        CameraDeviceInfo info = new CameraDeviceInfo();
        info.setAppVersion("  2.1.0-beta  ");
        assertEquals("2.1.0-beta", CameraRemote.resolveAppVersionForDisplay(info));
    }

    @Test
    public void resolveAppVersionForDisplay_cameraFirmwareString_extractsCoreVersion() {
        CameraDeviceInfo info = new CameraDeviceInfo();
        info.setAppVersion("v1.0.5 build20251127");
        assertEquals("1.0.5", CameraRemote.resolveAppVersionForDisplay(info));
    }

    @Test
    public void parseCameraAppVersionDisplayValue_stripsVPrefixAndBuildSuffix() {
        assertEquals("1.0.5", CameraRemote.parseCameraAppVersionDisplayValue("v1.0.5 build20251127"));
        assertEquals("1.0.5", CameraRemote.parseCameraAppVersionDisplayValue("V1.0.5 BUILD20251127"));
    }
}
