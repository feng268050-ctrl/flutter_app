package com.lasercyber.lws.ui.common.utils;
import android.content.Context;
import android.content.res.Resources;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Rect;
import android.graphics.drawable.BitmapDrawable;
import android.os.Build;
import android.renderscript.Allocation;
import android.renderscript.Element;
import android.renderscript.RenderScript;
import android.renderscript.ScriptIntrinsicBlur;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;

public class BlurUtils {
    private static final String TAG = "BlurUtils";
    // 最大模糊半径（RenderScript限制最大25）
    private static final int MAX_BLUR_RADIUS = 25;

    /**
     * 对指定View进行模糊，返回模糊后的Bitmap
     * @param view 要模糊的View（如LinearLayout）
     * @param radius 模糊半径（0-25）
     * @return 模糊后的Bitmap
     */
    public static Bitmap blurView(View view, int radius) {
        // 1. 将View绘制为Bitmap
        Bitmap bitmap = createBitmapFromView(view);
        if (bitmap==null){
            return null;
        }
        // 2. 对Bitmap进行高斯模糊
        return blurBitmap(view.getContext(), bitmap, radius);
    }

    /**
     * 将View转为Bitmap
     */
    private static Bitmap createBitmapFromView(View view) {
        // 测量View尺寸（确保View已布局完成）
        view.measure(View.MeasureSpec.makeMeasureSpec(view.getWidth(), View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(view.getHeight(), View.MeasureSpec.EXACTLY));
        view.layout(view.getLeft(), view.getTop(), view.getRight(), view.getBottom());
        if (view.getWidth()<=0||view.getHeight()<=0){
            return null;
        }
        // 创建Bitmap并绘制
        Bitmap bitmap = Bitmap.createBitmap(view.getWidth(), view.getHeight(), Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        view.draw(canvas);
        return bitmap;
    }

    /**
     * 高斯模糊Bitmap（兼容API 17+）
     */
    public static Bitmap blurBitmap(Context context, Bitmap bitmap, int radius) {
        if (bitmap == null || bitmap.isRecycled()) {
            return null;
        }
        if (radius > MAX_BLUR_RADIUS) radius = MAX_BLUR_RADIUS;
        if (radius <= 0) return bitmap;

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
            try {
                RenderScript rs = RenderScript.create(context.getApplicationContext());
                Allocation input = Allocation.createFromBitmap(rs, bitmap);
                Allocation output = Allocation.createTyped(rs, input.getType());
                ScriptIntrinsicBlur blurScript = ScriptIntrinsicBlur.create(rs, Element.U8_4(rs));
                blurScript.setRadius(radius);
                blurScript.setInput(input);
                blurScript.forEach(output);
                output.copyTo(bitmap);
                input.destroy();
                output.destroy();
                blurScript.destroy();
                rs.destroy();
                return bitmap;
            } catch (Throwable renderScriptFailure) {
                Log.w(
                        TAG,
                        "RenderScript blur failed (radius=" + radius
                                + ", size=" + bitmap.getWidth() + "x" + bitmap.getHeight() + ")",
                        renderScriptFailure
                );
            }
        }
        return blurBitmapJava(bitmap, radius);
    }

    /**
     * Java实现高斯模糊（兼容低版本）
     */
    private static Bitmap blurBitmapJava(Bitmap bitmap, int radius) {
        int width = bitmap.getWidth();
        int height = bitmap.getHeight();
        Bitmap blurred = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(blurred);
        canvas.drawBitmap(bitmap, 0, 0, null);

        int[] pixels = new int[width * height];
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height);

        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                int r = 0, g = 0, b = 0, a = 0;
                int count = 0;

                // 遍历模糊半径内的像素
                for (int iy = y - radius; iy <= y + radius; iy++) {
                    for (int ix = x - radius; ix <= x + radius; ix++) {
                        if (iy >= 0 && iy < height && ix >= 0 && ix < width) {
                            int pixel = pixels[iy * width + ix];
                            a += (pixel >> 24) & 0xff;
                            r += (pixel >> 16) & 0xff;
                            g += (pixel >> 8) & 0xff;
                            b += pixel & 0xff;
                            count++;
                        }
                    }
                }

                // 计算平均值
                a /= count;
                r /= count;
                g /= count;
                b /= count;
                pixels[y * width + x] = (a << 24) | (r << 16) | (g << 8) | b;
            }
        }

        blurred.setPixels(pixels, 0, width, 0, 0, width, height);
        return blurred;
    }

    /**
     * 显示模糊视图
     * @param resources
     * @param viewGroup
     */
    public static void showBlurView(Resources resources,ViewGroup ...viewGroup){
        for (ViewGroup group : viewGroup) {
            Bitmap bitmap = BlurUtils.blurView(group, 15);
            if (bitmap == null){
                continue;
            }
//            for (int i = 0; i < group.getChildCount(); i++) {
//                group.getChildAt(i).setVisibility(View.INVISIBLE);
//            }
            group.setBackground(new BitmapDrawable(resources, bitmap));
        }

    }

    /**
     * 隐藏模糊视图
     *
     * @param viewGroup
     */
    public static void hideBlurView(ViewGroup... viewGroup) {
        for (ViewGroup group : viewGroup) {
//            for (int i = 0; i < group.getChildCount(); i++) {
//                group.getChildAt(i).setVisibility(View.VISIBLE);
//            }
            group.setBackground(null);
        }
    }
}