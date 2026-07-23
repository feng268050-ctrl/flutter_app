package com.lasercyber.lws.ui.component.machine;

import android.content.Context;
import android.content.res.TypedArray;
import android.util.AttributeSet;
import android.view.ViewGroup;
import android.widget.LinearLayout;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.frostui.card.interop.FrostCardView;

/**
 * Frosted-glass gauge card shared by Monitor machine status and quick-mode more-monitor dialog.
 */
public class MachineStatusGaugeCard extends FrostCardView {

    @NonNull
    private MachineStatusChrome chrome;
    @NonNull
    private MachineStatusChrome.Variant variant = MachineStatusChrome.Variant.MONITOR;
    private int gaugeWidthPx;
    private int gaugeHeightPx;

    public MachineStatusGaugeCard(@NonNull Context context) {
        this(context, null);
    }

    public MachineStatusGaugeCard(@NonNull Context context, @Nullable AttributeSet attrs) {
        this(context, attrs, 0);
    }

    public MachineStatusGaugeCard(
            @NonNull Context context,
            @Nullable AttributeSet attrs,
            int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        chrome = MachineStatusChrome.of(context, MachineStatusChrome.Variant.MONITOR);
        gaugeWidthPx = chrome.gaugeWidthPx;
        gaugeHeightPx = chrome.gaugeHeightPx;
        readAttrs(context, attrs);
        applyChrome();
    }

    @Override
    protected void onFinishInflate() {
        super.onFinishInflate();
        applyLayoutDimensions();
        applyLiveMonitorClipPolicy();
    }

    private void readAttrs(@NonNull Context context, @Nullable AttributeSet attrs) {
        if (attrs == null) {
            return;
        }
        TypedArray array = context.obtainStyledAttributes(attrs, R.styleable.MachineStatusGaugeCard);
        try {
            int variantIndex = array.getInt(
                    R.styleable.MachineStatusGaugeCard_machineStatusVariant,
                    MachineStatusChrome.Variant.MONITOR.ordinal());
            if (variantIndex == MachineStatusChrome.Variant.DIALOG.ordinal()) {
                variant = MachineStatusChrome.Variant.DIALOG;
            } else if (variantIndex == MachineStatusChrome.Variant.LIVE_MONITOR.ordinal()) {
                variant = MachineStatusChrome.Variant.LIVE_MONITOR;
            } else {
                variant = MachineStatusChrome.Variant.MONITOR;
            }
            chrome = MachineStatusChrome.of(context, variant);
            gaugeWidthPx = chrome.gaugeWidthPx;
            gaugeHeightPx = chrome.gaugeHeightPx;
            if (array.hasValue(R.styleable.MachineStatusGaugeCard_machineStatusGaugeWidth)) {
                gaugeWidthPx = array.getDimensionPixelSize(
                        R.styleable.MachineStatusGaugeCard_machineStatusGaugeWidth,
                        gaugeWidthPx);
            }
            if (array.hasValue(R.styleable.MachineStatusGaugeCard_machineStatusGaugeHeight)) {
                gaugeHeightPx = array.getDimensionPixelSize(
                        R.styleable.MachineStatusGaugeCard_machineStatusGaugeHeight,
                        gaugeHeightPx);
            }
        } finally {
            array.recycle();
        }
    }

    private void applyChrome() {
        if (!isBlurTintExplicit()) {
            setBlurTint(chrome.blurTint);
        }
        if (!isBlurIntensityExplicit()) {
            setBlurIntensity(chrome.blurIntensity);
        }
        setPadding(
                chrome.gaugePaddingLeftPx,
                chrome.gaugePaddingTopPx,
                chrome.gaugePaddingRightPx,
                chrome.gaugePaddingBottomPx);
        setContentGravity(chrome.gaugeGravity);
        setContentOrientation(LinearLayout.VERTICAL);
        applyLiveMonitorClipPolicy();
        applyLayoutDimensions();
    }

    /** Live Monitor 外层 panel 已有圆角底；卡片不裁切，避免外侧刻度数字被 clip */
    private void applyLiveMonitorClipPolicy() {
        if (variant != MachineStatusChrome.Variant.LIVE_MONITOR) {
            return;
        }
        setClipChildren(false);
        setClipToPadding(false);
        setClipToOutline(false);
    }

    private void applyLayoutDimensions() {
        ViewGroup.LayoutParams params = getLayoutParams();
        if (params == null) {
            params = new ViewGroup.LayoutParams(gaugeWidthPx, gaugeHeightPx);
        } else {
            params.width = gaugeWidthPx;
            params.height = gaugeHeightPx;
        }
        setLayoutParams(params);
    }
}
