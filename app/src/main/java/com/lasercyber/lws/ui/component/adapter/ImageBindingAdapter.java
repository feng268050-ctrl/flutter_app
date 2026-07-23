package com.lasercyber.lws.ui.component.adapter;

import android.graphics.drawable.Drawable;
import android.widget.ImageView;

import androidx.databinding.BindingAdapter;

/**
 * DataBinding 图片绑定适配器
 * 用于动态绑定 ImageView 的 android:src 属性
 */
public class ImageBindingAdapter {

    /**
     * 绑定图片资源 ID 到 ImageView
     *
     * @param imageView 目标ImageView
     * @param resId     图片资源ID（如 R.mipmap.cemera_stop_icon）
     */
    @BindingAdapter("imageSrc")
    public static void setImageResource(ImageView imageView, int resId) {
        // 空值判断：避免设置无效的资源ID
        if (resId > 0) {
            imageView.setImageResource(resId);
        }
    }

    /**
     * 重载：绑定 Drawable 对象到 ImageView
     *
     * @param imageView 目标ImageView
     * @param drawable  Drawable对象
     */
    @BindingAdapter("imageSrc")
    public static void setImageDrawable(ImageView imageView, Drawable drawable) {
        if (drawable != null) {
            imageView.setImageDrawable(drawable);
        }
    }
    // 可选扩展：绑定网络图片（需结合Glide/Picasso）
    /*
    @BindingAdapter("imageUrl")
    public static void loadImageFromUrl(ImageView imageView, String url) {
        if (url == null || url.isEmpty()) {
            imageView.setImageResource(R.mipmap.ic_launcher);
            return;
        }
        // 结合Glide加载网络图片（需添加Glide依赖）
        Glide.with(imageView.getContext())
             .load(url)
             .placeholder(R.mipmap.ic_launcher)
             .error(R.mipmap.ic_launcher)
             .into(imageView);
    }
    */
}