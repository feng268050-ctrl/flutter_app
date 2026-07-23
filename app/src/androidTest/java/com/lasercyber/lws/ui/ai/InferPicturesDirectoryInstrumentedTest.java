package com.lasercyber.lws.ui.ai;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import android.content.Context;
import android.util.Log;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;

import com.lasercyber.lws.ai.engine.AiManager;
import com.lasercyber.lws.ai.NativeBridge;
import com.lasercyber.lws.ui.common.upgrade.BundledLibraryBootstrap;

import org.junit.Test;
import org.junit.runner.RunWith;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

@RunWith(AndroidJUnit4.class)
public class InferPicturesDirectoryInstrumentedTest {
    private static final String TAG = "InferPicturesDir";
    private static final String SOURCE_DIR = "/sdcard/Pictures";
    private static final String[] EXTENSIONS = new String[]{".jpg", ".jpeg", ".png", ".bmp", ".webp"};

    @Test
    public void inferAllPicturesAndPrintResultPaths() {
        Context appContext = appContext();

        File dir = new File(SOURCE_DIR);
        assertTrue("source dir missing: " + SOURCE_DIR, dir.isDirectory());
        List<File> inputs = listSupportedImages(dir);
        assertTrue("no supported images under " + SOURCE_DIR, !inputs.isEmpty());

        AiManager manager = ensureEngineRunning(appContext);

        int successCount = 0;
        for (File src : inputs) {
            AiManager.InferenceImageResult result = manager.rknnStainDetectFromJpgAndSaveResult(src.getAbsolutePath());
            assertNotNull("infer result null: " + src.getAbsolutePath(), result);
            String outputPath = result.getResultImagePath();
            assertNotNull("output path null: " + src.getAbsolutePath(), outputPath);
            File outFile = new File(outputPath);
            boolean outputReady = outFile.isFile() && outFile.length() > 0;
            if (result.isSuccess() && outputReady) {
                successCount++;
                Log.i(TAG, "INFER_OK src=" + src.getAbsolutePath() + " out=" + outputPath);
            } else {
                Log.e(TAG, "INFER_FAIL src=" + src.getAbsolutePath()
                        + " code=" + result.getCode()
                        + " msg=" + result.getMessage()
                        + " out=" + outputPath
                        + " outputReady=" + outputReady);
            }
        }
        assertTrue("no image inference succeeded under " + SOURCE_DIR, successCount > 0);
    }

    @Test
    public void inferMissingImageReturnsReadFailure() {
        Context appContext = appContext();
        AiManager manager = ensureEngineRunning(appContext);

        File output = new File("/sdcard/lws/result/missing_input_result.jpg");
        int code = NativeBridge.guardedRknnStainDetectFromJpgAndSave(
                manager.getHandle(),
                "/sdcard/Pictures/__missing_native_infer_input__.jpg",
                output.getAbsolutePath());
        assertEquals("missing input image should map to native image-read failure", -2, code);
    }

    private static Context appContext() {
        return InstrumentationRegistry.getInstrumentation()
                .getTargetContext()
                .getApplicationContext();
    }

    private static AiManager ensureEngineRunning(Context appContext) {
        AiManager manager = AiManager.getInstance();
        for (int attempt = 0; attempt < 3 && !manager.isRknnEngineRunning(); attempt++) {
            BundledLibraryBootstrap.run(appContext);
            manager.start(appContext);
            if (!manager.isRknnEngineRunning()) {
                sleepQuietly(1000);
            }
        }
        assertTrue("lens guard engine not running after bootstrap retry", manager.isRknnEngineRunning());
        return manager;
    }

    private static void sleepQuietly(long millis) {
        try {
            Thread.sleep(millis);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    private static List<File> listSupportedImages(File dir) {
        File[] files = dir.listFiles();
        List<File> result = new ArrayList<>();
        if (files == null) {
            return result;
        }
        for (File file : files) {
            if (!file.isFile()) {
                continue;
            }
            String name = file.getName().toLowerCase(Locale.ROOT);
            for (String ext : EXTENSIONS) {
                if (name.endsWith(ext)) {
                    result.add(file);
                    break;
                }
            }
        }
        return result;
    }
}
