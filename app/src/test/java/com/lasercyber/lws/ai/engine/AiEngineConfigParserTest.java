package com.lasercyber.lws.ai.engine;
import com.lasercyber.lws.ai.engine.AiEngineConfigParser;
import com.lasercyber.lws.ai.stain.LensDetConsecutiveOkFilter;

import org.junit.Assert;
import org.junit.Test;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;

public class AiEngineConfigParserTest {

    @Test
    public void parseMinConsecutiveOkFrames_readsOpencvStainDetectSection() throws IOException {
        File config = File.createTempFile("config", ".yaml");
        try (FileWriter writer = new FileWriter(config)) {
            writer.write("opencv_stain_detect:\n");
            writer.write("  min_consecutive_ok_frames: 2\n");
            writer.write("models:\n");
            writer.write("  det:\n");
            writer.write("    enabled: true\n");
        }
        Assert.assertEquals(2, AiEngineConfigParser.parseMinConsecutiveOkFrames(config));
    }

    @Test
    public void parseMinConsecutiveOkFrames_usesDefaultWhenMissing() {
        Assert.assertEquals(
                LensDetConsecutiveOkFilter.DEFAULT_MIN_CONSECUTIVE_OK_FRAMES,
                AiEngineConfigParser.parseMinConsecutiveOkFrames(null));
    }
}
