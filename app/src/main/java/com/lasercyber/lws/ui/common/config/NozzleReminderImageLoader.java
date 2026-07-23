package com.lasercyber.lws.ui.common.config;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.util.Log;
import android.widget.ImageView;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.ModelConstant;

/**
 * Loads mode-specific nozzle illustrations from {@code res/drawable-nodpi/nozzle_*.png}.
 */
public final class NozzleReminderImageLoader {

    private static final String TAG = LogTAGConstant.APPLICATION;

    private NozzleReminderImageLoader() {
    }

    /**
     * Binds the illustration for {@code processModel}; blank when no matching drawable exists.
     */
    public static void bind(ImageView imageView, int processModel) {
        if (imageView == null) {
            return;
        }
        int resId = drawableIdFor(processModel);
        if (resId == 0) {
            Log.w(TAG, "nozzle reminder illustration missing for processModel=" + processModel);
            imageView.setImageDrawable(null);
            return;
        }
        Bitmap bitmap = BitmapFactory.decodeResource(imageView.getResources(), resId);
        if (bitmap == null) {
            Log.w(TAG, "nozzle reminder illustration failed to decode resId=0x"
                    + Integer.toHexString(resId) + " processModel=" + processModel);
            imageView.setImageDrawable(null);
            return;
        }
        imageView.setImageBitmap(bitmap);
        Log.i(TAG, "nozzle reminder illustration bound processModel=" + processModel + " resId=0x"
                + Integer.toHexString(resId));
    }

    static int drawableIdFor(int processModel) {
        return switch (processModel) {
            case ModelConstant.HAND_CUT, ModelConstant.CNC_CUT -> R.drawable.nozzle_cut;
            case ModelConstant.WELD_CLEAN -> R.drawable.nozzle_weld_path_clean;
            case ModelConstant.WIDTH_CLEAN -> R.drawable.nozzle_ultra_wide_clean;
            case ModelConstant.CONTINUOUS_WELDING, ModelConstant.POINT_WELDING -> R.drawable.nozzle_weld;
            default -> {
                Log.w(TAG, "unknown processModel for nozzle reminder illustration: " + processModel);
                yield R.drawable.nozzle_weld;
            }
        };
    }
}
