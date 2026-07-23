package com.lasercyber.lws.ui.component.layout;

import android.content.Context;
import android.content.res.TypedArray;
import android.util.AttributeSet;
import android.view.Gravity;
import android.widget.LinearLayout;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.component.interaction.ClickSoundSupport;

/** List row with symmetric horizontal inset. */
public class InsetListRow extends LinearLayout {
    public InsetListRow(Context context) {
        this(context, null);
    }

    public InsetListRow(Context context, @Nullable AttributeSet attrs) {
        this(context, attrs, 0);
    }

    public InsetListRow(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        setOrientation(HORIZONTAL);
        setGravity(Gravity.CENTER_VERTICAL);

        int defaultInset = getResources().getDimensionPixelSize(R.dimen.inset_list_horizontal_inset);
        int defaultMinHeight = getResources().getDimensionPixelSize(R.dimen.inset_list_row_height);
        int horizontalInset = defaultInset;
        int verticalPadding = 0;
        int minHeight = defaultMinHeight;

        if (attrs != null) {
            TypedArray typedArray = context.obtainStyledAttributes(attrs, R.styleable.InsetListRow);
            horizontalInset = typedArray.getDimensionPixelSize(
                    R.styleable.InsetListRow_horizontalInset, defaultInset);
            verticalPadding = typedArray.getDimensionPixelSize(
                    R.styleable.InsetListRow_rowVerticalPadding, 0);
            if (typedArray.hasValue(R.styleable.InsetListRow_rowMinHeight)) {
                minHeight = typedArray.getDimensionPixelSize(R.styleable.InsetListRow_rowMinHeight, 0);
            }
            typedArray.recycle();
        }

        setPaddingRelative(horizontalInset, verticalPadding, horizontalInset, verticalPadding);
        setMinimumHeight(minHeight);
        ClickSoundSupport.install(this);
    }

    @Override
    public boolean performClick() {
        ClickSoundSupport.play(this);
        return super.performClick();
    }
}
