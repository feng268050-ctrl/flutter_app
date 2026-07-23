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
import com.lasercyber.lws.ui.common.config.DeviceApiOriginConfig;
import com.lasercyber.lws.ui.common.upgrade.BundledLibraryBootstrap;
import com.lasercyber.lws.ui.network.http.DeviceWorkerAiReportClient;

import org.junit.Test;
import org.junit.runner.RunWith;

import java.io.File;

import okhttp3.HttpUrl;

@RunWith(AndroidJUnit4.class)
public class AiStainDetectUploadInstrumentedTest {

    private static final String TAG = "AiStainDetectUploadTest";
    private static final String SOURCE_IMAGE =
            "/sdcard/lws/picture/rtsp10100100100PR0/微信图片_20260416145222_4_2.jpg";
    private static final String TEST_SN = "SN-EMU-001";
    // Preconditions:
    // 1) SOURCE_IMAGE exists and readable on target device
    // 2) Network can reach https://api-test.lasercyber.workers.dev
    // 3) TEST_SN is accepted by testing environment

    @Test
    public void inferAndUploadToCloud() {
        Context appContext = InstrumentationRegistry.getInstrumentation()
                .getTargetContext()
                .getApplicationContext();

        File source = new File(SOURCE_IMAGE);
        assertTrue("source image missing: " + SOURCE_IMAGE, source.isFile());

        // Ensure bundled process-library / videos and APK jniLibs are ready.
        BundledLibraryBootstrap.run(appContext);
        assertApkAiLibReady(appContext);

        AiManager manager = AiManager.getInstance();
        manager.start(appContext);
        assertTrue("lens guard engine not running", manager.isRknnEngineRunning());
        File runtimeConfig = new File(appContext.getFilesDir(), "lens_guard/config.yaml");
        assertTrue("runtime config missing: " + runtimeConfig.getAbsolutePath(), runtimeConfig.isFile());

        AiManager.InferenceImageResult inferResult = manager.rknnStainDetectFromJpgAndSaveResult(SOURCE_IMAGE);
        assertNotNull("infer result is null", inferResult);
        assertTrue("inference failed: code=" + inferResult.getCode() + ", msg=" + inferResult.getMessage(),
                inferResult.isSuccess());
        assertNotNull("result path is null", inferResult.getResultImagePath());

        File resultImage = new File(inferResult.getResultImagePath());
        assertTrue("result image missing: " + inferResult.getResultImagePath(), resultImage.isFile());
        assertTrue("result image is empty: " + inferResult.getResultImagePath(), resultImage.length() > 0);
        Log.i(TAG, "inference output: " + resultImage.getAbsolutePath());

        DeviceApiOriginConfig.setPinnedBaseForTest(HttpUrl.get("https://api-test.lasercyber.workers.dev"));
        // NOTE: This direct client call is for transport diagnosis only.
        // Product-path validation MUST go through AiUploadCoordinator.enqueue + WorkManager drain.
        DeviceWorkerAiReportClient.Outcome upload = DeviceWorkerAiReportClient.postAiReport(
                TEST_SN,
                0,
                "lens",
                resultImage,
                "{\"source\":\"instrumented-test\"}"
        );

        assertTrue("upload failed: " + upload.getErrorMessage(), upload.isOk());
        Log.i(TAG, "upload success for image: " + resultImage.getAbsolutePath());
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
