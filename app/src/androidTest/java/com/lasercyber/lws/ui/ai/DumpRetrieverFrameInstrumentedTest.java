package com.lasercyber.lws.ui.ai;

import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import android.graphics.Bitmap;
import android.media.MediaMetadataRetriever;
import android.util.Log;

import androidx.test.ext.junit.runners.AndroidJUnit4;

import org.junit.Test;
import org.junit.runner.RunWith;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;

/**
 * One-shot: dump a MediaMetadataRetriever frame (same API as {@code ProcessVideoAiSession})
 * to {@code /sdcard/lws/debug/} for adb pull. Process-video infer uses {@link com.lasercyber.lws.ai.Nv12FrameUtil}
 * after retriever bitmap sampling (see offline-inference-nv12-unification).
 */
@RunWith(AndroidJUnit4.class)
public class DumpRetrieverFrameInstrumentedTest {

    private static final String TAG = "DumpRetrieverFrame";

    @Test
    public void dumpFrameAt2400ms() throws IOException {
        dumpFrame(
                "/storage/emulated/0/lws/movie/2026-05-31/26-05-31_22-58-58.mp4",
                2400L,
                "/sdcard/lws/debug/retriever_2400ms_26-05-31_22-58-58.png");
    }

    static void dumpFrame(String videoPath, long sampleMs, String outputPath) throws IOException {
        File video = new File(videoPath);
        assertTrue("video missing: " + videoPath, video.isFile());

        File out = new File(outputPath);
        File parent = out.getParentFile();
        if (parent != null && !parent.isDirectory()) {
            assertTrue("failed to create " + parent.getAbsolutePath(), parent.mkdirs());
        }

        MediaMetadataRetriever retriever = new MediaMetadataRetriever();
        try {
            retriever.setDataSource(video.getAbsolutePath());
            Bitmap bitmap = retriever.getFrameAtTime(
                    sampleMs * 1000L,
                    MediaMetadataRetriever.OPTION_CLOSEST);
            assertNotNull("getFrameAtTime returned null at ms=" + sampleMs, bitmap);
            try {
                try (FileOutputStream fos = new FileOutputStream(out)) {
                    assertTrue("PNG compress failed", bitmap.compress(Bitmap.CompressFormat.PNG, 100, fos));
                }
                Log.i(TAG, "saved ms=" + sampleMs
                        + " size=" + bitmap.getWidth() + "x" + bitmap.getHeight()
                        + " path=" + out.getAbsolutePath()
                        + " bytes=" + out.length());
            } finally {
                if (!bitmap.isRecycled()) {
                    bitmap.recycle();
                }
            }
        } finally {
            try {
                retriever.release();
            } catch (Exception ignored) {
            }
        }
    }
}
