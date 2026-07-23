package com.lasercyber.lws.ai.zeropoint;
import com.lasercyber.lws.ai.zeropoint.ZeroPointPendingCorrectionStore;
import com.lasercyber.lws.ai.zeropoint.ZeroPointPendingJsonLoader;

import org.junit.After;
import org.junit.Assert;
import org.junit.Before;
import org.junit.Test;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

public class ZeroPointPendingJsonLoaderTest {

    private Path tempDir;
    private Path pendingFile;
    private ZeroPointPendingCorrectionStore store;

    @Before
    public void setUp() throws IOException {
        tempDir = Files.createTempDirectory("zp-pending-test");
        pendingFile = tempDir.resolve("zero_point_pending.json");
        ZeroPointPendingJsonLoader.setPendingPathOverrideForTest(pendingFile.toString());
        ZeroPointPendingJsonLoader.setReleaseChannelOverrideForTest(false);
        store = ZeroPointPendingCorrectionStore.getInstance();
        store.clear();
    }

    @After
    public void tearDown() {
        ZeroPointPendingJsonLoader.setReleaseChannelOverrideForTest(null);
        ZeroPointPendingJsonLoader.setPendingPathOverrideForTest(null);
        store.clear();
        if (tempDir != null) {
            try {
                Files.deleteIfExists(pendingFile);
                Files.deleteIfExists(tempDir);
            } catch (IOException ignored) {
            }
        }
    }

    @Test
    public void tryHydratePendingFrom_releaseChannel_returnsFalse() throws Exception {
        ZeroPointPendingJsonLoader.setReleaseChannelOverrideForTest(true);
        writePending("{\"valid_samples\":4,\"offset_x\":-9.0,\"offset_y\":0.0}");

        Assert.assertFalse(ZeroPointPendingJsonLoader.tryHydratePendingFromFile());
        Assert.assertFalse(store.hasFreshPending());
    }

    @Test
    public void tryHydratePendingFrom_validFile_hydratesStoreAndDeletesFile() throws Exception {
        writePending("{\"valid_samples\":4,\"offset_x\":-9.0,\"offset_y\":0.0}");

        Assert.assertTrue(ZeroPointPendingJsonLoader.tryHydratePendingFromFile());
        Assert.assertTrue(store.hasFreshPending());
        ZeroPointPendingCorrectionStore.PendingCorrection pending = store.peekForTest();
        Assert.assertNotNull(pending);
        Assert.assertEquals(4, pending.validSamples);
        Assert.assertEquals(-9.0, pending.meanOffsetX, 0.001);
        Assert.assertEquals(0.0, pending.meanOffsetY, 0.001);
        Assert.assertFalse(Files.exists(pendingFile));
    }

    @Test
    public void tryHydratePendingFrom_missingFile_returnsFalse() {
        Assert.assertFalse(ZeroPointPendingJsonLoader.tryHydratePendingFromFile());
        Assert.assertFalse(store.hasFreshPending());
    }

    @Test
    public void tryHydratePendingFrom_invalidJson_returnsFalse() throws Exception {
        writePending("not-json");

        Assert.assertFalse(ZeroPointPendingJsonLoader.tryHydratePendingFromFile());
        Assert.assertFalse(store.hasFreshPending());
        Assert.assertTrue(Files.exists(pendingFile));
    }

    @Test
    public void parsePendingPayload_defaultsValidSamplesToOne() {
        ZeroPointPendingJsonLoader.PendingPayload payload =
                ZeroPointPendingJsonLoader.parsePendingPayload(
                        "{\"offset_x\":-9.0,\"offset_y\":0.0}");

        Assert.assertNotNull(payload);
        Assert.assertEquals(1, payload.validSamples);
        Assert.assertEquals(-9.0, payload.offsetX, 0.001);
        Assert.assertEquals(0.0, payload.offsetY, 0.001);
    }

    @Test
    public void parsePendingPayload_rejectsMissingOffsets() {
        Assert.assertNull(ZeroPointPendingJsonLoader.parsePendingPayload("{\"valid_samples\":4}"));
    }

    private void writePending(String content) throws IOException {
        Files.write(pendingFile, content.getBytes(StandardCharsets.UTF_8));
    }
}
