package com.lasercyber.lws.ui.component.layout;

import android.content.Context;
import android.content.res.TypedArray;
import android.util.AttributeSet;
import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.R;

/** Horizontal divider aligned with {@link InsetListRow} content insets. */
public class InsetDivider extends View {
    private int insetStart;
    private int insetEnd;

    public InsetDivider(Context context) {
        this(context, null);
    }

    public InsetDivider(Context context, @Nullable AttributeSet attrs) {
        this(context, attrs, 0);
    }

    public InsetDivider(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        int defaultInset = getResources().getDimensionPixelSize(R.dimen.inset_list_horizontal_inset);
        TypedArray typedArray = context.obtainStyledAttributes(attrs, R.styleable.InsetDivider);
        if (typedArray.hasValue(R.styleable.InsetDivider_dividerInset)) {
            int inset = typedArray.getDimensionPixelSize(R.styleable.InsetDivider_dividerInset, defaultInset);
            insetStart = inset;
            insetEnd = inset;
        } else {
            insetStart = typedArray.getDimensionPixelSize(
                    R.styleable.InsetDivider_dividerInsetStart, defaultInset);
            insetEnd = typedArray.getDimensionPixelSize(
                    R.styleable.InsetDivider_dividerInsetEnd, defaultInset);
        }
        typedArray.recycle();
        setBackgroundColor(getResources().getColor(R.color.inset_divider_color, context.getTheme()));
    }

    @Override
    protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        applyLayoutParams();
    }

    public void setInsets(int start, int end) {
        insetStart = start;
        insetEnd = end;
        applyLayoutParams();
    }

    private void applyLayoutParams() {
        ViewGroup.LayoutParams params = getLayoutParams();
        if (params == null) {
            params = new ViewGroup.MarginLayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    getResources().getDimensionPixelSize(R.dimen.inset_divider_height));
        }
        if (params instanceof ViewGroup.MarginLayoutParams marginLayoutParams) {
            marginLayoutParams.width = ViewGroup.LayoutParams.MATCH_PARENT;
            marginLayoutParams.height = getResources().getDimensionPixelSize(R.dimen.inset_divider_height);
            marginLayoutParams.setMarginStart(insetStart);
            marginLayoutParams.setMarginEnd(insetEnd);
            setLayoutParams(marginLayoutParams);
        }
    }
}
