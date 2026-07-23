package com.lasercyber.lws.ai.stain;
import com.lasercyber.lws.ai.model.OpencvStainDetectJson;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ai.model.StainDetectSource;
import com.lasercyber.lws.ai.stain.OpencvStainDetectResultMapper;
import com.lasercyber.lws.ai.stream.StreamDetectEvent;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.ai.upload.StainAuditUploadCoordinator;
import com.lasercyber.lws.ui.common.utils.json.GsonInitUtils;

import org.junit.After;
import org.junit.Before;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;

public class StainAuditUploadCoordinatorTest {

    @Rule
    public TemporaryFolder tmp = new TemporaryFolder();

    @Before
    public void setUp() {
        GsonInitUtils.initGson();
        StainAuditUploadCoordinator.setEnqueueSinkForTest(null);
        StainAuditUploadCoordinator.resetThrottleForTest();
    }

    @After
    public void tearDown() {
        StainAuditUploadCoordinator.setEnqueueSinkForTest(null);
        StainAuditUploadCoordinator.resetThrottleForTest();
    }

    @Test
    public void detectFailedWithInputFrame_enqueues() throws Exception {
        File frameDir = tmp.newFolder("frame_7");
        File inputFrame = new File(frameDir, "input_frame.jpg");
        Files.write(inputFrame.toPath(), "jpg".getBytes(StandardCharsets.UTF_8));
        String summary = "{\"ok\":false,\"code\":-3,\"reason\":\"insufficient_regions_after_erode\",\"files\":[\""
                + inputFrame.getAbsolutePath().replace("\\", "\\\\") + "\"]}";
        StreamDetectEvent.DetectResult event = StreamDetectEvent.DetectResult.forTest(
                "lens_det", 100L, 7L, 1920, 1080, -3, false, summary);
        OpencvStainDetectResult result = OpencvStainDetectResultMapper.fromNativeSummary(
                summary, 1920, 1080, 100L, StainDetectSource.LIVE);

        CountDownLatch latch = new CountDownLatch(1);
        AtomicBoolean enqueued = new AtomicBoolean(false);
        AtomicReference<File> imageRef = new AtomicReference<>();
        StainAuditUploadCoordinator.setEnqueueSinkForTest((context, imageFile, statJson) -> {
            enqueued.set(true);
            imageRef.set(imageFile);
            latch.countDown();
            return true;
        });

        StainAuditUploadCoordinator.maybeEnqueueLiveDetectFailed(null, event, result);

        assertTrue(latch.await(2, TimeUnit.SECONDS));
        assertTrue(enqueued.get());
        assertEquals(inputFrame.getAbsolutePath(), imageRef.get().getAbsolutePath());
        // Staged successfully → native frame_* removed on background thread after sink returns.
        for (int i = 0; i < 40 && frameDir.exists(); i++) {
            Thread.sleep(25);
        }
        assertFalse(frameDir.exists());
    }

    @Test
    public void frameRejected_doesNotEnqueue() {
        String summary = "{\"ok\":false,\"code\":-5,\"reason\":\"overexposed\",\"files\":[]}";
        StreamDetectEvent.DetectResult event = StreamDetectEvent.DetectResult.forTest(
                "lens_det", 100L, 8L, 1920, 1080, -5, false, summary);
        OpencvStainDetectResult result = OpencvStainDetectResultMapper.fromNativeSummary(
                summary, 1920, 1080, 100L, StainDetectSource.LIVE);

        AtomicBoolean enqueued = new AtomicBoolean(false);
        StainAuditUploadCoordinator.setEnqueueSinkForTest((context, imageFile, statJson) -> {
            enqueued.set(true);
            return true;
        });

        StainAuditUploadCoordinator.maybeEnqueueLiveDetectFailed(null, event, result);

        assertFalse(enqueued.get());
    }

    @Test
    public void findWrittenFile_resolvesAbsoluteAndRelative() throws Exception {
        File lensGuard = tmp.newFolder("lens_guard");
        File nested = new File(lensGuard, "opencv_stain_detect/sess/frame_1");
        assertTrue(nested.mkdirs());
        File inputFrame = new File(nested, "input_frame.jpg");
        Files.write(inputFrame.toPath(), "x".getBytes(StandardCharsets.UTF_8));

        OpencvStainDetectJson.Summary abs = OpencvStainDetectJson.parseSummary(
                "{\"ok\":false,\"code\":-3,\"files\":[\"" + inputFrame.getAbsolutePath() + "\"]}");
        assertEquals(inputFrame.getAbsolutePath(),
                OpencvStainDetectJson.findWrittenFile(abs, "input_frame.jpg").getAbsolutePath());

        String rel = "opencv_stain_detect/sess/frame_1/input_frame.jpg";
        OpencvStainDetectJson.Summary relative = OpencvStainDetectJson.parseSummary(
                "{\"ok\":false,\"code\":-3,\"files\":[\"" + rel + "\"]}");
        File resolved = OpencvStainDetectJson.findWrittenFile(relative, "input_frame.jpg", lensGuard);
        assertNotNull(resolved);
        assertEquals(inputFrame.getAbsolutePath(), resolved.getAbsolutePath());
    }
}
