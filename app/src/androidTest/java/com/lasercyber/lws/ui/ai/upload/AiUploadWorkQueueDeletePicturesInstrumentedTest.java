package com.lasercyber.lws.ui.ai.upload;

import static org.junit.Assert.assertTrue;

import android.content.Context;
import android.os.SystemClock;
import android.util.Log;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;

import org.junit.Test;
import org.junit.runner.RunWith;

import java.io.File;
import java.util.ArrayList;
import java.util.List;

@RunWith(AndroidJUnit4.class)
public class AiUploadWorkQueueDeletePicturesInstrumentedTest {

    private static final String TAG = "AiUploadQueueTest";
    private static final String TEST_SN = "d765d68d6415fcaa";

    @Test
    public void queueUpload_shouldUploadAndDeleteAllPicturesOnSuccess() {
        Context app = InstrumentationRegistry.getInstrumentation().getTargetContext().getApplicationContext();
        AiUploadCoordinator.deleteRecursive(AiUploadPaths.root(app));

        List<File> targets = new ArrayList<>(
                AiUploadPictureDirectoryQueue.listSupportedImageFiles(AiUploadPictureDirectoryQueue.DEFAULT_PICTURES_DIR));
        assertTrue("no supported pictures found under /sdcard/Pictures", !targets.isEmpty());

        int queued = AiUploadPictureDirectoryQueue.enqueueDefaultPicturesToTestWorker(app, TEST_SN);
        assertTrue("expected all /sdcard/Pictures images to be queued, targets=" + targets.size()
                + " queued=" + queued, queued == targets.size());

        long deadline = SystemClock.elapsedRealtime() + Math.max(180_000L, targets.size() * 45_000L);
        while (SystemClock.elapsedRealtime() < deadline) {
            if (allDeleted(targets)) {
                Log.i(TAG, "all target pictures deleted after queue upload");
                return;
            }
            SystemClock.sleep(2_000L);
        }

        List<String> remaining = new ArrayList<>();
        for (File f : targets) {
            if (f.exists()) {
                remaining.add(f.getAbsolutePath());
            }
        }
        assertTrue("queue upload finished but pictures still exist: " + remaining, remaining.isEmpty());
    }

    private static boolean allDeleted(List<File> files) {
        for (File f : files) {
            if (f.exists()) {
                return false;
            }
        }
        return true;
    }
}
