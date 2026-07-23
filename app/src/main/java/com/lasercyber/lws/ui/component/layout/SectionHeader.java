package com.lasercyber.lws.ui.component.layout;

import android.content.Context;
import android.content.res.TypedArray;
import android.util.AttributeSet;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.annotation.Nullable;
import androidx.appcompat.widget.AppCompatTextView;

import com.lasercyber.lws.ui.R;

/** Section title with a full-width divider below. */
public class SectionHeader extends LinearLayout {
    private final TextView titleView;

    public SectionHeader(Context context) {
        this(context, null);
    }

    public SectionHeader(Context context, @Nullable AttributeSet attrs) {
        this(context, attrs, 0);
    }

    public SectionHeader(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        setOrientation(VERTICAL);

        int dividerSpacing = getResources().getDimensionPixelSize(R.dimen.frost_dialog_content_padding);
        if (attrs != null) {
            TypedArray typedArray = context.obtainStyledAttributes(attrs, R.styleable.SectionHeader);
            dividerSpacing = typedArray.getDimensionPixelSize(
                    R.styleable.SectionHeader_dividerTopSpacing, dividerSpacing);
            typedArray.recycle();
        }

        titleView = new AppCompatTextView(context, attrs, defStyleAttr);
        titleView.setTextColor(getResources().getColor(android.R.color.white, context.getTheme()));
        titleView.setTextSize(24);
        titleView.setSingleLine(true);
        titleView.setIncludeFontPadding(false);
        titleView.setLayoutParams(new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT));
        addView(titleView);

        View dividerView = new View(context);
        dividerView.setBackgroundResource(R.drawable.frost_divider_start_aligned);
        int dividerHeight = getResources().getDimensionPixelSize(R.dimen.section_header_divider_height);
        LayoutParams dividerParams = new LayoutParams(LayoutParams.MATCH_PARENT, dividerHeight);
        dividerParams.topMargin = dividerSpacing;
        dividerView.setLayoutParams(dividerParams);
        addView(dividerView);
    }

    public TextView getTitleView() {
        return titleView;
    }

    public void setTitle(CharSequence title) {
        titleView.setText(title);
    }
}
