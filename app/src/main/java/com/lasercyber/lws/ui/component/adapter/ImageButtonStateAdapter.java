package com.lasercyber.lws.ui.component.adapter;

import android.widget.ImageButton;

import androidx.annotation.DrawableRes;
import androidx.annotation.Nullable;
import androidx.databinding.BindingAdapter;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.constant.ModelConstant;

/**
 * ImageButton 状态绑定适配器
 * 解决 android:state_xxx 无法直接绑定布尔值的问题
 */
public class ImageButtonStateAdapter {

    /** ~35% alpha for comm-unavailable idle visual (does not disable clicks). */
    private static final int COMM_UNAVAILABLE_IMAGE_ALPHA = 89;

    /**
     * Idle available uses colored stop assets (play in lens); unavailable uses gray stop; recording uses run (pause).
     */
    @BindingAdapter(value = {"recordButtonModelType", "selectedState", "commUnavailableState"}, requireAll = false)
    public static void setCameraRecordButtonVisual(
            ImageButton imageButton,
            @Nullable Integer recordButtonModelType,
            @Nullable Boolean isSelected,
            @Nullable Boolean commUnavailable) {
        boolean recording = isSelected != null && isSelected;
        boolean unavailable = !recording && commUnavailable != null && commUnavailable;
        imageButton.setSelected(recording);
        imageButton.clearColorFilter();
        if (recording) {
            imageButton.setImageResource(resolveRecordingIcon(recordButtonModelType));
            imageButton.setImageAlpha(255);
            return;
        }
        imageButton.setImageResource(
                unavailable ? R.mipmap.camera_stop_icon : resolveAvailableIdleIcon(recordButtonModelType));
        imageButton.setImageAlpha(unavailable ? COMM_UNAVAILABLE_IMAGE_ALPHA : 255);
    }

    @DrawableRes
    static int resolveAvailableIdleIcon(@Nullable Integer modelType) {
        int type = modelType != null ? modelType : ModelConstant.CONTINUOUS_WELDING;
        if (type == ModelConstant.WELD_CLEAN || type == ModelConstant.WIDTH_CLEAN) {
            return R.mipmap.camera_stop_green_icon;
        }
        if (type == ModelConstant.HAND_CUT) {
            return R.mipmap.camera_stop_blue_icon;
        }
        return R.mipmap.camera_stop_orange_icon;
    }

    @DrawableRes
    static int resolveRecordingIcon(@Nullable Integer modelType) {
        int type = modelType != null ? modelType : ModelConstant.CONTINUOUS_WELDING;
        if (type == ModelConstant.WELD_CLEAN || type == ModelConstant.WIDTH_CLEAN) {
            return R.mipmap.camera_run_green_icon;
        }
        if (type == ModelConstant.HAND_CUT) {
            return R.mipmap.camera_run_blue_icon;
        }
        return R.mipmap.camera_run_orange_icon;
    }

    /**
     * 补充：绑定可用状态（避免后续遇到同样问题）
     */
    @BindingAdapter("enabledState")
    public static void setImageButtonEnabled(ImageButton imageButton, Boolean isEnabled) {
        if (isEnabled == null) {
            imageButton.setEnabled(true); // 默认可用
        } else {
            imageButton.setEnabled(isEnabled);
        }
    }
}