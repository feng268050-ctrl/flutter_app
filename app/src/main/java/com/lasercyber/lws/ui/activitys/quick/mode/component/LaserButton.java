package com.lasercyber.lws.ui.activitys.quick.mode.component;

import android.content.Context;
import android.graphics.PointF;
import android.util.AttributeSet;
import android.view.MotionEvent;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.ArrayList;
import java.util.List;

/**
 * 激光按钮，控制可点击的范围（梯形置于按钮底部）
 */
public class LaserButton extends androidx.appcompat.widget.AppCompatButton {
    // 梯形的四个顶点（按顺时针：左上、右上、右下、左下）
    private final List<PointF> trapezoidPoints = new ArrayList<>();
    // 梯形上底宽度占按钮宽度的比例（底部梯形的「上边缘」）
    private final float topWidthRatio = 0.5f;
    // 梯形下底宽度占按钮宽度的比例（底部梯形的「下边缘」，贴合按钮底部）
    private final float bottomWidthRatio = 0.93f;
    // 梯形高度占按钮高度的比例（从底部向上延伸的高度）
    private final float heightRatio = 0.8f;

    public LaserButton(@NonNull Context context) {
        super(context);
    }

    public LaserButton(@NonNull Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
    }

    public LaserButton(@NonNull Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
    }

    /**
     * 初始化梯形顶点坐标（基于 Button 尺寸动态计算，梯形置于底部）
     */
    private void initTrapezoidPoints() {
        trapezoidPoints.clear();
        float btnWidth = getWidth();
        float btnHeight = getHeight();

        // 计算底部梯形的四个顶点（中心对齐，适配不同尺寸 Button）
        // 梯形上边缘（顶部）：位于按钮底部向上偏移 (1-heightRatio)*btnHeight 的位置
        float topY = btnHeight - btnHeight * heightRatio;
        float topLeftX = btnWidth * (1 - topWidthRatio) / 2;
        float topRightX = btnWidth - topLeftX;

        // 梯形下边缘（底部）：贴合按钮最底部
        float bottomY = btnHeight;
        float bottomLeftX = btnWidth * (1 - bottomWidthRatio) / 2;
        float bottomRightX = btnWidth - bottomLeftX;

        // 按顺时针添加顶点：左上、右上、右下、左下（底部梯形）
        trapezoidPoints.add(new PointF(topLeftX, topY));       // 梯形上边缘左点
        trapezoidPoints.add(new PointF(topRightX, topY));      // 梯形上边缘右点
        trapezoidPoints.add(new PointF(bottomRightX, bottomY));// 梯形下边缘右点（按钮底部）
        trapezoidPoints.add(new PointF(bottomLeftX, bottomY)); // 梯形下边缘左点（按钮底部）
    }

    /**
     * 核心算法：判断点是否在梯形（凸四边形）内部
     * 原理：射线法 - 从点向右发射射线，与梯形边的交点数为奇数则在内部
     */
    private boolean isPointInTrapezoid(float x, float y) {
        int intersectCount = 0;
        int pointCount = trapezoidPoints.size();

        for (int i = 0; i < pointCount; i++) {
            PointF p1 = trapezoidPoints.get(i);
            PointF p2 = trapezoidPoints.get((i + 1) % pointCount);

            // 跳过水平边（无交点）
            if (p1.y == p2.y) continue;

            // 检查射线是否与当前边相交
            if ((y > Math.min(p1.y, p2.y)) && (y <= Math.max(p1.y, p2.y))) {
                // 计算交点的 X 坐标
                float intersectX = (y - p1.y) * (p2.x - p1.x) / (p2.y - p1.y) + p1.x;
                // 若交点在点的右侧，计数+1
                if (x <= intersectX) {
                    intersectCount++;
                }
            }
        }
        // 奇数个交点 = 在梯形内部
        return (intersectCount % 2) == 1;
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        // Button 未测量完成时，不处理
        if (getWidth() == 0 || getHeight() == 0) {
            return super.onTouchEvent(event);
        }

        // 初始化梯形顶点（每次触摸时更新，适配布局变化）
        initTrapezoidPoints();

        // 获取触摸点坐标（相对于 Button 自身）
        float touchX = event.getX();
        float touchY = event.getY();

        // 判断是否在梯形可点击区域内
        boolean isInTrapezoid = isPointInTrapezoid(touchX, touchY);

        // 仅在梯形内，才响应触摸事件（触发 onClick）
        if (isInTrapezoid) {
            return super.onTouchEvent(event);
        } else {
            // 超出梯形区域，不响应触摸
            return false;
        }
    }
}