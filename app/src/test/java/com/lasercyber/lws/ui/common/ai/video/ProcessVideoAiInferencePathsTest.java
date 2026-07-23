package com.lasercyber.lws.ui.common.ai.video;

import com.lasercyber.lws.ui.bean.entity.vo.ProcessParamsVideoVo;

import org.junit.Assert;
import org.junit.Test;

import java.io.File;

public class ProcessVideoAiInferencePathsTest {

    @Test
    public void inferenceMp4Tmp_appendsTmpSuffix() {
        ProcessParamsVideoVo vo = new ProcessParamsVideoVo();
        vo.setId(42L);
        vo.setVideoId("vid-1");
        File mp4 = new File("/data/user/0/app/files/ai-vision-inference-videos/42/ai-vision-inference-42-abc.mp4");
        File tmp = ProcessVideoAiInferencePaths.inferenceMp4Tmp(mp4);
        Assert.assertTrue(tmp.getName().endsWith(".mp4.tmp"));
    }
}
