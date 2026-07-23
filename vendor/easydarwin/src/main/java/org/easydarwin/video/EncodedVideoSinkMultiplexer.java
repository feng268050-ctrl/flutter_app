package org.easydarwin.video;

import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Fan-out {@link EncodedVideoSink} for multiple LAN / recording consumers on one {@link EasyPlayerClient}.
 */
public final class EncodedVideoSinkMultiplexer implements EncodedVideoSink {

    private final List<EncodedVideoSink> sinks = new CopyOnWriteArrayList<>();

    public void addSink(EncodedVideoSink sink) {
        if (sink != null && !sinks.contains(sink)) {
            sinks.add(sink);
        }
    }

    public void removeSink(EncodedVideoSink sink) {
        if (sink != null) {
            sinks.remove(sink);
        }
    }

    public void clear() {
        sinks.clear();
    }

    public boolean isEmpty() {
        return sinks.isEmpty();
    }

    @Override
    public void onEncodedVideoFrame(byte[] annexB, int offset, int length, int codec, boolean keyFrame,
                                    long ptsUs, int width, int height) {
        for (EncodedVideoSink sink : sinks) {
            try {
                sink.onEncodedVideoFrame(annexB, offset, length, codec, keyFrame, ptsUs, width, height);
            } catch (Throwable ignored) {
            }
        }
    }
}
