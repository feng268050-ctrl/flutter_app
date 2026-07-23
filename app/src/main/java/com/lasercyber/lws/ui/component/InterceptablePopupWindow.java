package com.lasercyber.lws.ui.component;
import android.content.Context;
import android.view.MotionEvent;
import android.view.View;
import android.widget.PopupWindow;

public class InterceptablePopupWindow extends PopupWindow {
    // 关闭拦截器：返回 true 允许关闭，false 禁止关闭
    private OnDismissInterceptListener dismissInterceptListener;

    public InterceptablePopupWindow(Context context) {
        super(context);
        init();
    }

    public InterceptablePopupWindow(View contentView, int width, int height) {
        super(contentView, width, height);
        init();
    }

    // 初始化：拦截外部触摸事件
    private void init() {
        // 1. 拦截外部触摸关闭（核心：重写触摸事件，替代系统默认逻辑）
        setOutsideTouchable(true); // 保留外部触摸触发，但自己处理逻辑
        setBackgroundDrawable(null); // 需设置背景（否则外部触摸不触发）
        getContentView().setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event) {
                // 外部触摸的判定：点击坐标在 PopupWindow 区域外
                if (event.getAction() == MotionEvent.ACTION_DOWN) {
                    if (isOutOfPopupWindow(event.getX(), event.getY())) {
                        // 触发关闭拦截判断
                        if (dismissInterceptListener != null && dismissInterceptListener.canDismiss()) {
                            realDismiss(); // 允许关闭，执行真正的 dismiss
                        }
                        return true; // 消费事件，阻止系统默认逻辑
                    }
                }
                return false;
            }
        });
    }

    // 判定点击坐标是否在 PopupWindow 外部
    private boolean isOutOfPopupWindow(float x, float y) {
        return x < 0 || x >= getWidth() || y < 0 || y >= getHeight();
    }

    // 对外暴露：手动调用的“安全关闭”方法（替代直接调用 dismiss()）
    public void safeDismiss() {
        if (dismissInterceptListener != null && dismissInterceptListener.canDismiss()) {
            realDismiss();
        }
    }

    // 真正的关闭逻辑（封装系统 dismiss()）
    private void realDismiss() {
        super.dismiss();
        // 可选：触发关闭回调
        if (dismissInterceptListener != null) {
            dismissInterceptListener.onDismissed();
        }
    }

    // 禁止外部直接调用 dismiss()（强制走 safeDismiss）
    @Override
    public void dismiss() {
        safeDismiss(); // 拦截系统 dismiss() 调用
    }

    // 关闭拦截器接口
    public interface OnDismissInterceptListener {
        boolean canDismiss(); // 返回 true 允许关闭，false 禁止
        void onDismissed(); // 关闭成功后的回调（可选）
    }

    // 设置拦截器
    public void setDismissInterceptListener(OnDismissInterceptListener listener) {
        this.dismissInterceptListener = listener;
    }
}