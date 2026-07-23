package com.lasercyber.lws.ui.component;

import android.content.Context;
import android.util.AttributeSet;
import android.view.MotionEvent;
import android.widget.ScrollView;

/**
 * App-wide scroll container. Scrollbars stay hidden until the user scrolls, then fade
 * normally. After scrolling stops, layout-driven {@link #awakenScrollBars(int, boolean)}
 * calls are ignored so a sibling re-layout does not flash the thumb back on.
 */
public class AppScrollView extends ScrollView {

    private static final int SCROLLBAR_SUPPRESS_AFTER_IDLE_MS = 800;

    private boolean userScrolled;
    private boolean suppressLayoutScrollbarAwake;

    private final Runnable enableLayoutScrollbarSuppress =
            () -> suppressLayoutScrollbarAwake = true;

    public AppScrollView(Context context) {
        super(context);
    }

    public AppScrollView(Context context, AttributeSet attrs) {
        super(context, attrs);
    }

    public AppScrollView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
    }

    public AppScrollView(Context context, AttributeSet attrs, int defStyleAttr, int defStyleRes) {
        super(context, attrs, defStyleAttr, defStyleRes);
    }

    private void onUserScrollActivity() {
        suppressLayoutScrollbarAwake = false;
        removeCallbacks(enableLayoutScrollbarSuppress);
        postDelayed(enableLayoutScrollbarSuppress, SCROLLBAR_SUPPRESS_AFTER_IDLE_MS);
    }

    @Override
    public boolean onTouchEvent(MotionEvent ev) {
        switch (ev.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
            case MotionEvent.ACTION_MOVE:
                onUserScrollActivity();
                break;
            default:
                break;
        }
        return super.onTouchEvent(ev);
    }

    @Override
    protected void onScrollChanged(int l, int t, int oldl, int oldt) {
        super.onScrollChanged(l, t, oldl, oldt);
        if (t != oldt) {
            userScrolled = true;
            onUserScrollActivity();
        }
    }

    @Override
    protected boolean awakenScrollBars(int startDelay, boolean invalidate) {
        if (!userScrolled) {
            return false;
        }
        if (suppressLayoutScrollbarAwake) {
            return false;
        }
        return super.awakenScrollBars(startDelay, invalidate);
    }
}
