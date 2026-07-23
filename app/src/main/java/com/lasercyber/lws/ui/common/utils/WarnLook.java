package com.lasercyber.lws.ui.common.utils;

import android.os.SystemClock;

import com.lasercyber.lws.ui.bean.entity.WarnTable;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/*告警间隔*/
public class WarnLook {
    private final Object clickLock = new Object();
    private long lastClickTime = 0;
    private static long CLICK_INTERVAL = 5000;
    private String code = "";
    private String lastCode = "";

    /*点击时间间隔*/
    public boolean warnTime(){

        synchronized ( clickLock ) {
            // 1. 获取当前点击时间
            long currentTime = SystemClock.elapsedRealtime();
            // 2. 防抖判断：如果两次点击间隔小于阈值，直接返回
            if (currentTime - lastClickTime < CLICK_INTERVAL && code.equals( lastCode ) ) {
                return false;
            }
            lastCode = code;
            // 3. 更新最后点击时间
            lastClickTime = currentTime;
            CLICK_INTERVAL = 1000;
            return true;
        }
    }

    /*添加的告警数组去重*/
    public List<WarnTable> removeDuplicates( List<WarnTable> list ){
        String str = "";
        Map<String, WarnTable> codeMap = new HashMap<>();
        for (WarnTable table : list) {
            str = str + table.getCode();
            codeMap.put(table.getCode(),table);
        }
        this.code = str;
        return new ArrayList<>(codeMap.values());
    }

}
