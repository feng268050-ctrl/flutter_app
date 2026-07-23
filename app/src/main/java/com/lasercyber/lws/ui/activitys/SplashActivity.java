package com.lasercyber.lws.ui.activitys;

import android.content.Intent;
import android.os.Bundle;

import androidx.appcompat.app.AppCompatActivity;

import com.lasercyber.lws.ui.BuildConfig;
import com.lasercyber.lws.ui.common.utils.AndroidEmulatorUtils;

import java.util.Objects;

public class SplashActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        AndroidEmulatorUtils.hideStatusBar(this);
        Intent intent;
        if (Objects.equals(BuildConfig.DEBUG, Boolean.TRUE)) {
            // 测试环境
            intent = getDebugIntent();
        } else {
            // 生产环境
            intent = new Intent(this, SafetyTipsActivity.class);
        }

        startActivity(intent);
        finish(); // 关闭启动页，避免返回键回到此页
    }

    /**
     * 测试环境
     *
     * @return
     */
    private Intent getDebugIntent() {
        return new Intent(this, SafetyTipsActivity.class);
    }
}