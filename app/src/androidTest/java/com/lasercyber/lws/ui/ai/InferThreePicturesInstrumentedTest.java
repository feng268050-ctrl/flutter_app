package com.lasercyber.lws.ui.ai;

import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import android.content.Context;
import android.util.Log;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;

import com.lasercyber.lws.ai.bridge.AiLibraryDirectory;
import com.lasercyber.lws.ai.engine.AiManager;
import com.lasercyber.lws.ai.NativeBridge;
import com.lasercyber.lws.ui.common.upgrade.BundledLibraryBootstrap;

import org.junit.Ignore;
import org.junit.Test;
import org.junit.runner.RunWith;

import java.io.File;

/**
 * Runs JPG inference for three files under {@code /sdcard/lws/picture/} and asserts
 * result images are written under {@code /sdcard/lws/result/} (see {@link AiManager}).
 * <p>
 * Ignored by default: some devices hit native SIGBUS during {@code nativeCreate}; remove
 * {@link Ignore} to run locally when the engine is stable on hardware.
 */
@Ignore("Manual/local: three JPG inference; native engine may crash on some RK boards during create")
@RunWith(AndroidJUnit4.class)
public class InferThreePicturesInstrumentedTest {

    private static final String TAG = "InferThreePictures";
    private static final String RESULT_DIR_PREFIX = "/sdcard/lws/result";

    private static final String[] SOURCE_IMAGES = {
            "/sdcard/lws/picture/微信图片_20260416145221_2_2.jpg",
            "/sdcard/lws/picture/微信图片_20260416145221_3_2.jpg",
            "/sdcard/lws/picture/微信图片_20260416145222_4_2.jpg",
    };

    @Test
    public void inferThreeImagesToSdcardResult() {
        Context appContext = InstrumentationRegistry.getInstrumentation()
                .getTargetContext()
                .getApplicationContext();

        for (String path : SOURCE_IMAGES) {
            File src = new File(path);
            assertTrue("source image missing: " + path, src.isFile());
        }

        BundledLibraryBootstrap.run(appContext);
        assertApkAiLibReady(appContext);

        AiManager manager = AiManager.getInstance();
        manager.start(appContext);
        assertTrue("lens guard engine not running", manager.isRknnEngineRunning());
        File runtimeConfig = new File(appContext.getFilesDir(), "lens_guard/config.yaml");
        assertTrue("runtime config missing: " + runtimeConfig.getAbsolutePath(), runtimeConfig.isFile());

        for (String path : SOURCE_IMAGES) {
            AiManager.InferenceImageResult inferResult = manager.rknnStainDetectFromJpgAndSaveResult(path);
            assertNotNull("infer result is null for " + path, inferResult);
            assertTrue(
                    "inference failed for " + path + ": code=" + inferResult.getCode()
                            + ", msg=" + inferResult.getMessage(),
                    inferResult.isSuccess());
            String out = inferResult.getResultImagePath();
            assertNotNull("result path is null for " + path, out);
            assertTrue(
                    "expected result under " + RESULT_DIR_PREFIX + ", got: " + out,
                    out.startsWith(RESULT_DIR_PREFIX));
            File resultImage = new File(out);
            assertTrue("result image missing: " + out, resultImage.isFile());
            assertTrue("result image is empty: " + out, resultImage.length() > 0);
            Log.i(TAG, "OK: " + path + " -> " + out);
        }
    }

    private static void assertApkAiLibReady(Context context) {
        File libDir = AiLibraryDirectory.resolveNativeLibDir(context);
        assertNotNull("AI native lib dir missing — run make ai before instrumented tests", libDir);
        assertTrue("libc++_shared.so missing", new File(libDir, "libc++_shared.so").isFile());
        assertTrue("librknnrt.so missing", new File(libDir, "librknnrt.so").isFile());
        assertTrue("libai.so missing", new File(libDir, "libai.so").isFile());
        Log.i(TAG, "AI native lib dir ready: " + libDir.getAbsolutePath());
    }
}
