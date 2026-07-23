package com.lasercyber.lws.ui.component;

import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.RippleDrawable;
import android.view.View;

import androidx.annotation.ColorInt;
import androidx.annotation.DimenRes;
import androidx.annotation.NonNull;

import com.lasercyber.lws.ui.R;

/**
 * Applies position-aware rounded selection backgrounds for list rows inside a rounded container.
 */
public final class ListSelectionBackgroundUtils {

    private ListSelectionBackgroundUtils() {
    }

    public static void apply(
            @NonNull View row,
            int position,
            int itemCount,
            boolean selected,
            @ColorInt int selectedBackgroundColor,
            @DimenRes int cornerRadiusDimen) {
        if (!selected) {
            row.setBackgroundColor(Color.TRANSPARENT);
            return;
        }
        float cornerRadius = row.getResources().getDimension(cornerRadiusDimen);
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(selectedBackgroundColor);
        drawable.setCornerRadii(cornerRadiiForPosition(position, itemCount, cornerRadius));
        row.setBackground(drawable);
    }

    /** Uniform rounded pill for a single list row (popup menu selection). */
    public static void applyUniform(
            @NonNull View row,
            boolean selected,
            @ColorInt int selectedBackgroundColor,
            @DimenRes int cornerRadiusDimen) {
        if (!selected) {
            row.setBackgroundColor(Color.TRANSPARENT);
            return;
        }
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(selectedBackgroundColor);
        drawable.setCornerRadius(row.getResources().getDimension(cornerRadiusDimen));
        row.setBackground(drawable);
    }

    /** Press ripple aligned to row position inside a rounded FrostedGlass list card. */
    public static void applyPressRipple(
            @NonNull View row,
            int position,
            int itemCount,
            @DimenRes int cornerRadiusDimen) {
        float cornerRadius = row.getResources().getDimension(cornerRadiusDimen);
        ColorStateList rippleColor = ColorStateList.valueOf(Color.argb(0x3D, 255, 255, 255));
        GradientDrawable mask = new GradientDrawable();
        mask.setShape(GradientDrawable.RECTANGLE);
        mask.setColor(Color.WHITE);
        mask.setCornerRadii(cornerRadiiForPosition(position, itemCount, cornerRadius));
        row.setForeground(new RippleDrawable(rippleColor, null, mask));
    }

    public static float[] cornerRadiiForPosition(int position, int itemCount, float cornerRadius) {
        float[] radii = new float[8];
        boolean first = position == 0;
        boolean last = position == itemCount - 1;
        boolean single = itemCount == 1;
        if (single || first) {
            radii[0] = cornerRadius;
            radii[1] = cornerRadius;
            radii[2] = cornerRadius;
            radii[3] = cornerRadius;
        }
        if (single || last) {
            radii[4] = cornerRadius;
            radii[5] = cornerRadius;
            radii[6] = cornerRadius;
            radii[7] = cornerRadius;
        }
        return radii;
    }
}
