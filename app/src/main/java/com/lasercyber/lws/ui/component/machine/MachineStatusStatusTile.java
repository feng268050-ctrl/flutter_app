package com.lasercyber.lws.ui.component.machine;

import android.content.Context;
import android.content.res.TypedArray;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.util.AttributeSet;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.annotation.ColorInt;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.StringRes;
import androidx.core.content.ContextCompat;
import androidx.core.widget.TextViewCompat;

import com.lasercyber.lws.frostui.border.FrostBlurIntensity;
import com.lasercyber.lws.frostui.control.FrostStatusState;
import com.lasercyber.lws.frostui.card.interop.FrostCardView;
import com.lasercyber.lws.ui.R;

/**
 * Label status tile shared by Monitor machine status and Live Monitor overlay.
 * Active / success state tints the whole {@link FrostCardView}; no separate indicator glyph.
 */
public class MachineStatusStatusTile extends FrostCardView {

    private final TextView labelView;

    @NonNull
    private MachineStatusChrome chrome;
    @NonNull
    private MachineStatusChrome.Variant variant = MachineStatusChrome.Variant.MONITOR;
    private int tileWidthPx;
    private int tileHeightPx;
    @ColorInt
    private int labelTextColor;
    private float labelTextSizePx;
    @NonNull
    private FrostStatusState statusState = FrostStatusState.Idle;

    public MachineStatusStatusTile(@NonNull Context context) {
        this(context, null);
    }

    public MachineStatusStatusTile(@NonNull Context context, @Nullable AttributeSet attrs) {
        this(context, attrs, 0);
    }

    public MachineStatusStatusTile(
            @NonNull Context context,
            @Nullable AttributeSet attrs,
            int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        chrome = MachineStatusChrome.of(context, MachineStatusChrome.Variant.MONITOR);
        tileWidthPx = chrome.tileWidthPx;
        tileHeightPx = chrome.tileHeightPx;
        labelTextColor = chrome.labelTextColor;
        labelTextSizePx = chrome.labelTextSizePx;

        labelView = new TextView(context);
        LinearLayout.LayoutParams labelParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT);
        labelView.setLayoutParams(labelParams);
        labelView.setMaxLines(2);
        labelView.setIncludeFontPadding(true);
        labelView.setGravity(Gravity.CENTER);
        addView(labelView);

        readAttrs(context, attrs);
        applyChrome();
        applyStatusAppearance();
    }

    @Override
    protected void onFinishInflate() {
        super.onFinishInflate();
        applyLayoutDimensions();
    }

    private void readAttrs(@NonNull Context context, @Nullable AttributeSet attrs) {
        if (attrs == null) {
            return;
        }
        TypedArray array = context.obtainStyledAttributes(attrs, R.styleable.MachineStatusStatusTile);
        try {
            int variantIndex = array.getInt(
                    R.styleable.MachineStatusStatusTile_machineStatusVariant,
                    MachineStatusChrome.Variant.MONITOR.ordinal());
            if (variantIndex == MachineStatusChrome.Variant.DIALOG.ordinal()) {
                variant = MachineStatusChrome.Variant.DIALOG;
            } else if (variantIndex == MachineStatusChrome.Variant.LIVE_MONITOR.ordinal()) {
                variant = MachineStatusChrome.Variant.LIVE_MONITOR;
            } else {
                variant = MachineStatusChrome.Variant.MONITOR;
            }
            chrome = MachineStatusChrome.of(context, variant);
            tileWidthPx = chrome.tileWidthPx;
            tileHeightPx = chrome.tileHeightPx;
            labelTextColor = chrome.labelTextColor;
            labelTextSizePx = chrome.labelTextSizePx;

            if (array.hasValue(R.styleable.MachineStatusStatusTile_machineStatusTileWidth)) {
                tileWidthPx = array.getDimensionPixelSize(
                        R.styleable.MachineStatusStatusTile_machineStatusTileWidth,
                        tileWidthPx);
            }
            if (array.hasValue(R.styleable.MachineStatusStatusTile_machineStatusTileHeight)) {
                tileHeightPx = array.getDimensionPixelSize(
                        R.styleable.MachineStatusStatusTile_machineStatusTileHeight,
                        tileHeightPx);
            }
            if (array.hasValue(R.styleable.MachineStatusStatusTile_machineStatusLabelTextColor)) {
                labelTextColor = array.getColor(
                        R.styleable.MachineStatusStatusTile_machineStatusLabelTextColor,
                        labelTextColor);
            }
            if (array.hasValue(R.styleable.MachineStatusStatusTile_machineStatusLabelTextSize)) {
                labelTextSizePx = array.getDimension(
                        R.styleable.MachineStatusStatusTile_machineStatusLabelTextSize,
                        labelTextSizePx);
            }
            CharSequence labelText = array.getText(R.styleable.MachineStatusStatusTile_labelText);
            if (labelText != null) {
                labelView.setText(labelText);
            }
            boolean checked = array.getBoolean(R.styleable.MachineStatusStatusTile_android_checked, false);
            statusState = checked ? FrostStatusState.Success : FrostStatusState.Idle;
        } finally {
            array.recycle();
        }
    }

    private void applyChrome() {
        if (!isBlurTintExplicit()) {
            setBlurTint(chrome.blurTint);
        }
        if (!isBlurIntensityExplicit()) {
            // Border chrome only; fill comes from status tint background.
            setBlurIntensity(FrostBlurIntensity.TRANSPARENT);
        }
        setDrawFill(false);
        setContentOrientation(LinearLayout.HORIZONTAL);
        setContentGravity(Gravity.CENTER);
        int verticalPadding = chrome.tilePaddingTopPx > 0 ? chrome.tilePaddingTopPx : 0;
        int bottomPadding = chrome.tilePaddingBottomPx > 0 ? chrome.tilePaddingBottomPx : verticalPadding;
        setPadding(
                chrome.tilePaddingHorizontalPx,
                verticalPadding,
                chrome.tilePaddingHorizontalPx,
                bottomPadding);

        labelView.setTextColor(labelTextColor);
        labelView.setTextSize(TypedValue.COMPLEX_UNIT_PX, labelTextSizePx);
        if (variant == MachineStatusChrome.Variant.LIVE_MONITOR) {
            // 一行六枚：单行文字，自动缩小以适配均分宽度
            labelView.setMaxLines(1);
            labelView.setSingleLine(true);
            TextViewCompat.setAutoSizeTextTypeUniformWithConfiguration(
                    labelView,
                    10,
                    Math.max(10, Math.round(labelTextSizePx / getResources().getDisplayMetrics().scaledDensity)),
                    1,
                    TypedValue.COMPLEX_UNIT_SP);
        } else {
            labelView.setMaxLines(2);
            labelView.setSingleLine(false);
            int maxLabelTextSizeSp = Math.max(
                    10,
                    Math.round(labelTextSizePx / getResources().getDisplayMetrics().scaledDensity));
            TextViewCompat.setAutoSizeTextTypeUniformWithConfiguration(
                    labelView,
                    10,
                    maxLabelTextSizeSp,
                    1,
                    TypedValue.COMPLEX_UNIT_SP);
        }

        applyLayoutDimensions();
    }

    private void applyLayoutDimensions() {
        ViewGroup.LayoutParams params = getLayoutParams();
        if (variant == MachineStatusChrome.Variant.LIVE_MONITOR) {
            // 与同排兄弟均分宽度，避免固定 140dp×6 溢出裁切
            LinearLayout.LayoutParams lp;
            if (params instanceof LinearLayout.LayoutParams existing) {
                lp = existing;
            } else {
                lp = new LinearLayout.LayoutParams(0, tileHeightPx, 1f);
            }
            lp.width = 0;
            lp.height = tileHeightPx;
            lp.weight = 1f;
            int gap = getResources().getDimensionPixelSize(R.dimen.laser_live_monitor_tile_gap) / 2;
            lp.setMarginStart(gap);
            lp.setMarginEnd(gap);
            setLayoutParams(lp);
            return;
        }
        if (params == null) {
            params = new ViewGroup.LayoutParams(tileWidthPx, tileHeightPx);
        } else {
            params.width = tileWidthPx;
            params.height = tileHeightPx;
        }
        setLayoutParams(params);
    }

    public void setLabelText(@Nullable CharSequence text) {
        labelView.setText(text);
    }

    public void setLabelText(@StringRes int textResId) {
        labelView.setText(textResId);
    }

    public void setIndicatorState(@NonNull FrostStatusState state) {
        if (statusState == state) {
            return;
        }
        statusState = state;
        applyStatusAppearance();
    }

    @NonNull
    public FrostStatusState getIndicatorState() {
        return statusState;
    }

    private void applyStatusAppearance() {
        @ColorInt int fill = resolveStatusFillColor(statusState);
        if (fill == Color.TRANSPARENT) {
            labelView.setBackground(null);
        } else {
            float radius = getResources().getDimension(R.dimen.frost_corner_radius);
            GradientDrawable background = new GradientDrawable();
            background.setShape(GradientDrawable.RECTANGLE);
            background.setCornerRadius(radius);
            background.setColor(fill);
            // Tint the label host — FrostCardView clears View#setBackground for outline clipping.
            labelView.setBackground(background);
        }
        // 通过/失败等状态只改背景，字体保持白色
        labelView.setTextColor(ContextCompat.getColor(getContext(), R.color.white));
    }

    private boolean isLiveMonitorChrome() {
        if (variant == MachineStatusChrome.Variant.LIVE_MONITOR) {
            return true;
        }
        // Fallback: style may set layout size without resolving custom enum on some inflate paths
        int liveW = getResources().getDimensionPixelSize(R.dimen.laser_live_monitor_tile_width);
        int liveH = getResources().getDimensionPixelSize(R.dimen.laser_live_monitor_tile_height);
        return tileWidthPx == liveW && tileHeightPx == liveH;
    }

    @ColorInt
    private int resolveStatusFillColor(@NonNull FrostStatusState state) {
        return switch (state) {
            case Success -> isLiveMonitorChrome()
                    ? ContextCompat.getColor(getContext(), R.color.machine_status_tile_live_success_fill)
                    : ContextCompat.getColor(getContext(), R.color.machine_status_tile_success_fill);
            case Failure -> ContextCompat.getColor(getContext(), R.color.machine_status_tile_failure_fill);
            case InProgress -> ContextCompat.getColor(getContext(), R.color.machine_status_tile_progress_fill);
            // Live Monitor idle: same as video/page background (no #99000000 wash)
            case Idle -> isLiveMonitorChrome()
                    ? Color.TRANSPARENT
                    : ContextCompat.getColor(getContext(), R.color.machine_status_tile_idle_fill);
        };
    }
}
