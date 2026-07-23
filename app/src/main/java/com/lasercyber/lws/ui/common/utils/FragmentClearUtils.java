package com.lasercyber.lws.ui.common.utils;

import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentManager;
import androidx.fragment.app.FragmentTransaction;

public class FragmentClearUtils {

    /**
     * 清空FragmentManager中所有已添加的Fragment
     * @param fragmentManager 目标FragmentManager（如getFragmentManager()/getSupportFragmentManager()）
     */
    public static void clearAllFragments(FragmentManager fragmentManager) {
        if (fragmentManager == null) {
            return;
        }

        // 步骤1：获取所有已添加的Fragment
        // getFragments()返回当前已添加的Fragment列表（API 17+）
        for (Fragment fragment : fragmentManager.getFragments()) {
            if (fragment != null && !fragment.isRemoving()) { // 避免重复移除
                // 步骤2：开启事务并移除Fragment
                FragmentTransaction transaction = fragmentManager.beginTransaction();
                transaction.remove(fragment);

                // 可选：如果需要彻底清除，可同时移除回退栈（若有）
                fragmentManager.popBackStackImmediate(null, FragmentManager.POP_BACK_STACK_INCLUSIVE);

                // 步骤3：安全提交事务（避免Activity/Fragment状态保存后提交）
                if (!fragmentManager.isStateSaved()) {
                    transaction.commitNowAllowingStateLoss(); // 推荐：立即执行，允许状态丢失
                    // 也可使用 transaction.commit(); 但commitNowAllowingStateLoss更稳定
                }
            }
        }
    }
}
