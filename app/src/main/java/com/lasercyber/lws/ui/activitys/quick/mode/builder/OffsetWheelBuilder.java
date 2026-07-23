package com.lasercyber.lws.ui.activitys.quick.mode.builder;

import com.blankj.utilcode.util.SizeUtils;
import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.component.config.OffsetWheelConfig;
import com.lasercyber.lws.ui.component.wheelview.widget.WheelView;

public class OffsetWheelBuilder {
    private static final String TAG = LogTAGConstant.OffsetWheelBuilder;

    public static void builderBasedWheelViewStyle(WheelView wheelView) {
        WheelView.WheelViewStyle wheelViewStyle = new WheelView.WheelViewStyle();
        wheelViewStyle.backgroundColor = Utils.getApp().getResources().getColor(android.R.color.transparent);
        wheelViewStyle.holoBorderColor = Utils.getApp().getResources().getColor(android.R.color.transparent);
        wheelViewStyle.textSize = SizeUtils.dp2px(24);
        wheelViewStyle.selectedTextSize = SizeUtils.dp2px(28);

        wheelView.setStyle(wheelViewStyle);
        wheelView.setSkin(WheelView.Skin.None);
        wheelView.setWheelSize(9);
        wheelView.setClickToPosition(true);
    }

    /**
     * 构建模式的偏移适配器的配置
     *
     * @return
     */
    public static OffsetWheelConfig builderOffsetModelOffset() {
        return new OffsetWheelConfig()
                .setSelectedTextSize(28)
                .setUnSelectedTextSize(24)
                .setSelectedTextAlpha(1)
                .setSelectedTextMarginBottomTop(24)
                .setWheelWidth(260)
                .setWheelHeight(68)
                .setOffsetDirection(1)
                .setUnSelectedTextAlpha((item, curPosition) -> Math.max(1 - Math.abs(item.getPosition() - curPosition) * 0.2f, 0.4f))
                .setUnSelectedTextOffset((item, wellSelect) -> SizeUtils.dp2px(Math.abs(item.getPosition() - wellSelect) * 10 + 24))
                ;

    }

    /**
     * 构建材质的偏移适配器的配置
     *
     * @return
     */
    public static OffsetWheelConfig builderOffsetMaterialsOffset() {
        return builderOffsetModelOffset()
                .setOffsetDirection(0);

    }

    /**
     * 构建档位的偏移配置
     *
     * @return
     */
    public static OffsetWheelConfig builderOffsetGearOffset() {
        return new OffsetWheelConfig()
                .setSelectedTextSize(28)
                .setUnSelectedTextSize(24)
                .setSelectedTextAlpha(1)
                .setSelectedTextMarginBottomTop(24)
                .setWheelWidth(140)
                .setWheelHeight(68)
                .setOffsetDirection(1)
                .setUnSelectedTextAlpha((item, curPosition) -> Math.max(1 - Math.abs(item.getPosition() - curPosition) * 0.2f, 0.4f))
                .setUnSelectedTextOffset((item, wellSelect) -> {
                    // 需要根据三角函数来进行计算
                    return SizeUtils.dp2px(Math.abs(item.getPosition() - wellSelect)*Math.abs(item.getPosition() - wellSelect)*8+24);
                })
                ;

    }
    /**
     * 构建厚度的偏移配置
     * @return
     */
    public static OffsetWheelConfig builderOffsetThicknessOffset(){
        return builderOffsetGearOffset().setOffsetDirection(0);
//                .setWheelBackgroundRes(android.R.color.holo_green_light);
    }

}
