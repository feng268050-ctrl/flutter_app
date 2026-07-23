package com.lasercyber.lws.ui.component.machine;

import android.content.Context;
import android.content.res.Resources;
import android.graphics.Color;
import android.view.Gravity;

import androidx.annotation.ColorInt;
import androidx.annotation.NonNull;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.frostui.border.FrostBlurIntensity;
import com.lasercyber.lws.frostui.border.FrostBlurTint;

/**
 * Shared layout chrome for machine-status gauges and status tiles (Monitor vs quick-mode dialog).
 */
public final class MachineStatusChrome {

    public enum Variant {
        MONITOR,
        DIALOG,
        LIVE_MONITOR
    }

    public final int gaugeWidthPx;
    public final int gaugeHeightPx;
    public final int gaugePaddingLeftPx;
    public final int gaugePaddingTopPx;
    public final int gaugePaddingRightPx;
    public final int gaugePaddingBottomPx;
    public final int gaugeGravity;

    public final int tileWidthPx;
    public final int tileHeightPx;
    public final int tilePaddingHorizontalPx;
    public final int tilePaddingTopPx;
    public final int tilePaddingBottomPx;
    @ColorInt
    public final int labelTextColor;
    public final float labelTextSizePx;
    @NonNull
    public final FrostBlurTint blurTint;
    @NonNull
    public final FrostBlurIntensity blurIntensity;

    private MachineStatusChrome(
            int gaugeWidthPx,
            int gaugeHeightPx,
            int gaugePaddingLeftPx,
            int gaugePaddingTopPx,
            int gaugePaddingRightPx,
            int gaugePaddingBottomPx,
            int gaugeGravity,
            int tileWidthPx,
            int tileHeightPx,
            int tilePaddingHorizontalPx,
            int tilePaddingTopPx,
            int tilePaddingBottomPx,
            @ColorInt int labelTextColor,
            float labelTextSizePx,
            @NonNull FrostBlurTint blurTint,
            @NonNull FrostBlurIntensity blurIntensity) {
        this.gaugeWidthPx = gaugeWidthPx;
        this.gaugeHeightPx = gaugeHeightPx;
        this.gaugePaddingLeftPx = gaugePaddingLeftPx;
        this.gaugePaddingTopPx = gaugePaddingTopPx;
        this.gaugePaddingRightPx = gaugePaddingRightPx;
        this.gaugePaddingBottomPx = gaugePaddingBottomPx;
        this.gaugeGravity = gaugeGravity;
        this.tileWidthPx = tileWidthPx;
        this.tileHeightPx = tileHeightPx;
        this.tilePaddingHorizontalPx = tilePaddingHorizontalPx;
        this.tilePaddingTopPx = tilePaddingTopPx;
        this.tilePaddingBottomPx = tilePaddingBottomPx;
        this.labelTextColor = labelTextColor;
        this.labelTextSizePx = labelTextSizePx;
        this.blurTint = blurTint;
        this.blurIntensity = blurIntensity;
    }

    @NonNull
    public static MachineStatusChrome of(@NonNull Context context, @NonNull Variant variant) {
        Resources resources = context.getResources();
        int contentPadding = resources.getDimensionPixelSize(R.dimen.frost_dialog_content_padding);
        if (variant == Variant.LIVE_MONITOR) {
            // 外层 panel 已有 padding/圆角底；卡片本身不再内缩，避免四位刻度数字被裁切
            return new MachineStatusChrome(
                    dimen(resources, R.dimen.laser_live_monitor_gauge_width),
                    dimen(resources, R.dimen.laser_live_monitor_gauge_height),
                    0,
                    0,
                    0,
                    0,
                    Gravity.CENTER,
                    dimen(resources, R.dimen.laser_live_monitor_tile_width),
                    dimen(resources, R.dimen.laser_live_monitor_tile_height),
                    // 上下左右统一 2dp 内边距
                    dp(resources, 2),
                    dp(resources, 2),
                    dp(resources, 2),
                    Color.WHITE,
                    resources.getDimension(R.dimen.text_size_14),
                    FrostBlurTint.DARK,
                    FrostBlurIntensity.TRANSPARENT);
        }
        if (variant == Variant.MONITOR) {
            return new MachineStatusChrome(
                    dimen(resources, R.dimen.machine_status_monitor_gauge_width),
                    dimen(resources, R.dimen.machine_status_monitor_gauge_height),
                    dp(resources, 10),
                    dp(resources, 18),
                    dp(resources, 10),
                    dp(resources, 8),
                    Gravity.CENTER,
                    dimen(resources, R.dimen.machine_status_monitor_tile_width),
                    dimen(resources, R.dimen.machine_status_monitor_tile_height),
                    contentPadding,
                    0,
                    0,
                    Color.WHITE,
                    resources.getDimension(R.dimen.text_size_16),
                    FrostBlurTint.DARK,
                    FrostBlurIntensity.TRANSPARENT);
        }
        return new MachineStatusChrome(
                dimen(resources, R.dimen.machine_status_dialog_gauge_width),
                dimen(resources, R.dimen.machine_status_dialog_gauge_height),
                dp(resources, 110),
                dp(resources, 24),
                dp(resources, 110),
                dp(resources, 18),
                Gravity.CENTER_HORIZONTAL | Gravity.TOP,
                dimen(resources, R.dimen.machine_status_dialog_tile_width),
                dimen(resources, R.dimen.machine_status_dialog_tile_height),
                contentPadding,
                dp(resources, 14),
                dp(resources, 14),
                resources.getColor(R.color.text_black, context.getTheme()),
                resources.getDimension(R.dimen.text_size_16),
                FrostBlurTint.DARK,
                FrostBlurIntensity.TRANSPARENT);
    }

    private static int dimen(@NonNull Resources resources, int resId) {
        return resources.getDimensionPixelSize(resId);
    }

    private static int dp(@NonNull Resources resources, int dp) {
        return (int) (dp * resources.getDisplayMetrics().density + 0.5f);
    }
}
