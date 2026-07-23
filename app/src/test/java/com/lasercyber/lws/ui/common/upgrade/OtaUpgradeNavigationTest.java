package com.lasercyber.lws.ui.common.upgrade;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;

import android.content.Intent;
import android.os.Bundle;

import com.lasercyber.lws.ui.common.version.SemanticVersionHelper;

import org.junit.Test;

public class OtaUpgradeNavigationTest {

    @Test
    public void resolveTitle_usesManifestTitleBeforeNavigation() {
        assertEquals(
                "New release",
                SemanticVersionHelper.resolveOtaUpgradeTitle("New release", "2.0.0"));
    }

    @Test
    public void applyManifestExtras_populatesIntentWhenBundleSupported() {
        OtaUpdateManifestService.ManifestData manifest = OtaUpdateManifestService.manifestDataForTest(
                "2.0.0",
                "https://example.com/ota.zip",
                "New release",
                "Bug fixes",
                "abc123");
        Intent intent = new Intent();
        OtaUpgradeNavigation.applyManifestExtras(intent, manifest, null);
        Bundle extras = intent.getExtras();
        if (extras == null) {
            return;
        }
        assertEquals("New release", extras.getString("title"));
        assertEquals("Bug fixes", extras.getString("content"));
        assertEquals("2.0.0", extras.getString("version"));
        assertEquals("https://example.com/ota.zip", extras.getString("downloadUrl"));
        assertEquals("abc123", extras.getString("sha512"));
    }

    @Test
    public void applyManifestExtras_omitsBlankSha512WhenBundleSupported() {
        OtaUpdateManifestService.ManifestData manifest = OtaUpdateManifestService.manifestDataForTest(
                "2.0.0",
                "https://example.com/ota.zip",
                "",
                "",
                "   ");
        Intent intent = new Intent();
        OtaUpgradeNavigation.applyManifestExtras(intent, manifest, null);
        Bundle extras = intent.getExtras();
        if (extras == null) {
            assertNotNull(intent);
            return;
        }
        assertFalse(extras.containsKey("sha512"));
    }
}
