package com.lasercyber.lws.ai.stain;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ai.model.StainDetectSource;
import com.lasercyber.lws.ai.stain.StainDetectAlertPublisher;

import org.junit.Test;

public class StainDetectAlertPublisherTest {

    @Test
    public void publishFromWorker_doesNotThrow() {
        StainDetectAlertPublisher publisher = StainDetectAlertPublisher.getInstance();
        OpencvStainDetectResult result = new OpencvStainDetectResult(
                true, 0, "target", 100.0, 200.0, 1920, 1080, StainDetectSource.LIVE, 1L);
        publisher.publishFromWorker(result);
    }
}
