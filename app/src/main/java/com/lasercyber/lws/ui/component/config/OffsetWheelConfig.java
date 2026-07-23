package com.lasercyber.lws.ui.component.config;

import com.blankj.utilcode.util.SizeUtils;
import com.lasercyber.lws.ui.bean.ui.WheelViewItem;

import lombok.Data;
import lombok.Setter;
import lombok.experimental.Accessors;

@Data
@Accessors(chain = true)
public class OffsetWheelConfig {
    /**
     * 选中的字体大小 dp
     */
    private int selectedTextSize;
    /**
     * 未选中的字体大小 dp
     */
    private int unSelectedTextSize ;
    /**
     * 选中字体的Alpha
     */
    private int selectedTextAlpha;
    /**
     * 选中文字的顶部和底部间距 dp
     */
    private int selectedTextMarginBottomTop ;
    /**
     * 选项的宽度 dp
     */
    private int wheelWidth ;
    /**
     * 选项的高度 dp
     */
    private int wheelHeight ;
    /**
     * 选项的背景
     */
    private int wheelBackgroundRes=-1;
    /**
     * 偏移方向,-1不偏移,0:左偏移,1:右偏移
     */
    private int offsetDirection = -1;
    /**
     * 未选中字体的Alpha
     */
    private UnSelectedTextAlpha unSelectedTextAlpha= (item, curPosition) -> 1;

    /**
     * 未选中选项的偏移
     */
    private UnSelectedTextOffset unSelectedTextOffset = (item, wellSelect) -> 0;


    /**
     * 左偏移
     * @return
     */
    public boolean isLeftOffset(){
        return offsetDirection==0;
    }

    /**
     * 右偏移
     */
    public boolean isRightOffset(){
        return offsetDirection==1;
    }
    public interface UnSelectedTextOffset{
        /**
         * 获取未选中的选项的偏移
         * @param item 当前选项
         * @param wellSelect 即将选中的位置
         * @return
         */
        int getUnSelectedTextOffset(WheelViewItem item, int wellSelect);
    }
    public interface UnSelectedTextAlpha{
        /**
         * 获取未选中的字体透明度
         * @param item 当前选项
         * @param curPosition 当前位置
         * @return
         */
        float getUnSelectedTextAlpha(WheelViewItem  item,int curPosition);
    }
}
