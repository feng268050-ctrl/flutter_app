package com.lasercyber.lws.ui.component.home;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.drawable.Animatable;
import android.graphics.drawable.Drawable;
import android.util.AttributeSet;
import android.view.View;

import androidx.annotation.Nullable;
import androidx.appcompat.widget.AppCompatImageView;

/**
 * Home hero WebP layer kept outside {@code BlurTarget} so frost blur sampling does not stop
 * {@link Animatable} playback via offscreen {@code draw()}.
 */
public class HomeBackdropWebPView extends AppCompatImageView {

    public HomeBackdropWebPView(Context context) {
        super(context);
    }

    public HomeBackdropWebPView(Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
    }

    public HomeBackdropWebPView(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
    }

    /** Restarts the animated drawable and schedules the next frame. */
    public void restartAnimation() {
        Drawable drawable = getDrawable();
        if (!(drawable instanceof Animatable animatable)) {
            return;
        }
        animatable.stop();
        drawable.setCallback(this);
        animatable.start();
        invalidate();
    }

    @Override
    protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        restartAnimation();
    }

    @Override
    protected void onVisibilityChanged(View changedView, int visibility) {
        super.onVisibilityChanged(changedView, visibility);
        if (changedView == this && visibility == VISIBLE) {
            restartAnimation();
        }
    }

    @Override
    public void setImageDrawable(@Nullable Drawable drawable) {
        super.setImageDrawable(drawable);
        restartAnimation();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        ensureAnimationRunning();
        super.onDraw(canvas);
    }

    private void ensureAnimationRunning() {
        Drawable drawable = getDrawable();
        if (drawable instanceof Animatable animatable && !animatable.isRunning()) {
            drawable.setCallback(this);
            animatable.start();
        }
    }
}
