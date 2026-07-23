package com.lasercyber.lws.ui.activitys.engineer.mode.ui;

import android.content.Context;

import androidx.annotation.ColorInt;
import androidx.annotation.ColorRes;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;
import androidx.core.graphics.ColorUtils;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.constant.ModelConstant;

/**
 * Resolves engineer-mode accent colors from the active process model
 * (same grouping as {@code engineer_tab.xml} and camera record button visuals).
 */
public final class EngineerModelThemeColors {

    /** Matches {@code engineer_popup_item_selected_bg} alpha (#33). */
    private static final int POPUP_SELECTED_BG_ALPHA = 0x33;

    private EngineerModelThemeColors() {
    }

    @ColorRes
    public static int resolveTabActiveColorRes(@Nullable Integer modelType) {
        int type = modelType != null ? modelType : ModelConstant.CONTINUOUS_WELDING;
        if (type == ModelConstant.WELD_CLEAN || type == ModelConstant.WIDTH_CLEAN) {
            return R.color.engineer_wash_tab_active;
        }
        if (type == ModelConstant.HAND_CUT) {
            return R.color.engineer_cut_tab_active;
        }
        return R.color.engineer_weld_tab_active;
    }

    @ColorInt
    public static int resolveTabActiveColor(@NonNull Context context, @Nullable Integer modelType) {
        return ContextCompat.getColor(context, resolveTabActiveColorRes(modelType));
    }

    @ColorInt
    public static int resolvePopupSelectedBackgroundColor(
            @NonNull Context context,
            @Nullable Integer modelType) {
        return ColorUtils.setAlphaComponent(resolveTabActiveColor(context, modelType), POPUP_SELECTED_BG_ALPHA);
    }
}
