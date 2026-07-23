package com.lasercyber.lws.ui.component.layout;

import android.content.Context;
import android.content.res.TypedArray;
import android.util.AttributeSet;
import android.widget.LinearLayout;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.R;

/** Content area below a {@link SectionHeader}. */
public class SectionContent extends LinearLayout {
    public SectionContent(Context context) {
        this(context, null);
    }

    public SectionContent(Context context, @Nullable AttributeSet attrs) {
        this(context, attrs, 0);
    }

    public SectionContent(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        setOrientation(VERTICAL);
        int contentInset = getResources().getDimensionPixelSize(R.dimen.frost_dialog_content_padding);
        if (attrs != null) {
            TypedArray typedArray = context.obtainStyledAttributes(attrs, R.styleable.SectionContent);
            contentInset = typedArray.getDimensionPixelSize(
                    R.styleable.SectionContent_contentTopPadding, contentInset);
            typedArray.recycle();
        }
        setPadding(0, contentInset, 0, 0);
    }
}
