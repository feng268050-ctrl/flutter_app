package com.lasercyber.lws.ui.common.utils;

import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersNameData;
import com.lasercyber.lws.ui.bean.ui.DataListPopupItem;
import com.lasercyber.lws.ui.common.utils.convert.EngineerWeldingConvert;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

public class DataListPopupUtils {
    /**
     * 创建材质列表
     * @param materials
     * @return
     */
    public static List<DataListPopupItem> createMaterialList(String materials) {
        List<DataListPopupItem> materialList = new ArrayList<>();
        String stainlessSteel = Utils.getApp().getString(R.string.stainless_steel_text);
        String carbonSteel = Utils.getApp().getString(R.string.carbon_steel_text);
        String galvanizedSheet = Utils.getApp().getString(R.string.galvanized_sheet_text);
        String aluminumAlloy = Utils.getApp().getString(R.string.aluminum_alloy_text);
        String brass = Utils.getApp().getString(R.string.brass_text);
        String customize = Utils.getApp().getString(R.string.customize_text);

        materialList.add(new DataListPopupItem(R.mipmap.stainless_steel_icon,  stainlessSteel, Objects.equals(materials,stainlessSteel)));
        materialList.add(new DataListPopupItem(R.mipmap.carbon_steel_icon, carbonSteel, Objects.equals(materials,carbonSteel)));
        materialList.add(new DataListPopupItem(R.mipmap.galvanized_sheet_icon, galvanizedSheet, Objects.equals(materials,galvanizedSheet)));  // 默认选中
        materialList.add(new DataListPopupItem(R.mipmap.aluminum_alloy_icon,aluminumAlloy, Objects.equals(materials,aluminumAlloy)));
        materialList.add(new DataListPopupItem(R.mipmap.brass_icon, brass,Objects.equals(materials,brass)));
        materialList.add(new DataListPopupItem(R.mipmap.customize_icon, customize,Objects.equals(materials,customize)));
        return materialList;
    }

    /**
     * 生成更多工艺的列表
     * @param parameterName current parameter display name for matching
     * @param processParametersDataList
     * @return
     */
    public static List<DataListPopupItem> createMoreCommon(String parameterName, List<ProcessParametersNameData> processParametersDataList) {
        List<DataListPopupItem> materialList = new ArrayList<>();
        if (processParametersDataList==null){
            return materialList;
        }
        for (ProcessParametersNameData processParametersData : processParametersDataList) {
            Integer icon = EngineerWeldingConvert.convertMaterialsIcon(processParametersData.getMaterialType());
            int iconRes = icon != null ? icon : R.mipmap.customize_icon;
            String displayName = MaterialDisplayNameUtils.localizeKnownMaterialName(
                    processParametersData.getName(),
                    processParametersData.getMaterialType()
            );
            DataListPopupItem dataListPopupItem = new DataListPopupItem(iconRes,
                    displayName,
                    Objects.equals(parameterName, displayName)
            );
            dataListPopupItem.setId(processParametersData.getId());
            dataListPopupItem.setDataType(processParametersData.getDataType());
            dataListPopupItem.setProcessType(processParametersData.getProcessType());
            materialList.add(dataListPopupItem);
        }
        return materialList;
    }
}
