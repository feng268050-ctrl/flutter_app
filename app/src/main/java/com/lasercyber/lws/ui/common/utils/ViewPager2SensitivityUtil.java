package com.lasercyber.lws.ui.common.utils;

import androidx.recyclerview.widget.RecyclerView;
import androidx.viewpager2.widget.ViewPager2;

import java.lang.reflect.Field;

public class ViewPager2SensitivityUtil {
    /**
     * 修改 ViewPager2 的滑动灵敏度
     * @param viewPager2 目标 ViewPager2
     * @param touchSlopScale 滑动阈值缩放比例（0.5f=更灵敏，2f=更迟钝，1f=默认）
     * @param velocityScale 速度阈值缩放比例（0.5f=更灵敏，2f=更迟钝，1f=默认）
     */
    public static void adjustViewPager2Sensitivity(ViewPager2 viewPager2,
                                                   int touchSlopScale,
                                                   float velocityScale) {
        if (viewPager2 == null) return;

        // 2. 修改 RecyclerView 的 touchSlop（滑动触发阈值）
        adjustRecyclerViewTouchSlop(viewPager2, touchSlopScale);
    }


    /**
     * 修改 ViewPager2 的最小快速滑动速度阈值
     */
    private static void adjustRecyclerViewTouchSlop(ViewPager2 viewPager2, int scale) {
        try {
            Field recyclerViewField = ViewPager2.class.getDeclaredField("mRecyclerView");
            recyclerViewField.setAccessible(true);

            RecyclerView recyclerView = (RecyclerView) recyclerViewField.get(viewPager2);
//            recyclerView.setScrollingTouchSlop(RecyclerView.TOUCH_SLOP_PAGING);
            Field touchSlopField = RecyclerView.class.getDeclaredField("mTouchSlop");
            touchSlopField.setAccessible(true);

            int touchSlop = (int) touchSlopField.get(recyclerView);
            touchSlopField.set(recyclerView, touchSlop * scale);
        } catch (NoSuchFieldException | IllegalAccessException e) {
            e.printStackTrace();
        }
    }

    // 快捷方法：设置为高灵敏度（滑动更灵敏，轻微滑动即可切换页面）
    public static void setHighSensitivity(ViewPager2 viewPager2) {
        adjustViewPager2Sensitivity(viewPager2, 1, 0.5f);
    }

    // 快捷方法：设置为低灵敏度（防止误触，需要更大滑动/速度才切换）
    public static void setLowSensitivity(ViewPager2 viewPager2) {
        adjustViewPager2Sensitivity(viewPager2, 5, 2.0f);
    }

    // 快捷方法：恢复默认灵敏度
    public static void restoreDefaultSensitivity(ViewPager2 viewPager2) {
        adjustViewPager2Sensitivity(viewPager2, 1, 1.0f);
    }
}
