package org.easydarwin.video;

/**
 * Receives encoded video access units (H.264 / H.265) from {@link EasyPlayerClient}
 * on the same path as recording muxer writes, without requiring display decode.
 */
public interface EncodedVideoSink {

    /**
     * @param annexB      Annex-B bitstream (may include start codes)
     * @param offset      start offset in {@code annexB}
     * @param length      byte length
     * @param codec       {@link EasyPlayerClient#EASY_SDK_VIDEO_CODEC_H264} or HEVC
     * @param keyFrame    true when {@code frameInfo.type == 1}
     * @param ptsUs       presentation timestamp in microseconds
     * @param width       coded width
     * @param height      coded height
     */
    void onEncodedVideoFrame(byte[] annexB, int offset, int length, int codec, boolean keyFrame,
                             long ptsUs, int width, int height);
}
