package com.lasercyber.lws.ui.common.utils;

import android.os.SystemClock;

/*点击加锁*/
public class ClickLook {
    private final Object clickLock = new Object();
    private long lastClickTime = 0;
    private static long CLICK_INTERVAL = 1000;
    /*点击时间间隔*/
    public boolean clickTime(){

        synchronized (clickLock) {
            // 1. 获取当前点击时间
            long currentTime = SystemClock.elapsedRealtime();
            // 2. 防抖判断：如果两次点击间隔小于阈值，直接返回
            if (currentTime - lastClickTime < CLICK_INTERVAL) {
                return false;
            }
            // 3. 更新最后点击时间
            lastClickTime = currentTime;
            CLICK_INTERVAL = 1000;
            return true;
        }
    }

    public boolean clickTime( long time ){
        CLICK_INTERVAL = time;
        return clickTime();
    }


    /*加锁， 不解锁*/
    public void upClickTime(){
            // 3. 更新最后点击时间
        lastClickTime = SystemClock.elapsedRealtime();;
    }
}
