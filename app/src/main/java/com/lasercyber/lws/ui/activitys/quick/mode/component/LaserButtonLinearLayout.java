package com.lasercyber.lws.ui.activitys.quick.mode.component;

import android.content.Context;
import android.util.AttributeSet;
import android.view.View;
import android.widget.FrameLayout;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.R;

/**
 * 出光按钮容器：内容层 + 梯形 ripple 顶层 overlay。
 */
public class LaserButtonLinearLayout extends FrameLayout {

    @Nullable
    private View rippleOverlay;

    public LaserButtonLinearLayout(@NonNull Context context) {
        super(context);
    }

    public LaserButtonLinearLayout(@NonNull Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
    }

    public LaserButtonLinearLayout(@NonNull Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
    }

    public LaserButtonLinearLayout(@NonNull Context context, @Nullable AttributeSet attrs, int defStyleAttr, int defStyleRes) {
        super(context, attrs, defStyleAttr, defStyleRes);
    }

    @Override
    protected void onFinishInflate() {
        super.onFinishInflate();
        rippleOverlay = findViewById(R.id.laser_button_ripple_overlay);
        if (rippleOverlay == null) {
            rippleOverlay = new LaserButtonTrapezoidRippleOverlay(getContext());
            rippleOverlay.setId(R.id.laser_button_ripple_overlay);
            addView(rippleOverlay, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));
        }
    }

    @NonNull
    public View getRippleOverlay() {
        if (rippleOverlay == null) {
            rippleOverlay = findViewById(R.id.laser_button_ripple_overlay);
        }
        if (rippleOverlay == null) {
            throw new IllegalStateException("Laser button ripple overlay is missing");
        }
        return rippleOverlay;
    }

    public boolean isPointInTrapezoid(float x, float y) {
        if (getWidth() == 0 || getHeight() == 0) {
            return false;
        }
        return LaserButtonTrapezoidGeometry.contains(x, y, getWidth(), getHeight());
    }

    @Override
    public void setEnabled(boolean enabled) {
        super.setEnabled(enabled);
        if (rippleOverlay != null) {
            rippleOverlay.setEnabled(enabled);
        }
    }
}
