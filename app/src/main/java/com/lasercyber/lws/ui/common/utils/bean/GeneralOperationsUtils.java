package com.lasercyber.lws.ui.common.utils.bean;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.ui.GeneralOperations;
import com.lasercyber.lws.ui.common.constant.ModelConstant;

public class GeneralOperationsUtils {
    /**
     * 创建默认的通用操作
     * @return
     */
    public static GeneralOperations createDefaultGeneralOperations(){
        GeneralOperations generalOperations = new GeneralOperations();
        generalOperations.setFeedVisible(true);
        generalOperations.setRetractVisible(true);
        generalOperations.setFeedEnableVisible(true);
        generalOperations.setManualGasVisible(true);
        generalOperations.setLaserEnableVisible(true);
        return generalOperations;
    }

    /**
     * 激光清洗-焊道清洗
     * @return
     */
    public static GeneralOperations createWashWeldCleaning(){
//        Locale locale = LanguageUtils.getAppContextLanguage();
        GeneralOperations generalOperations = createDefaultGeneralOperations();
        generalOperations.setFeedVisible(false);
        generalOperations.setRetractVisible(false);
        generalOperations.setFeedEnableVisible(false);
        generalOperations.setBackGroundRes(R.drawable.quick_mode_wheel_active_green);
        generalOperations.setType(ModelConstant.WELD_CLEAN);
        return generalOperations;
    }
    /**
     * 激光清洗-宽幅清洗
     */
    public static GeneralOperations createWashWidthCleaning(){
        GeneralOperations generalOperations = createDefaultGeneralOperations();
        generalOperations.setFeedVisible(false);
        generalOperations.setRetractVisible(false);
        generalOperations.setFeedEnableVisible(false);
        generalOperations.setBackGroundRes(R.drawable.quick_mode_wheel_active_green);
        generalOperations.setType(ModelConstant.WIDTH_CLEAN);
        return generalOperations;
    }
    /**
     * 激光焊接-连续焊接
     */
    public static GeneralOperations createWeldingContinuousWelding(){
        GeneralOperations generalOperations = createDefaultGeneralOperations();
        generalOperations.setBackGroundRes(R.drawable.quick_mode_wheel_active_orange);
        generalOperations.setType(ModelConstant.CONTINUOUS_WELDING);
        return generalOperations;
    }
    /**
     * 激光焊接-点焊接
     */
    public static GeneralOperations createWeldingPointWelding(){
        GeneralOperations generalOperations = createDefaultGeneralOperations();
        generalOperations.setFeedVisible(false);
        generalOperations.setRetractVisible(false);
        generalOperations.setFeedEnableVisible(false);
        generalOperations.setBackGroundRes(R.drawable.quick_mode_wheel_active_orange);
        generalOperations.setType(ModelConstant.POINT_WELDING);
        return generalOperations;
    }
    /**
     * 激光切割-手持切割
     */
    public static GeneralOperations createCuttingHandHeldCutting(){
        GeneralOperations generalOperations = createDefaultGeneralOperations();
        generalOperations.setFeedVisible(false);
        generalOperations.setRetractVisible(false);
        generalOperations.setFeedEnableVisible(false);
        generalOperations.setBackGroundRes(R.drawable.quick_mode_wheel_active_blue);
        generalOperations.setType(ModelConstant.HAND_CUT);
        return generalOperations;
    }
}
