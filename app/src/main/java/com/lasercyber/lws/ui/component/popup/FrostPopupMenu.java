package com.lasercyber.lws.ui.component.popup;

import android.app.Activity;
import android.content.Context;
import android.graphics.Rect;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.annotation.ColorInt;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;

import com.blankj.utilcode.util.SizeUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.EngineerModelThemeColors;
import com.lasercyber.lws.ui.component.AppScrollView;
import com.lasercyber.lws.ui.component.InterceptablePopupWindow;
import com.lasercyber.lws.ui.component.ListSelectionBackgroundUtils;
import com.lasercyber.lws.ui.component.layout.InsetDivider;
import com.lasercyber.lws.ui.component.layout.InsetList;
import com.lasercyber.lws.ui.component.layout.InsetListRow;

import java.util.ArrayList;
import java.util.List;

import lombok.Setter;

/**
 * Frosted-glass anchored popup menu built on {@link InsetList} rows (Settings list chrome).
 */
public class FrostPopupMenu {
    private static final int FADE_DURATION_MS = 300;

    private final Context context;
    private final View cardRoot;
    private final AppScrollView scrollView;
    private final InsetList listContainer;
    private final List<InsetListRow> rowViews = new ArrayList<>();

    private FrameLayout overlayRoot;
    private ViewGroup hostContentRoot;
    private List<PopupMenuItem> items = new ArrayList<>();
    private OnItemClickListener itemClickListener;
    private InterceptablePopupWindow.OnDismissInterceptListener dismissInterceptListener;

    private boolean showing;
    private int contentWidthPx;
    private int contentHeightPx;
    private int selectedIndex = -1;

    @ColorInt
    private int normalTextColor;
    @ColorInt
    private int selectedTextColor;
    @ColorInt
    private int selectedBackgroundColor;

    @Setter
    private int xOffset;
    @Setter
    private int yOffset;

    public interface OnItemClickListener {
        void onItemClick(@NonNull PopupMenuItem item, int position);
    }

    public FrostPopupMenu(@NonNull Context context) {
        this.context = context;
        normalTextColor = ContextCompat.getColor(context, R.color.white);
        applyModelTypeTheme(null);

        cardRoot = LayoutInflater.from(context).inflate(R.layout.frost_popup_menu, null);
        scrollView = cardRoot.findViewById(R.id.frost_popup_menu_scroll);
        listContainer = cardRoot.findViewById(R.id.frost_popup_menu_list);
        scrollView.setOverScrollMode(View.OVER_SCROLL_NEVER);
    }

    public void setModelTypeTheme(@Nullable Integer modelType) {
        applyModelTypeTheme(modelType);
        refreshRowSelectionColors();
    }

    private void applyModelTypeTheme(@Nullable Integer modelType) {
        selectedTextColor = EngineerModelThemeColors.resolveTabActiveColor(context, modelType);
        selectedBackgroundColor = EngineerModelThemeColors.resolvePopupSelectedBackgroundColor(
                context, modelType);
    }

    private void refreshRowSelectionColors() {
        for (int i = 0; i < rowViews.size(); i++) {
            InsetListRow row = rowViews.get(i);
            TextView labelView = row.findViewById(R.id.popup_menu_label);
            applyRowSelection(row, labelView, i == selectedIndex);
        }
    }

    public void setItems(
            @NonNull List<PopupMenuItem> items,
            @ColorInt int normalTextColorId,
            @NonNull OnItemClickListener listener) {
        this.items = new ArrayList<>(items);
        this.normalTextColor = ContextCompat.getColor(context, normalTextColorId);
        this.itemClickListener = listener;
        this.selectedIndex = -1;
        for (int i = 0; i < this.items.size(); i++) {
            if (this.items.get(i).isSelected()) {
                selectedIndex = i;
                break;
            }
        }
        rebuildList();
    }

    public void setContentSize(int widthDp, int heightDp) {
        contentWidthPx = SizeUtils.dp2px(widthDp);
        contentHeightPx = SizeUtils.dp2px(heightDp);

        ViewGroup.LayoutParams scrollParams = scrollView.getLayoutParams();
        if (scrollParams == null) {
            scrollParams = new ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, contentHeightPx);
        } else {
            scrollParams.width = ViewGroup.LayoutParams.MATCH_PARENT;
            scrollParams.height = contentHeightPx;
        }
        scrollView.setLayoutParams(scrollParams);
    }

    public void setDismissInterceptListener(
            InterceptablePopupWindow.OnDismissInterceptListener listener) {
        this.dismissInterceptListener = listener;
    }

    public void show(@NonNull View anchorView) {
        if (showing) {
            dismiss();
            return;
        }

        Activity activity = (Activity) context;
        hostContentRoot = activity.findViewById(android.R.id.content);
        if (hostContentRoot == null) {
            return;
        }

        overlayRoot = new FrameLayout(context);
        overlayRoot.setLayoutParams(new ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));
        overlayRoot.setClickable(true);
        overlayRoot.setFocusable(true);

        if (cardRoot.getParent() instanceof ViewGroup previousParent) {
            previousParent.removeView(cardRoot);
        }

        FrameLayout.LayoutParams cardParams = new FrameLayout.LayoutParams(
                contentWidthPx > 0 ? contentWidthPx : ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.TOP | Gravity.START);
        overlayRoot.addView(cardRoot, cardParams);

        overlayRoot.setOnTouchListener((v, event) -> {
            if (event.getAction() == MotionEvent.ACTION_DOWN
                    && !isTouchInsideView(cardRoot, event)) {
                safeDismiss();
                return true;
            }
            return false;
        });

        // FrostCardView hosts a ComposeView; measure only after the overlay is window-attached.
        overlayRoot.setAlpha(0f);
        hostContentRoot.addView(overlayRoot);

        int popupWidth = contentWidthPx > 0
                ? contentWidthPx
                : ViewGroup.LayoutParams.WRAP_CONTENT;
        int widthMeasureSpec = contentWidthPx > 0
                ? View.MeasureSpec.makeMeasureSpec(contentWidthPx, View.MeasureSpec.EXACTLY)
                : View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED);
        cardRoot.measure(
                widthMeasureSpec,
                View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED));
        if (contentWidthPx <= 0) {
            popupWidth = cardRoot.getMeasuredWidth();
        }

        int[] anchorLocation = new int[2];
        int[] rootLocation = new int[2];
        anchorView.getLocationOnScreen(anchorLocation);
        hostContentRoot.getLocationOnScreen(rootLocation);

        int anchorRight = anchorLocation[0] - rootLocation[0] + anchorView.getWidth();
        int left = anchorRight - popupWidth + xOffset;
        int maxLeft = Math.max(0, hostContentRoot.getWidth() - popupWidth);
        left = Math.max(0, Math.min(left, maxLeft));

        cardParams.leftMargin = left;
        cardParams.topMargin = anchorLocation[1] - rootLocation[1] + anchorView.getHeight() + yOffset;
        cardRoot.setLayoutParams(cardParams);
        overlayRoot.animate()
                .alpha(1f)
                .setDuration(FADE_DURATION_MS)
                .start();
        showing = true;
    }

    public void dismiss() {
        safeDismiss();
    }

    public boolean isShowing() {
        return showing;
    }

    private void safeDismiss() {
        if (!showing) {
            return;
        }
        if (dismissInterceptListener != null && !dismissInterceptListener.canDismiss()) {
            return;
        }
        dismissInternal(true);
    }

    private void dismissInternal(boolean notifyListener) {
        if (!showing || overlayRoot == null || hostContentRoot == null) {
            showing = false;
            return;
        }
        showing = false;
        overlayRoot.animate().cancel();
        overlayRoot.animate()
                .alpha(0f)
                .setDuration(FADE_DURATION_MS)
                .withEndAction(() -> {
                    hostContentRoot.removeView(overlayRoot);
                    overlayRoot = null;
                    hostContentRoot = null;
                    if (notifyListener && dismissInterceptListener != null) {
                        dismissInterceptListener.onDismissed();
                    }
                })
                .start();
    }

    private void rebuildList() {
        listContainer.removeAllViews();
        rowViews.clear();
        int rowSpacing = context.getResources().getDimensionPixelSize(
                R.dimen.frost_popup_menu_row_spacing);
        LayoutInflater inflater = LayoutInflater.from(context);

        for (int i = 0; i < items.size(); i++) {
            if (i > 0) {
                InsetDivider divider = new InsetDivider(context);
                divider.setInsets(0, 0);
                listContainer.addView(divider, new LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT));
            }

            InsetListRow row = (InsetListRow) inflater.inflate(
                    R.layout.frost_popup_menu_item, listContainer, false);
            LinearLayout.LayoutParams rowParams = new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT);
            if (i > 0) {
                rowParams.topMargin = rowSpacing;
            }
            if (i < items.size() - 1) {
                rowParams.bottomMargin = rowSpacing;
            }
            bindRow(row, i);
            listContainer.addView(row, rowParams);
            rowViews.add(row);
        }
    }

    private void bindRow(@NonNull InsetListRow row, int position) {
        PopupMenuItem item = items.get(position);
        ImageView iconView = row.findViewById(R.id.popup_menu_icon);
        TextView labelView = row.findViewById(R.id.popup_menu_label);
        iconView.setImageResource(item.getIconRes());
        labelView.setText(item.getLabel());
        applyRowSelection(row, labelView, position == selectedIndex);

        row.setOnClickListener(v -> {
            int previousIndex = selectedIndex;
            selectedIndex = position;
            if (previousIndex >= 0 && previousIndex < rowViews.size()) {
                InsetListRow previousRow = rowViews.get(previousIndex);
                TextView previousLabel = previousRow.findViewById(R.id.popup_menu_label);
                applyRowSelection(previousRow, previousLabel, false);
                items.get(previousIndex).setSelected(false);
            }
            applyRowSelection(row, labelView, true);
            item.setSelected(true);
            if (itemClickListener != null) {
                itemClickListener.onItemClick(item, position);
            }
        });
    }

    private void applyRowSelection(
            @NonNull InsetListRow row,
            @NonNull TextView labelView,
            boolean selected) {
        labelView.setTextColor(selected ? selectedTextColor : normalTextColor);
        ListSelectionBackgroundUtils.applyUniform(
                row,
                selected,
                selectedBackgroundColor,
                R.dimen.frost_popup_menu_item_corner_radius);
    }

    private static boolean isTouchInsideView(View view, MotionEvent event) {
        int[] location = new int[2];
        view.getLocationOnScreen(location);
        Rect bounds = new Rect(
                location[0],
                location[1],
                location[0] + view.getWidth(),
                location[1] + view.getHeight());
        return bounds.contains((int) event.getRawX(), (int) event.getRawY());
    }
}
