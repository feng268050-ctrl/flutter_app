package com.lasercyber.lws.ui.common.utils.web;

import android.content.Context;
import android.content.res.Resources;

import com.lasercyber.lws.ui.R;

public class HomeLayoutUtils {

    public static Integer materialsLength = 1; //焊接材料长度总计

    public static Integer lightLength = 2;//出光总时长

    public static Integer jobLength = 3; //工作时长

    public static Integer weldingRatio = 4; //焊接总比例

    public static Integer cuttingRatio = 5; //切割总占比

    public static Integer rinseRatio = 6; //清洗总占比

    public static Integer comparedToLastWeek = 7; //较上周增加出光时长

    public static Integer commonMaterials = 8; //常用材料


    public static String typeToTitle(int type, Context context){
        Resources res = context.getResources();
        String title ="";
        if ( type == HomeLayoutUtils.materialsLength ) {
            title = res.getString(R.string.warn_info_welding_consumables);
        }
        if ( type == HomeLayoutUtils.lightLength ) {
            title = res.getString(R.string.warn_info_light_time);
        }
        if( type == HomeLayoutUtils.commonMaterials) {
            title = res.getString(R.string.warn_info_welding_consumables_info);
        }
        if( type == HomeLayoutUtils.comparedToLastWeek) {
            title = res.getString(R.string.warn_info_light_time_info);
        }
        if ( type == HomeLayoutUtils.jobLength ) {
            title = res.getString(R.string.warn_info_last_work);
        }
        if ( type == HomeLayoutUtils.weldingRatio ) {
            title = res.getString(R.string.welding_proportion_text);
        }
        if ( type == HomeLayoutUtils.cuttingRatio ) {
            title = res.getString(R.string.cutting_proportion_text);
        }
        if ( type == HomeLayoutUtils.rinseRatio ) {
            title = res.getString(R.string.wash_proportion_text);
        }
        return title;
    }

}
