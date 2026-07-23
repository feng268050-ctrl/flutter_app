package com.lasercyber.lws.ui.common.utils;

import org.junit.Assert;
import org.junit.Test;

import java.io.File;

public class VideoFileUtilParentDirsTest {

    @Test
    public void ensureParentDirs_createsNestedPath() {
        File root = new File(System.getProperty("java.io.tmpdir"), "lws-video-test");
        File nested = new File(new File(new File(root, "movie"), "2026-06-24"), "clip.mp4");
        try {
            Assert.assertTrue(VideoFileUtil.ensureParentDirs(nested.getAbsolutePath()));
            Assert.assertTrue(nested.getParentFile().isDirectory());
        } finally {
            File parent = nested.getParentFile();
            if (parent != null) {
                parent.delete();
            }
            new File(root, "movie").delete();
            root.delete();
        }
    }
}
