package com.lasercyber.lws.ai;

import org.junit.Assert;
import org.junit.Test;

import java.nio.ByteBuffer;

public class Nv12FrameUtilTest {

    @Test
    public void argbToNv12_producesExpectedBufferSize() {
        int width = 640;
        int height = 480;
        int[] argb = new int[width * height];
        ByteBuffer nv12 = Nv12FrameUtil.argbToNv12(argb, width, height);
        Assert.assertTrue(nv12.isDirect());
        Assert.assertEquals(width * height * 3 / 2, nv12.capacity());
        Assert.assertEquals(width * height * 3 / 2, nv12.duplicate().remaining());
    }

    @Test
    public void argbToNv12_blackPixelUsesBt601NeutralChroma() {
        int width = 2;
        int height = 2;
        int[] argb = new int[width * height];
        ByteBuffer nv12 = Nv12FrameUtil.argbToNv12(argb, width, height);
        Assert.assertEquals((byte) 16, nv12.get(0));
        int frameSize = width * height;
        Assert.assertEquals((byte) 128, nv12.get(frameSize));
        Assert.assertEquals((byte) 128, nv12.get(frameSize + 1));
    }

    @Test
    public void preparePayload_limitsBufferToResolvedNv12Size() {
        int width = 1920;
        int height = 1080;
        ByteBuffer nv12 = ByteBuffer.allocateDirect(width * height * 3 / 2);
        Nv12FrameUtil.Payload payload = Nv12FrameUtil.preparePayload(nv12, width, 1088);
        Assert.assertEquals(height, payload.height);
        Assert.assertEquals(width * height * 3 / 2, payload.buffer.remaining());
    }

    @Test
    public void evenDimension_roundsDownToEven() {
        Assert.assertEquals(1918, Nv12FrameUtil.evenDimension(1919));
        Assert.assertEquals(1080, Nv12FrameUtil.evenDimension(1080));
    }
}
