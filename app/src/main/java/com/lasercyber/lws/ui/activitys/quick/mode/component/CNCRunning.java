package com.lasercyber.lws.ui.activitys.quick.mode.component;

import android.content.Context;
import android.content.res.TypedArray;
import android.util.AttributeSet;
import android.util.Log;
import android.view.LayoutInflater;
import android.widget.LinearLayout;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.quick.mode.listener.CNCLinkExitListener;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.databinding.CncRunningBinding;

import lombok.Setter;

/**
 * CNC模式运行中
 */
public class CNCRunning extends LinearLayout implements MemoryCacheManager.OnCacheChangedListener {
    private static final String TAG = LogTAGConstant.CNCRunning;
    private CncRunningBinding binding;
    @Setter
    private CNCLinkExitListener cncLinkExitListener;

    public CNCRunning(Context context) {
        super(context);
        this.initView(context);
    }

    public CNCRunning(Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
        this.attrsHandler(context, attrs);
        this.initView(context);
    }

    public CNCRunning(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        this.attrsHandler(context, attrs);
        this.initView(context);
    }

    private void initView(Context context) {
        binding = CncRunningBinding.inflate(LayoutInflater.from(context), this, true);
        binding.exitCncBtn.setOnClickListener(v -> {
            // 退出CNC模式
            GlobalSoundManager.playClickSound();
            new CNCExitDialog(getContext(), new CNCExitDialog.CNCExitDialogListener() {
                @Override
                public boolean onConfirm() {
                    if (cncLinkExitListener != null) {
                        cncLinkExitListener.onExit(false);
                    }
                    return true;
                }

                @Override
                public boolean onCancel() {
                    return true;
                }
            }).show();
        });
    }

    /**
     * 解析参数
     *
     * @param context
     * @param attrs
     */
    private void attrsHandler(Context context, @Nullable AttributeSet attrs) {
        TypedArray typedArray = context.obtainStyledAttributes(attrs, R.styleable.cnc_running);
        // 自定义的属性xml
        // 回收typedArray
        typedArray.recycle();
    }

    public void setCnc_link_status(boolean cncRunning) {
        if (cncRunning) {
            // 监听CNC退出
            MemoryCacheManager.getInstance().addListener(CacheKey.DEVICE_STATUS_KEY, this);
        } else {
            MemoryCacheManager.getInstance().removeListener(CacheKey.DEVICE_STATUS_KEY, this);
        }
    }

    @Override
    protected void onDetachedFromWindow() {
        super.onDetachedFromWindow();
        if (binding != null) {
            binding.unbind();
            binding = null;
        }
        MemoryCacheManager.getInstance().removeListener(CacheKey.DEVICE_STATUS_KEY, this);
    }

    @Override
    public void onCacheChanged(String key) {
        DeviceStatus deviceStatus = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        if (deviceStatus == null || deviceStatus.isConnectCNC()) {
            Log.d(TAG, "onCacheChanged: CNC已连接");
            return;
        }
        // 退出CNC模式
        if (cncLinkExitListener != null) {
            Log.d(TAG, "onCacheChanged: CNC断开");
            cncLinkExitListener.onExit(true);
            // 移除监听
            MemoryCacheManager.getInstance().removeListener(CacheKey.DEVICE_STATUS_KEY, this);
        }
    }
}
