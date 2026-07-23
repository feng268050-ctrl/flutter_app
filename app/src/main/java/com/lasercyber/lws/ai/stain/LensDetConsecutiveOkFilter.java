package com.lasercyber.lws.ai.stain;
import com.lasercyber.lws.ai.engine.AiManager;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

/**
 * Temporal gate for lens_det: native per-frame ok only counts when part of a run of at least
 * {@link #MIN_CONSECUTIVE_OK_FRAMES} consecutive native-ok samples. Set to 1 for single-frame validity.
 */
public final class LensDetConsecutiveOkFilter {

    /** Matches {@code opencv_stain_detect.min_consecutive_ok_frames} in assets config.yaml. */
    public static final int DEFAULT_MIN_CONSECUTIVE_OK_FRAMES = 1;

    /** Fallback when deployed config is unreadable; prefer {@link AiManager#getMinConsecutiveOkFrames()}. */
    public static final int MIN_CONSECUTIVE_OK_FRAMES = DEFAULT_MIN_CONSECUTIVE_OK_FRAMES;

    private LensDetConsecutiveOkFilter() {
    }

  /**
   * Returns a mask parallel to {@code nativeOk}: true only for indices in a native-ok run of
   * length {@code >= minConsecutive}.
   */
    @NonNull
    public static boolean[] effectiveOkMask(@NonNull boolean[] nativeOk, int minConsecutive) {
        boolean[] mask = new boolean[nativeOk.length];
        if (minConsecutive <= 1) {
            System.arraycopy(nativeOk, 0, mask, 0, nativeOk.length);
            return mask;
        }
        int i = 0;
        while (i < nativeOk.length) {
            if (!nativeOk[i]) {
                i++;
                continue;
            }
            int start = i;
            while (i < nativeOk.length && nativeOk[i]) {
                i++;
            }
            int len = i - start;
            if (len >= minConsecutive) {
                for (int j = start; j < i; j++) {
                    mask[j] = true;
                }
            }
        }
        return mask;
    }

    /** Stateful live gate: returns true once the current streak reaches the frame-kind minimum. */
    public static final class LiveGate {
        private int streak;
        @NonNull
        private String activeKind = "red";

        public void reset() {
            streak = 0;
            activeKind = "red";
        }

        public boolean acceptNativeOk(boolean nativeOk, @Nullable String frameKind, int redMin, int blueMin) {
            final String kind = frameKind == null || frameKind.isEmpty() ? "red" : frameKind;
            if (!kind.equals(activeKind)) {
                streak = 0;
                activeKind = kind;
            }
            if (!nativeOk) {
                streak = 0;
                return false;
            }
            streak++;
            final int min = "blue".equalsIgnoreCase(kind) ? blueMin : redMin;
            return streak >= min;
        }

        /** @deprecated use {@link #acceptNativeOk(boolean, String, int, int)} */
        public boolean acceptNativeOk(boolean nativeOk, int minConsecutive) {
            return acceptNativeOk(nativeOk, "red", minConsecutive, minConsecutive);
        }
    }

    @NonNull
    public static boolean[] effectiveOkMask(@NonNull boolean[] nativeOk, @NonNull int[] minConsecutivePerFrame) {
        boolean[] mask = new boolean[nativeOk.length];
        if (nativeOk.length != minConsecutivePerFrame.length) {
            return mask;
        }
        int i = 0;
        while (i < nativeOk.length) {
            if (!nativeOk[i]) {
                i++;
                continue;
            }
            final int required = Math.max(1, minConsecutivePerFrame[i]);
            int start = i;
            while (i < nativeOk.length && nativeOk[i]) {
                i++;
            }
            final int len = i - start;
            if (len >= required) {
                for (int j = start; j < i; j++) {
                    mask[j] = true;
                }
            }
        }
        return mask;
    }
}
