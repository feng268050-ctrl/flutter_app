package com.lasercyber.lws.ui.component.home;

import android.content.Context;
import android.content.res.TypedArray;
import android.graphics.drawable.Drawable;
import android.text.TextUtils;
import android.util.AttributeSet;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.frostui.card.interop.FrostCardView;
import com.lasercyber.lws.frostui.button.interop.FrostButtonView;
import com.lasercyber.lws.frostui.button.interop.FrostButtonTileRipple;

/**
 * Home quick-action tile: a {@link FrostCardView} body plus optional caption below.
 * Press ripple reuses {@link FrostButtonTileRipple#createTileRippleForeground(float)}; the card keeps
 * live blur chrome while this container owns click handling and label layout.
 */
public class FrostQuickActionEntry extends LinearLayout {

    private final float cornerRadiusPx;
    private final int labelWidthPx;
    private final int labelMarginTopPx;
    @Nullable
    private final CharSequence labelText;
    private final int labelViewId;
    @Nullable
    private View rippleHost;

    public FrostQuickActionEntry(@NonNull Context context) {
        this(context, null);
    }

    public FrostQuickActionEntry(@NonNull Context context, @Nullable AttributeSet attrs) {
        this(context, attrs, 0);
    }

    public FrostQuickActionEntry(
            @NonNull Context context,
            @Nullable AttributeSet attrs,
            int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        setOrientation(VERTICAL);
        setClickable(true);
        setFocusable(true);

        TypedArray array = context.obtainStyledAttributes(
                attrs, R.styleable.FrostQuickActionEntry, defStyleAttr, 0);
        try {
            labelText = array.getText(R.styleable.FrostQuickActionEntry_quickActionLabel);
            labelViewId = array.getResourceId(
                    R.styleable.FrostQuickActionEntry_quickActionLabelViewId,
                    View.NO_ID);
            labelWidthPx = array.getDimensionPixelSize(
                    R.styleable.FrostQuickActionEntry_quickActionLabelWidth,
                    getResources().getDimensionPixelSize(R.dimen.home_quick_action_label_width));
            labelMarginTopPx = array.getDimensionPixelSize(
                    R.styleable.FrostQuickActionEntry_quickActionLabelMarginTop,
                    getResources().getDimensionPixelSize(R.dimen.home_quick_action_label_margin_top));
            cornerRadiusPx = array.getDimension(
                    R.styleable.FrostQuickActionEntry_quickActionCornerRadius,
                    getResources().getDimension(R.dimen.home_stat_card_corner_radius));
        } finally {
            array.recycle();
        }
    }

    @Override
    protected void onFinishInflate() {
        super.onFinishInflate();
        View card = findQuickActionCard();
        if (card == null) {
            return;
        }

        ViewGroup.LayoutParams cardLayoutParams = card.getLayoutParams();
        removeView(card);

        CardRippleHost host = new CardRippleHost(getContext(), cornerRadiusPx);
        rippleHost = host;
        host.setDuplicateParentStateEnabled(true);
        host.setLayoutParams(copyCardHostLayoutParams(cardLayoutParams));
        host.addView(
                card,
                new FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT));
        addView(host, 0);
        addLabelIfNeeded();
    }

    @Override
    public boolean onTouchEvent(@NonNull MotionEvent event) {
        if (rippleHost != null && event.getActionMasked() == MotionEvent.ACTION_DOWN) {
            updateRippleHotspot(event.getX(), event.getY());
        }
        return super.onTouchEvent(event);
    }

    private void addLabelIfNeeded() {
        if (TextUtils.isEmpty(labelText)) {
            return;
        }

        TextView labelView = new TextView(getContext());
        if (labelViewId != View.NO_ID) {
            labelView.setId(labelViewId);
        }
        labelView.setDuplicateParentStateEnabled(true);
        labelView.setGravity(Gravity.CENTER);
        labelView.setText(labelText);
        labelView.setTextColor(ContextCompat.getColorStateList(
                getContext(), R.color.home_quick_action_label_text));
        labelView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f);

        LayoutParams labelParams = new LayoutParams(labelWidthPx, ViewGroup.LayoutParams.WRAP_CONTENT);
        labelParams.topMargin = labelMarginTopPx;
        labelParams.gravity = Gravity.CENTER_HORIZONTAL;
        addView(labelView, labelParams);
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

    @Nullable
    private View findQuickActionCard() {
        for (int i = 0; i < getChildCount(); i++) {
            View child = getChildAt(i);
            if (child instanceof FrostCardView) {
                return child;
            }
        }
        return null;
    }

    @NonNull
    private LayoutParams copyCardHostLayoutParams(@Nullable ViewGroup.LayoutParams source) {
        if (source instanceof LayoutParams linearParams) {
            return new LayoutParams(linearParams);
        }
        if (source != null) {
            return new LayoutParams(source.width, source.height);
        }
        return new LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT);
    }

    /** Hosts the card and applies the shared tile ripple without affecting card layout. */
    private static final class CardRippleHost extends FrameLayout {

        CardRippleHost(@NonNull Context context, float cornerRadiusPx) {
            super(context);
            setForeground(FrostButtonTileRipple.createTileRippleForeground(cornerRadiusPx));
        }
    }
}
