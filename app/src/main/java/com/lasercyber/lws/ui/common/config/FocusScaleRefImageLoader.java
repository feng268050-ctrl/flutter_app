package com.lasercyber.lws.ui.common.config;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.util.Log;
import android.widget.ImageView;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

/**
 * Loads focus-scale reference illustrations from {@code res/drawable-nodpi/fsr_*.png}.
 */
public final class FocusScaleRefImageLoader {

    private static final String TAG = LogTAGConstant.APPLICATION;

    private FocusScaleRefImageLoader() {
    }

    /**
     * Binds the illustration for {@code focusScaleRef} when a matching drawable exists; otherwise blank.
     */
    public static void bind(ImageView imageView, int focusScaleRef) {
        if (imageView == null) {
            return;
        }
        int resId = drawableIdFor(focusScaleRef);
        if (resId == 0) {
            Log.w(TAG, "focus scale ref illustration missing for value=" + focusScaleRef);
            imageView.setImageDrawable(null);
            return;
        }
        Bitmap bitmap = BitmapFactory.decodeResource(imageView.getResources(), resId);
        if (bitmap == null) {
            Log.w(TAG, "focus scale ref illustration failed to decode resId=0x"
                    + Integer.toHexString(resId) + " value=" + focusScaleRef);
            imageView.setImageDrawable(null);
            return;
        }
        imageView.setImageBitmap(bitmap);
        Log.i(TAG, "focus scale ref illustration bound value=" + focusScaleRef + " resId=0x"
                + Integer.toHexString(resId));
    }

    static int drawableIdFor(int focusScaleRef) {
        switch (focusScaleRef) {
            case -9:
                return R.drawable.fsr_n9;
            case -8:
                return R.drawable.fsr_n8;
            case -7:
                return R.drawable.fsr_n7;
            case -6:
                return R.drawable.fsr_n6;
            case -5:
                return R.drawable.fsr_n5;
            case -4:
                return R.drawable.fsr_n4;
            case -3:
                return R.drawable.fsr_n3;
            case -2:
                return R.drawable.fsr_n2;
            case -1:
                return R.drawable.fsr_n1;
            case 0:
                return R.drawable.fsr_0;
            case 1:
                return R.drawable.fsr_1;
            case 2:
                return R.drawable.fsr_2;
            case 3:
                return R.drawable.fsr_3;
            case 4:
                return R.drawable.fsr_4;
            case 5:
                return R.drawable.fsr_5;
            case 6:
                return R.drawable.fsr_6;
            case 7:
                return R.drawable.fsr_7;
            case 8:
                return R.drawable.fsr_8;
            case 9:
                return R.drawable.fsr_9;
            default:
                return 0;
        }
    }
}
