package com.lasercyber.lws.ui.network.http.local.overlay;

import android.graphics.Bitmap;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

/**
 * Supplies decoded preview frames for HTTP AI compositing (e.g. from AI Vision {@code TextureView}).
 */
public interface CompositorFrameProvider {

    boolean isActive();

    int getFrameWidth();

    int getFrameHeight();

    /**
     * Latest frame for encode; caller must not recycle the bitmap.
     */
    @Nullable
    Bitmap captureFrameForEncode();

    /**
     * When true, the provider's frame already contains all overlays (boxes + status) burned into pixels
     * and the HTTP compositor should not draw a second overlay.
     */
    default boolean isFrameComposited() {
        return false;
    }
}
