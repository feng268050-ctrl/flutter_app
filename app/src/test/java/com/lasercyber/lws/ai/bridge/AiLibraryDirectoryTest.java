package com.lasercyber.lws.ai.bridge;
import static org.junit.Assert.assertNull;

import com.lasercyber.lws.ai.bridge.AiLibraryDirectory;

import org.junit.Test;

public class AiLibraryDirectoryTest {

    @Test
    public void resolveNativeLibDir_nullContext() {
        assertNull(AiLibraryDirectory.resolveNativeLibDir(null));
    }

    @Test
    public void apkNativeLibDir_nullContext() {
        assertNull(AiLibraryDirectory.apkNativeLibDir(null));
    }
}
