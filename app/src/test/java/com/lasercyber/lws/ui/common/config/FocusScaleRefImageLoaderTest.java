package com.lasercyber.lws.ui.common.config;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotEquals;

import com.lasercyber.lws.ui.R;

import org.junit.Test;

public class FocusScaleRefImageLoaderTest {

    @Test
    public void knownPositiveValueResolvesDrawable() {
        assertEquals(R.drawable.fsr_7, FocusScaleRefImageLoader.drawableIdFor(7));
    }

    @Test
    public void knownNegativeValueResolvesDrawable() {
        assertEquals(R.drawable.fsr_n3, FocusScaleRefImageLoader.drawableIdFor(-3));
    }

    @Test
    public void outOfRangeReturnsZero() {
        assertEquals(0, FocusScaleRefImageLoader.drawableIdFor(99));
        assertEquals(0, FocusScaleRefImageLoader.drawableIdFor(-10));
    }

    @Test
    public void zeroResolvesDrawable() {
        assertNotEquals(0, FocusScaleRefImageLoader.drawableIdFor(0));
        assertEquals(R.drawable.fsr_0, FocusScaleRefImageLoader.drawableIdFor(0));
    }
}
