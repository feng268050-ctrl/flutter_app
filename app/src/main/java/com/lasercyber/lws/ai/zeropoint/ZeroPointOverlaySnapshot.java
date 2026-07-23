package com.lasercyber.lws.ai.zeropoint;
import androidx.annotation.NonNull;

/**
 * Zero-point overlay geometry in full-frame image pixels.
 */
public final class ZeroPointOverlaySnapshot {

    public final int frameWidth;
    public final int frameHeight;
    public final double referenceX;
    public final double referenceY;
    public final double offsetX;
    public final double offsetY;
    public final double detectedX;
    public final double detectedY;

    public ZeroPointOverlaySnapshot(int frameWidth,
                                    int frameHeight,
                                    double referenceX,
                                    double referenceY,
                                    double offsetX,
                                    double offsetY) {
        this.frameWidth = frameWidth;
        this.frameHeight = frameHeight;
        this.referenceX = referenceX;
        this.referenceY = referenceY;
        this.offsetX = offsetX;
        this.offsetY = offsetY;
        this.detectedX = referenceX + offsetX;
        this.detectedY = referenceY + offsetY;
    }

    public boolean isValid() {
        return frameWidth > 0 && frameHeight > 0;
    }

    @NonNull
    public String labelText() {
        return String.format("Δ(%.1f, %.1f)", offsetX, offsetY);
    }
}
