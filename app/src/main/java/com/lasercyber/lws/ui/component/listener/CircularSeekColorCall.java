package com.lasercyber.lws.ui.component.listener;

import android.graphics.RadialGradient;
import android.graphics.Shader;

import com.lasercyber.lws.ui.component.CircularSeekBar;

/**
 * 创建圆环的颜色
 */
public interface CircularSeekColorCall {
    Shader createShader(CircularSeekBar circularSeekBar);
}
