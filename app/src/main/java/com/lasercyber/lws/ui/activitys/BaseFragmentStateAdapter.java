package com.lasercyber.lws.ui.activitys;

import android.util.Log;

import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentActivity;
import androidx.viewpager2.adapter.FragmentStateAdapter;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.util.List;

import lombok.Getter;

/**
 * 基础的FragmentStateAdapter
 * @param <T>
 */
public class BaseFragmentStateAdapter<T extends Fragment> extends FragmentStateAdapter {
    private static final String TAG = LogTAGConstant.BaseFragmentStateAdapter;
    @Getter
    private final List<T> fragmentList;

    public BaseFragmentStateAdapter(FragmentActivity activity, List<T> fragmentList){
        super(activity);
        this.fragmentList=fragmentList;
    }

    @NonNull
    @Override
    public Fragment createFragment(int position) {
        return fragmentList.get(position);
    }

    @Override
    public int getItemCount() {
        return fragmentList.size();
    }

    /**
     * 动态替换指定位置的Fragment（核心方法）
     *
     * @param position    要替换的位置
     * @param newFragment 新的Fragment
     */
    public void replaceFragment(int position, T newFragment) {
        // 1. 边界校验
        if (position < 0 || position >= fragmentList.size()) {
            Log.e(TAG, "replaceFragment: 页面切换失败:" + position);
            return;
        }
        // 2. 替换数据源中的Fragment
        fragmentList.set(position, newFragment);
        // 3. 关键：通知适配器该位置的Item已失效，触发重建
        //    注意：不能只用notifyDataSetChanged()，需结合getItemId+containsItem保证精准刷新
        notifyItemChanged(position);
    }

    @Override
    public long getItemId(int position) {
        T fragment = fragmentList.get(position);
        if (fragment instanceof BaseFragment<?> baseFragment) {
            long fragmentId = baseFragment.fragmentId();
            if (fragmentId > 0) {
                return fragmentId;
            }
        }
        return super.getItemId(position);
    }
}
