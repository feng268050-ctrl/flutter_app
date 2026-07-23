package com.lasercyber.lws.ai.zeropoint;
import com.lasercyber.lws.ai.zeropoint.ZeroPointDetectJson;
import com.lasercyber.lws.ai.zeropoint.ZeroPointMockJsonLoader;

import org.junit.After;
import org.junit.Assert;
import org.junit.Before;
import org.junit.Test;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

public class ZeroPointMockJsonLoaderTest {

    private Path tempDir;
    private Path mockFile;

    @Before
    public void setUp() throws IOException {
        tempDir = Files.createTempDirectory("zp-mock-test");
        mockFile = tempDir.resolve("zero_point_mock.json");
        ZeroPointMockJsonLoader.setMockPathOverrideForTest(mockFile.toString());
        ZeroPointMockJsonLoader.setReleaseChannelOverrideForTest(false);
    }

    @After
    public void tearDown() {
        ZeroPointMockJsonLoader.setReleaseChannelOverrideForTest(null);
        ZeroPointMockJsonLoader.setMockPathOverrideForTest(null);
        if (tempDir != null) {
            try {
                Files.deleteIfExists(mockFile);
                Files.deleteIfExists(tempDir);
            } catch (IOException ignored) {
            }
        }
    }

    @Test
    public void tryLoadSample_releaseChannel_returnsNull() throws Exception {
        ZeroPointMockJsonLoader.setReleaseChannelOverrideForTest(true);
        writeMock("{\"ok\":true,\"code\":0,\"offset_x\":-9.0,\"offset_y\":0.0}");
        Assert.assertNull(ZeroPointMockJsonLoader.tryLoadSample());
    }

    @Test
    public void tryLoadSample_stagingValidFile_parsesSample() throws Exception {
        writeMock("{\"ok\":true,\"code\":0,\"offset_x\":-9.0,\"offset_y\":0.0}");
        ZeroPointDetectJson.Sample sample = ZeroPointMockJsonLoader.tryLoadSample();
        Assert.assertNotNull(sample);
        Assert.assertTrue(sample.ok);
        Assert.assertEquals(-9.0, sample.offsetX, 0.001);
        Assert.assertEquals(0.0, sample.offsetY, 0.001);
    }

    @Test
    public void tryLoadSample_missingFile_returnsNull() {
        Assert.assertNull(ZeroPointMockJsonLoader.tryLoadSample());
    }

    @Test
    public void tryLoadSample_invalidJson_returnsNull() throws Exception {
        writeMock("not-json");
        Assert.assertNull(ZeroPointMockJsonLoader.tryLoadSample());
    }

    @Test
    public void mockFileExists_releaseChannel_false() throws Exception {
        ZeroPointMockJsonLoader.setReleaseChannelOverrideForTest(true);
        writeMock("{\"ok\":true,\"code\":0,\"offset_x\":0,\"offset_y\":0}");
        Assert.assertFalse(ZeroPointMockJsonLoader.mockFileExists());
    }

    private void writeMock(String content) throws IOException {
        Files.write(mockFile, content.getBytes(StandardCharsets.UTF_8));
    }
}
