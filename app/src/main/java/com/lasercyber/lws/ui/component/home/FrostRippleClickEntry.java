package com.lasercyber.lws.ui.component.home;

import android.content.Context;
import android.content.res.TypedArray;
import android.graphics.Rect;
import android.graphics.drawable.Drawable;
import android.util.AttributeSet;
import android.view.MotionEvent;
import android.view.View;
import android.widget.FrameLayout;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.frostui.button.interop.FrostButtonTileRipple;

/**
 * Home mode entry (fast / engineer tiles) with press ripple aligned to a decorative target view.
 * Ripple uses {@link FrostButtonTileRipple#createTileRippleForeground(float)}.
 */
public class FrostRippleClickEntry extends FrameLayout {

    private final float cornerRadiusPx;
    private final int rippleTargetId;
    @Nullable
    private View rippleHost;
    @Nullable
    private View rippleTargetView;

    public FrostRippleClickEntry(@NonNull Context context) {
        this(context, null);
    }

    public FrostRippleClickEntry(@NonNull Context context, @Nullable AttributeSet attrs) {
        this(context, attrs, 0);
    }

    public FrostRippleClickEntry(
            @NonNull Context context,
            @Nullable AttributeSet attrs,
            int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        setClickable(true);
        setFocusable(true);

        TypedArray array = context.obtainStyledAttributes(
                attrs, R.styleable.FrostRippleClickEntry, defStyleAttr, 0);
        try {
            cornerRadiusPx = array.getDimension(
                    R.styleable.FrostRippleClickEntry_rippleCornerRadius,
                    getResources().getDimension(R.dimen.home_stat_card_corner_radius));
            rippleTargetId = array.getResourceId(
                    R.styleable.FrostRippleClickEntry_rippleTarget,
                    View.NO_ID);
        } finally {
            array.recycle();
        }
    }

    @Override
    protected void onFinishInflate() {
        super.onFinishInflate();
        TargetRippleHost host = new TargetRippleHost(getContext(), cornerRadiusPx);
        host.setDuplicateParentStateEnabled(true);
        host.setClickable(false);
        host.setFocusable(false);
        rippleHost = host;
        addView(host, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));
    }

    @Override
    protected void onLayout(boolean changed, int left, int top, int right, int bottom) {
        super.onLayout(changed, left, top, right, bottom);
        layoutRippleHost();
    }

    private void resolveRippleTargetIfNeeded() {
        if (rippleTargetView != null || rippleTargetId == View.NO_ID) {
            return;
        }
        rippleTargetView = getRootView().findViewById(rippleTargetId);
    }

    private void layoutRippleHost() {
        if (rippleHost == null) {
            return;
        }

        resolveRippleTargetIfNeeded();
        if (rippleTargetView == null) {
            rippleHost.layout(0, 0, 0, 0);
            return;
        }

        Rect rippleBounds = computeRippleBoundsInEntry(rippleTargetView);
        if (rippleBounds.isEmpty()) {
            rippleHost.layout(0, 0, 0, 0);
            return;
        }
        rippleHost.layout(
                rippleBounds.left,
                rippleBounds.top,
                rippleBounds.right,
                rippleBounds.bottom);
    }

    @NonNull
    private Rect computeRippleBoundsInEntry(@NonNull View frameView) {
        int frameWidth = frameView.getWidth();
        int frameHeight = frameView.getHeight();
        if (frameWidth <= 0 || frameHeight <= 0) {
            return new Rect();
        }

        Rect mapped = mapRectToEntry(frameView, new Rect(0, 0, frameWidth, frameHeight));
        Rect entryBounds = new Rect(0, 0, getWidth(), getHeight());
        Rect intersection = new Rect();
        if (!intersection.setIntersect(mapped, entryBounds)) {
            return new Rect();
        }
        return intersection;
    }

    @NonNull
    private Rect mapRectToEntry(@NonNull View sourceView, @NonNull Rect sourceLocalRect) {
        int[] sourceLoc = new int[2];
        int[] entryLoc = new int[2];
        sourceView.getLocationOnScreen(sourceLoc);
        getLocationOnScreen(entryLoc);
        int deltaX = sourceLoc[0] - entryLoc[0];
        int deltaY = sourceLoc[1] - entryLoc[1];
        return new Rect(
                sourceLocalRect.left + deltaX,
                sourceLocalRect.top + deltaY,
                sourceLocalRect.right + deltaX,
                sourceLocalRect.bottom + deltaY);
    }

    @Override
    public boolean onTouchEvent(@NonNull MotionEvent event) {
        if (rippleHost != null && event.getActionMasked() == MotionEvent.ACTION_DOWN) {
            updateRippleHotspot(event.getX(), event.getY());
        }
        return super.onTouchEvent(event);
    }

    private void updateRippleHotspot(float entryX, float entryY) {
        if (rippleHost == null) {
            return;
        }
        Drawable foreground = rippleHost.getForeground();
        if (foreground == null) {
            return;
        }
        foreground.setHotspot(
                entryX - rippleHost.getLeft(),
                entryY - rippleHost.getTop());
    }

    /** Hosts tile ripple clipped to the mapped target bounds. */
    private static final class TargetRippleHost extends FrameLayout {

        TargetRippleHost(@NonNull Context context, float cornerRadiusPx) {
            super(context);
            setForeground(FrostButtonTileRipple.createTileRippleForeground(cornerRadiusPx));
        }
    }
}
