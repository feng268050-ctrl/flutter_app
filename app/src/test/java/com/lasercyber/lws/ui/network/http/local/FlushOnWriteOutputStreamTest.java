package com.lasercyber.lws.ui.network.http.local;

import org.junit.Assert;
import org.junit.Test;

import java.io.ByteArrayOutputStream;
import java.io.IOException;

public class FlushOnWriteOutputStreamTest {

    @Test
    public void write_flushesUnderlyingStreamAfterEachWrite() throws IOException {
        CountingFlushStream underlying = new CountingFlushStream();
        FlushOnWriteOutputStream wrapped = new FlushOnWriteOutputStream(underlying);
        wrapped.write(new byte[] {1, 2});
        wrapped.write(3);
        Assert.assertEquals(2, underlying.flushCount);
    }

    private static final class CountingFlushStream extends ByteArrayOutputStream {
        int flushCount;

        @Override
        public void flush() {
            flushCount++;
        }
    }
}
