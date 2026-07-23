package com.lasercyber.lws.ui.activitys.engineer.mode.ui;

import android.content.Context;

import androidx.annotation.Nullable;

import com.blankj.utilcode.util.SizeUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.engineer.mode.component.DataListPopup;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersNameData;
import com.lasercyber.lws.ui.bean.ui.DataListPopupItem;
import com.lasercyber.lws.ui.common.utils.DataListPopupUtils;
import com.lasercyber.lws.ui.component.InterceptablePopupWindow;

import java.util.List;

public class DataPopupBuilder {
    private static final int POPUP_LIST_WIDTH_DP = 350;
    private static final int GAP_BELOW_ANCHOR_DP = 4;

    /**
     * 构建更多参数的弹窗
     */
    public static DataListPopup moreCommonBuilder(String nowParamsName,
                                                  List<ProcessParametersNameData> processParametersDataList,
                                                  Context context,
                                                  @Nullable Integer modelType,
                                                  DataListPopupClose dataListPopupClose) {
        DataListPopup mDataListPopup = new DataListPopup(context);
        mDataListPopup.setModelType(modelType);
        mDataListPopup.setYOffset(SizeUtils.dp2px(GAP_BELOW_ANCHOR_DP));
        mDataListPopup.setContentWidth(POPUP_LIST_WIDTH_DP, 434);
        List<DataListPopupItem> materialList =
                DataListPopupUtils.createMoreCommon(nowParamsName, processParametersDataList);
        mDataListPopup.setMaterialList(materialList, R.color.white, (bean, position) -> {
            dataListPopupClose.close(mDataListPopup, bean);
        });
        mDataListPopup.dismissInterceptListener(new InterceptablePopupWindow.OnDismissInterceptListener() {
            @Override
            public boolean canDismiss() {
                return true;
            }

            @Override
            public void onDismissed() {
                dataListPopupClose.close(mDataListPopup, null);
            }
        });
        return mDataListPopup;
    }

    /**
     * 构建材质弹窗
     */
    public static DataListPopup materialsBuilder(String materials,
                                                 Context context,
                                                 @Nullable Integer modelType,
                                                 DataListPopupClose dataListPopupClose) {
        DataListPopup mDataListPopup = new DataListPopup(context);
        mDataListPopup.setModelType(modelType);
        mDataListPopup.setYOffset(SizeUtils.dp2px(GAP_BELOW_ANCHOR_DP));
        mDataListPopup.setContentWidth(POPUP_LIST_WIDTH_DP, 334);
        List<DataListPopupItem> materialList = DataListPopupUtils.createMaterialList(materials);
        mDataListPopup.setMaterialList(materialList, R.color.white, (bean, position) -> {
            dataListPopupClose.close(mDataListPopup, bean);
        });
        mDataListPopup.dismissInterceptListener(new InterceptablePopupWindow.OnDismissInterceptListener() {
            @Override
            public boolean canDismiss() {
                return true;
            }

            @Override
            public void onDismissed() {
            }
        });
        return mDataListPopup;
    }

    public interface DataListPopupClose {
        void close(DataListPopup dataListPopup, DataListPopupItem dataListPopupItem);
    }
}
