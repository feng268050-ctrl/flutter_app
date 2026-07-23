package com.lasercyber.lws.ui.activitys.quick.mode.component;

import android.app.Dialog;
import android.content.Context;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.view.Window;

import androidx.annotation.NonNull;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;

/**
 * CNC退出提醒弹窗
 */
public class CNCExitDialog extends Dialog {
    private CNCExitDialogListener cncExitDialogListener;

    public CNCExitDialog(@NonNull Context context) {
        super(context);
        initView(context);
    }

    public CNCExitDialog(@NonNull Context context, CNCExitDialogListener cncExitDialogListener) {
        super(context);
        this.cncExitDialogListener = cncExitDialogListener;
        initView(context);
    }

    protected void initView(Context context) {
        // 去掉系统默认标题栏
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        setContentView(R.layout.cnc_exit_dialog);
        Window window = getWindow();
        if (window != null) {
            // 把弹窗窗口背景设为透明，消灭圆角外白色
            window.setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
            // 圆角+黑色背景+边框shape
            window.setBackgroundDrawableResource(R.drawable.cnc_running_border);
        }
        // 默认点击外部可关闭
        setCanceledOnTouchOutside(false);
        // 确认
        findViewById(R.id.cnc_exit_confirm).setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            if (cncExitDialogListener != null) {
                if (cncExitDialogListener.onConfirm()) {
                    dismiss();
                }
            } else {
                dismiss();
            }

        });
        // 取消
        findViewById(R.id.cnc_exit_cancel).setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            if (cncExitDialogListener != null) {
                if (cncExitDialogListener.onCancel()) {
                    dismiss();
                }
            } else {
                dismiss();
            }
        });
    }

    public interface CNCExitDialogListener {
        /**
         * 确认
         *
         * @return true：关闭弹窗，false：不关闭弹窗
         */
        boolean onConfirm();

        /**
         * 取消
         *
         * @return true：关闭弹窗，false：不关闭弹窗
         */
        boolean onCancel();
    }
}
