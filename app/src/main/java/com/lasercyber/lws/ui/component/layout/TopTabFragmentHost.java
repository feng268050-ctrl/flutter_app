package com.lasercyber.lws.ui.component.layout;

import androidx.annotation.IdRes;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentActivity;

import com.lasercyber.lws.ui.bean.entity.TabItemBean;

import java.util.List;

/**
 * Pairs {@link TopTabView} with {@link FragmentShowHideTabHost} for tabbed screens that host
 * one visible {@link Fragment} at a time.
 */
public final class TopTabFragmentHost {

    public interface OnTabShownListener {
        void onTabShown(int position, @NonNull String tabTitle);
    }

    private final TopTabView topTabView;
    private final FragmentShowHideTabHost tabHost;
    @Nullable
    private OnTabShownListener onTabShownListener;

    public TopTabFragmentHost(
            @NonNull FragmentActivity activity,
            @NonNull TopTabView topTabView,
            @IdRes int containerId,
            @NonNull String fragmentTagPrefix) {
        this.topTabView = topTabView;
        this.tabHost = new FragmentShowHideTabHost(activity, containerId, fragmentTagPrefix);
    }

    public void setup(@NonNull List<TabItemBean> tabItems, @NonNull List<Fragment> tabFragments) {
        topTabView.addTabs(tabItems);
        topTabView.setOnTabSelectedListener((position, tabTitle) -> {
            tabHost.showTab(position);
            if (onTabShownListener != null) {
                onTabShownListener.onTabShown(position, tabTitle);
            }
        });
        tabHost.install(tabFragments);
    }

    public void setOnTabShownListener(@Nullable OnTabShownListener listener) {
        onTabShownListener = listener;
    }

    /** Selects a tab and syncs {@link TopTabView} highlight without playing click sound. */
    public void selectTab(int position) {
        tabHost.showTab(position);
        topTabView.selectTabSilently(position);
    }

    public int getTabCount() {
        return tabHost.getTabCount();
    }

    public int getCurrentTabIndex() {
        return tabHost.getCurrentTabIndex();
    }

    @Nullable
    public Fragment getFragment(int index) {
        return tabHost.getFragment(index);
    }

    @Nullable
    public <T extends Fragment> T getFragment(int index, @NonNull Class<T> type) {
        return tabHost.getFragment(index, type);
    }
}
