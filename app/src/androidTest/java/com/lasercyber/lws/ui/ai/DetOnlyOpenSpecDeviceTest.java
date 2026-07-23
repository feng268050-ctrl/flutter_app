package com.lasercyber.lws.ui.ai;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import android.content.Context;
import android.util.Log;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;

import com.lasercyber.lws.ai.bridge.AiLibraryDirectory;
import com.lasercyber.lws.ai.model.AiStainDetectResult;
import com.lasercyber.lws.ai.engine.AiManager;
import com.lasercyber.lws.ai.NativeBridge;
import com.lasercyber.lws.ui.bean.entity.DeviceInfo;
import com.lasercyber.lws.ui.bean.event.LensClsSnapshotEvent;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.upgrade.BundledLibraryBootstrap;

import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;

import java.io.File;
/**
 * OpenSpec {@code det-only-disable-cls} device verification on RK3566.
 * Preconditions: {@code /sdcard/lws/picture/bus_test.jpg} exists (adb push from lensinspector assets).
 */
@RunWith(AndroidJUnit4.class)
public class DetOnlyOpenSpecDeviceTest {

    private static final String TAG = "DetOnlyOpenSpec";
    private static final String SOURCE_IMAGE = "/sdcard/lws/picture/bus_test.jpg";

    @Before
    public void pushTestImageIfPresent() {
        File src = new File(SOURCE_IMAGE);
        assertTrue("missing " + SOURCE_IMAGE + " — adb push lensinspector/assets/bus.jpg", src.isFile());
    }

    @Test
    public void detOnlyCapabilitiesOfflineInferAndClsStub() throws Exception {
        Context ctx = InstrumentationRegistry.getInstrumentation().getTargetContext().getApplicationContext();
        BundledLibraryBootstrap.run(ctx);
        assertApkAiLibReady(ctx);

        AiManager manager = AiManager.getInstance();
        manager.start(ctx);
        assertTrue("engine not running", manager.isRknnEngineRunning());

        Log.i(TAG, "typed stain infer linked=" + NativeBridge.isNativeRknnStainDetectLinked());

        AiStainDetectResult offline = manager.rknnStainDetectFromJpg(SOURCE_IMAGE);
        assertNotNull(offline);
        assertTrue("nativeRknnStainDetectFromJpg smoke", offline.success);
        assertEquals("offline_infer", offline.source);

        AiManager.InferenceImageResult stain = manager.rknnStainDetectFromJpgAndSaveResult(SOURCE_IMAGE);
        assertNotNull(stain);
        assertTrue("stain infer failed: " + stain.getMessage(), stain.isSuccess());
        Log.i(TAG, "stain infer ok -> " + stain.getResultImagePath());

        LensClsSnapshotEvent cls = manager.publishLastClsSnapshot();
        assertNotNull(cls);
        assertFalse("cls stub valid:false", cls.isValid());
        Log.i(TAG, "cls snapshot raw=" + cls.getRawJson());

        manager.setAiVisionPreviewDetectionEnabled(true);
        Log.i(TAG, "preview det enabled (live preview_det JSON needs I420 stream + laser OFF)");
    }

    private static void assertApkAiLibReady(Context context) {
        File libDir = AiLibraryDirectory.resolveNativeLibDir(context);
        assertNotNull("AI native lib dir missing — run make ai before instrumented tests", libDir);
        assertTrue("libai.so missing", new File(libDir, "libai.so").isFile());
        assertTrue("librknnrt.so missing", new File(libDir, "librknnrt.so").isFile());
        Log.i(TAG, "using AI native lib dir=" + libDir.getAbsolutePath());
    }
}
