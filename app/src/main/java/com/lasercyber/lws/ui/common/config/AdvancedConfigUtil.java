package com.lasercyber.lws.ui.common.config;

import com.lasercyber.lws.ui.bean.entity.vo.AdvancedSettingVo;

import java.util.Objects;

import cn.hutool.core.convert.Convert;


public class AdvancedConfigUtil {

    /*校验参数*/
    public static Boolean verifyData(String filedName, AdvancedSettingVo vo, Integer min, Integer max){
        Integer value = 0;
        if(filedName.equals("zeroPointCorrection")){
            String zeroPointCorrection = vo.getZeroPointCorrection();
            value = Convert.toInt(zeroPointCorrection);
        }
        if(filedName.equals("properSwingWidth")){
            String zeroPointCorrection = vo.getProperSwingWidth();
            value = Convert.toInt(zeroPointCorrection);
        }
        if(filedName.equals("laserStartPower")){
            String zeroPointCorrection = vo.getLaserStartPower();
            value = Convert.toInt(zeroPointCorrection);
        }
        if(filedName.equals("laserEndPower")){
            String zeroPointCorrection = vo.getLaserEndPower();
            value = Convert.toInt(zeroPointCorrection);
        }
        if(filedName.equals("blowPressureThreshold")){
            String zeroPointCorrection = vo.getBlowPressureThreshold();
            value = Convert.toInt(zeroPointCorrection);
        }
        if (Objects.equals(filedName, "manualDrawStringSpeed")) {
            String manualDrawStringSpeed = vo.getManualDrawStringSpeed();
            value = Convert.toInt(manualDrawStringSpeed);
        }

        if( value < min || value > max ){
            return false;
        }

        return true;
    }


}
