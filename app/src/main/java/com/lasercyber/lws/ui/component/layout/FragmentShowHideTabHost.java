package com.lasercyber.lws.ui.component.layout;

import androidx.annotation.IdRes;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentActivity;
import androidx.fragment.app.FragmentTransaction;

import java.util.ArrayList;
import java.util.List;

/**
 * Shows one {@link Fragment} at a time in a {@link android.widget.FrameLayout} via
 * {@link FragmentTransaction#show(Fragment)} / {@link FragmentTransaction#hide(Fragment)}.
 * Avoids ViewPager2 off-screen pages intercepting touches.
 */
public final class FragmentShowHideTabHost {

    private final FragmentActivity activity;
    @IdRes
    private final int containerId;
    @NonNull
    private final String tagPrefix;
    @NonNull
    private final List<Fragment> fragments = new ArrayList<>();
    private int currentIndex = -1;

    public FragmentShowHideTabHost(
            @NonNull FragmentActivity activity,
            @IdRes int containerId,
            @NonNull String tagPrefix) {
        this.activity = activity;
        this.containerId = containerId;
        this.tagPrefix = tagPrefix;
    }

    /**
     * Adds tab fragments on first launch, or rebinds restored instances after config change.
     *
     * @param tabFragments one fragment per tab index, in order
     */
    public void install(@NonNull List<Fragment> tabFragments) {
        if (!fragments.isEmpty()) {
            return;
        }
        Fragment restored = activity.getSupportFragmentManager().findFragmentByTag(tag(0));
        if (restored != null) {
            for (int i = 0; i < tabFragments.size(); i++) {
                Fragment fragment = activity.getSupportFragmentManager().findFragmentByTag(tag(i));
                if (fragment != null) {
                    fragments.add(fragment);
                }
            }
            restoreCurrentIndexFromVisibleFragment();
            return;
        }
        fragments.addAll(tabFragments);
        FragmentTransaction transaction = activity.getSupportFragmentManager().beginTransaction();
        for (int i = 0; i < fragments.size(); i++) {
            Fragment fragment = fragments.get(i);
            transaction.add(containerId, fragment, tag(i));
            transaction.hide(fragment);
        }
        transaction.commitNowAllowingStateLoss();
    }

    public void showTab(int position) {
        if (position < 0 || position >= fragments.size() || position == currentIndex) {
            return;
        }
        FragmentTransaction transaction = activity.getSupportFragmentManager().beginTransaction();
        if (currentIndex >= 0 && currentIndex < fragments.size()) {
            transaction.hide(fragments.get(currentIndex));
        }
        transaction.show(fragments.get(position));
        transaction.commitNowAllowingStateLoss();
        currentIndex = position;
    }

    public int getTabCount() {
        return fragments.size();
    }

    public int getCurrentTabIndex() {
        return currentIndex;
    }

    @Nullable
    public Fragment getFragment(int index) {
        if (index < 0 || index >= fragments.size()) {
            return null;
        }
        return fragments.get(index);
    }

    @Nullable
    public <T extends Fragment> T getFragment(int index, @NonNull Class<T> type) {
        Fragment fragment = getFragment(index);
        if (type.isInstance(fragment)) {
            return type.cast(fragment);
        }
        return null;
    }

    private void restoreCurrentIndexFromVisibleFragment() {
        currentIndex = -1;
        for (int i = 0; i < fragments.size(); i++) {
            Fragment fragment = fragments.get(i);
            if (fragment != null && fragment.isVisible()) {
                currentIndex = i;
                return;
            }
        }
    }

    @NonNull
    private String tag(int index) {
        return tagPrefix + index;
    }
}
