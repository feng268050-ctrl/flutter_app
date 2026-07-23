package com.lasercyber.lws.ui.component.layout;

import android.content.Context;
import android.graphics.Paint;
import android.util.AttributeSet;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.TextView;

import com.google.android.material.tabs.TabLayout;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.TabItemBean;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;

import java.util.ArrayList;
import java.util.List;

public class TopTabView extends FrameLayout {
    private static final int TAB_ICON_WIDTH_DP = 24;
    private static final int TAB_ICON_MARGIN_END_DP = 6;
    private static final int TAB_HORIZONTAL_PADDING_DP = 48;
    private TabLayout tabLayout;
    private OnTabSelectedListener tabListener;
    private List<View> tabViewList = new ArrayList<>();
    private int unselectedColor;
    private int selectedColor;
    private boolean programmaticSelection;
    /** Suppresses click sound while {@link TabLayout} is populated or synced programmatically. */
    private boolean suppressSelectionSound;

    public TopTabView(Context context) { this(context, null); }
    public TopTabView(Context context, AttributeSet attrs) { this(context, attrs, 0); }
    public TopTabView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        unselectedColor = getResources().getColor(R.color.tab_text_unselected);
        selectedColor = getResources().getColor(R.color.tab_text_selected);
        View.inflate(context, R.layout.view_top_tab, this);
        tabLayout = findViewById(R.id.tab_layout);
        tabLayout.setSoundEffectsEnabled(false);

        tabLayout.addOnTabSelectedListener(new TabLayout.OnTabSelectedListener() {
            @Override
            public void onTabSelected(TabLayout.Tab tab) {
                updateTabStyle(tab.getPosition(), true);
                if (!programmaticSelection && !suppressSelectionSound) {
                    GlobalSoundManager.playClickSound(getContext());
                }
                if (programmaticSelection) {
                    programmaticSelection = false;
                }
                if (tabListener != null) {
                    TabItemBean bean = (TabItemBean) tab.getTag();
                    tabListener.onTabSelected(tab.getPosition(), bean.getTitle());
                }
            }

            @Override
            public void onTabUnselected(TabLayout.Tab tab) {
                updateTabStyle(tab.getPosition(), false);
            }

            @Override
            public void onTabReselected(TabLayout.Tab tab) {}
        });
    }

    /**
     * Sync highlight from ViewPager without playing click sound. Safe to call repeatedly for
     * the same position (unlike {@link #setSelectedTab(int)} with a suppress flag).
     */
    public void selectTabSilently(int position) {
        if (position < 0 || position >= tabLayout.getTabCount()) {
            return;
        }
        programmaticSelection = true;
        if (tabLayout.getSelectedTabPosition() == position) {
            refreshAllTabStyles(position);
            programmaticSelection = false;
            suppressSelectionSound = false;
            return;
        }
        tabLayout.selectTab(tabLayout.getTabAt(position));
        suppressSelectionSound = false;
    }

    /** @deprecated Use {@link #selectTabSilently(int)} for programmatic selection. */
    @Deprecated
    public void setSuppressNextClickSound(boolean suppress) {
        if (suppress) {
            programmaticSelection = true;
        }
    }

    public void addTabs(List<TabItemBean> tabItemList) {
        if (tabItemList == null || tabItemList.isEmpty()) return;
        suppressSelectionSound = true;
        programmaticSelection = false;
        tabLayout.removeAllTabs();
        tabViewList.clear();
        LayoutInflater inflater = LayoutInflater.from(getContext());
        int tabW = calculateTabMinWidth(tabItemList);
        for (TabItemBean bean : tabItemList) {
            View tabView = inflater.inflate(R.layout.tab_item_layout, tabLayout, false);
            ImageView tabIcon = tabView.findViewById(R.id.tab_icon);
            TextView tabTitle = tabView.findViewById(R.id.tab_title);
            tabIcon.setImageResource(bean.getIconResId());
            tabTitle.setText(bean.getTitle());
            tabTitle.setMaxWidth(Math.max(0, tabW
                    - dp(TAB_ICON_WIDTH_DP)
                    - dp(TAB_ICON_MARGIN_END_DP)
                    - dp(TAB_HORIZONTAL_PADDING_DP)));
            tabIcon.setColorFilter(unselectedColor);
            tabTitle.setTextColor(unselectedColor);
            ViewGroup.LayoutParams layoutParams = tabView.getLayoutParams();
            if (layoutParams != null) {
                layoutParams.width = tabW;
                tabView.setLayoutParams(layoutParams);
            }
            TabLayout.Tab tab = tabLayout.newTab();
            tab.setCustomView(tabView);
            tab.setTag(bean);
            disableSoundEffects(tabView);
            tabLayout.addTab(tab);
            tabViewList.add(tabView);
        }
        disableSoundEffects(tabLayout);
        tabLayout.setMinimumWidth(tabW);
        for (View tabView : tabViewList) {
            tabView.setMinimumWidth(tabW);
        }
        if (!tabViewList.isEmpty()) {
            refreshAllTabStyles(0);
        }
    }

    public void setSelectedTab(int position) {
        selectTabSilently(position);
    }

    private void refreshAllTabStyles(int selectedPosition) {
        for (int i = 0; i < tabViewList.size(); i++) {
            updateTabStyle(i, i == selectedPosition);
        }
    }

    private void updateTabStyle(int position, boolean isSelected) {
        if (position >= tabViewList.size()) return;
        View tabView = tabViewList.get(position);
        ImageView tabIcon = tabView.findViewById(R.id.tab_icon);
        TextView tabTitle = tabView.findViewById(R.id.tab_title);
        int color = isSelected ? selectedColor : unselectedColor;
        tabIcon.setColorFilter(color);
        tabTitle.setTextColor(color);
    }

    public interface OnTabSelectedListener {
        void onTabSelected(int position, String tabTitle);
    }

    public void setOnTabSelectedListener(OnTabSelectedListener listener) {
        this.tabListener = listener;
    }

    private int calculateTabMinWidth(List<TabItemBean> tabItemList) {
        int baseWidth = getResources().getDimensionPixelSize(R.dimen.top_tab_item_width);
        Paint textPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        textPaint.setTextSize(getResources().getDimension(R.dimen.text_size_11));
        float maxTextWidth = 0f;
        for (TabItemBean item : tabItemList) {
            if (item == null || item.getTitle() == null) {
                continue;
            }
            maxTextWidth = Math.max(maxTextWidth, textPaint.measureText(item.getTitle()));
        }
        int contentWidth = (int) Math.ceil(maxTextWidth)
                + dp(TAB_ICON_WIDTH_DP)
                + dp(TAB_ICON_MARGIN_END_DP)
                + dp(TAB_HORIZONTAL_PADDING_DP);
        return Math.max(baseWidth, contentWidth);
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private static void disableSoundEffects(View view) {
        view.setSoundEffectsEnabled(false);
        if (view instanceof ViewGroup group) {
            for (int i = 0; i < group.getChildCount(); i++) {
                disableSoundEffects(group.getChildAt(i));
            }
        }
    }
}
