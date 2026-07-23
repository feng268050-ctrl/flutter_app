package com.lasercyber.lws.ui.bean.entity;

import android.content.Context;
import android.content.res.Resources;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.utils.StringUtils;
import com.lasercyber.lws.ui.common.utils.WireConsumptionDisplayUtil;
import com.lasercyber.lws.ui.common.utils.convert.EngineerWashConvert;
import com.lasercyber.lws.ui.common.utils.web.HomeLayoutUtils;

import java.util.ArrayList;
import java.util.List;

import cn.hutool.core.convert.Convert;
import lombok.Data;

/*首页实体对象*/
@Data
public class Home {

    private List<HomeStatic> list = new ArrayList<>();

    /* 快速模式*/
    private String spModel;
    /* 工程师模式*/
    private String pjModel;
    /* 检测*/
    private String monitor;
    /* 设置*/
    private String config;


    /*构建基础对象数据
     * hc 默认查询对象的类型
     * data 数据库中的查询值
     * commonUse 耗材型号枚举，需要转换
     * */
    public void buildHome(Context context, List<CustomLayout> listCustomLayout, StaticData data, Integer commonUse, String unitWireValue) {
        /* 左侧4格统计内容 */
        initStaticHome(listCustomLayout.get(0), context, data, commonUse, unitWireValue);
        initStaticHome(listCustomLayout.get(1), context, data, commonUse, unitWireValue);
        initStaticHome(listCustomLayout.get(2), context, data, commonUse, unitWireValue);
        initStaticHome(listCustomLayout.get(3), context, data, commonUse, unitWireValue);

        Resources res = context.getResources();
        /*右侧四项描述 , 这个基本不变*/
        spModel = res.getString(R.string.quick_mode_text);
        pjModel = res.getString(R.string.engineer_mode_text);
        monitor = res.getString(R.string.device_monitor_home_title);
        config = res.getString(R.string.device_setting_home_text);
    }

    /*构建首页初始化数据格式*/
    private void initStaticHome(CustomLayout customLayout, Context context, StaticData data, Integer commonUse, String unitWireValue) {
        HomeStatic homeStatic = new HomeStatic();
        String info = null, number = null;
        Integer type = customLayout.getType();

        String title = HomeLayoutUtils.typeToTitle(type, context);
        /*焊接耗材总计*/
        if (type == HomeLayoutUtils.materialsLength) {
            WireConsumptionDisplayUtil.DisplayValue displayValue =
                    WireConsumptionDisplayUtil.format(data.getConsumableTimeLength(), unitWireValue);
            number = displayValue.getNumber();
            info = displayValue.getUnit();
        }

        /* 出光总时长 */
        if (type == HomeLayoutUtils.lightLength) {
            info = " h";
            number = ((data.getWeldingTimeLength() + data.getCuttingTimeLength() + data.getWashTimeLength()) / 3600) + "";
        }

        /*常用材料*/
        if (type == HomeLayoutUtils.commonMaterials) {
            info = "";
            number = getCommonUse(commonUse);
        }

        /*较上周增加出光时长*/
        if (type == HomeLayoutUtils.comparedToLastWeek) {
            info = " %";
            number = getLightTimeRatio(data);
        }

        /*工作时长*/
        if (type == HomeLayoutUtils.jobLength) {
            info = " min";
            number = (data.getJobTimeLength() / 60) + "";
        }

        /*焊接总占比*/
        if (type == HomeLayoutUtils.weldingRatio) {
            this.newRatio(data, homeStatic, type);
        }
        /*切割总占比*/
        if (type == HomeLayoutUtils.cuttingRatio) {
            this.newRatio(data, homeStatic, type);
        }
        /*清洗总占比*/
        if (type == HomeLayoutUtils.rinseRatio) {
            this.newRatio(data, homeStatic, type);
        }

        homeStatic.setType(type);
        homeStatic.setStaticTitle(title);
        if (null == homeStatic.getStaticNumber()) {
            homeStatic.setStaticNumber(number);
        }
        homeStatic.setStaticInfo(info);
        list.add(homeStatic);
    }

    /*构建基础对象数据
     * hc 默认查询对象的类型
     * data 数据库中的查询值
     * commonUse 耗材型号枚举，需要转换
     * */
    public void build(Resources res, HomeConfig hc, StaticData data, String unitWireValue) {
        /* 左侧4格统计内容 */
        initStatic(hc.getStaticOne(), res, data, unitWireValue);
        initStatic(hc.getStaticTwo(), res, data, unitWireValue);
        initStatic(hc.getStaticThree(), res, data, unitWireValue);
        initStatic(hc.getStaticFour(), res, data, unitWireValue);
    }

    /*初始化统计配置
       index 默认查询对象的类型
       res 上下文， 用以获取枚举
    * staticData 数据库中的查询值
    * commonUse 耗材型号枚举，需要转换
    * */
    private void initStatic(Integer index, Resources res, StaticData data, String unitWireValue) {
        HomeStatic homeStatic = new HomeStatic();
        String title = null, info = null, number = null;

        /*出光总时长*/
        if (index == 1) {
            title = res.getString(R.string.warn_info_light_time);
            number = ((data.getWeldingTimeLength() + data.getCuttingTimeLength() + data.getWashTimeLength()) / 3600) + "";
            info = " h";
            addListData(homeStatic, HomeLayoutUtils.lightLength, title, info, number);
        }

        /*焊接耗材总计*/
        if (index == 2) {
            title = res.getString(R.string.warn_info_welding_consumables);
            WireConsumptionDisplayUtil.DisplayValue displayValue =
                    WireConsumptionDisplayUtil.format(data.getConsumableTimeLength(), unitWireValue);
            number = displayValue.getNumber();
            info = displayValue.getUnit();
            addListData(homeStatic, HomeLayoutUtils.materialsLength, title, info, number);
        }

        if (index == 3) {
            title = res.getString(R.string.warn_info_last_work);
            number = (data.getJobTimeLength() / 60) + "";
            info = " min";
            addListData(homeStatic, HomeLayoutUtils.jobLength, title, info, number);
        }

        /*统计占比图形*/
        if (index == 4) {
            title = res.getString(R.string.welding_proportion_text);
            this.newRatio(data, homeStatic, HomeLayoutUtils.weldingRatio);
            addListData(homeStatic, HomeLayoutUtils.weldingRatio, title, info, number);

            /*切割总占比*/
            HomeStatic homeStatic1 = new HomeStatic();
            title = res.getString(R.string.cutting_proportion_text);
            this.newRatio(data, homeStatic1, HomeLayoutUtils.cuttingRatio);
            addListData(homeStatic1, HomeLayoutUtils.cuttingRatio, title, info, number);
            list.add(homeStatic1);

            /*清洗总占比*/
            HomeStatic homeStatic2 = new HomeStatic();
            title = res.getString(R.string.wash_proportion_text);
            this.newRatio(data, homeStatic2, HomeLayoutUtils.rinseRatio);
            addListData(homeStatic2, HomeLayoutUtils.rinseRatio, title, info, number);
            list.add(homeStatic2);
        }

        list.add(homeStatic);
    }

    private void addListData(HomeStatic homeStatic, int type, String title, String info, String number) {
        homeStatic.setType(type);
        if (null != title) {
            homeStatic.setStaticTitle(title);
        }
        if (null != number) {
            homeStatic.setStaticNumber(number);
        }
        if (null != info) {
            homeStatic.setStaticInfo(info);
        }
    }


    /*创建一个 统计图形对象*/
    private void newRatio(StaticData data, HomeStatic homeStatic, Integer type) {

        Long sum = isNullOr0(data.getWeldingTimeLength()) + isNullOr0(data.getCuttingTimeLength()) + isNullOr0(data.getWashTimeLength());

        /*判断，数值为0则不统计*/
        if (sum == 0) {
            homeStatic.setStaticNumber("0");
        } else {

            if (type == HomeLayoutUtils.weldingRatio) {
                if (data.getWeldingTimeLength() > 0) {
                    homeStatic.setStaticNumber(Convert.toInt(Convert.toDouble(data.getWeldingTimeLength()) / Convert.toDouble(sum) * 100) + "");
                } else {
                    homeStatic.setStaticNumber("0");
                }
            }
            /*切割总占比*/
            if (type == HomeLayoutUtils.cuttingRatio) {
                if (data.getCuttingTimeLength() > 0) {
                    homeStatic.setStaticNumber(Convert.toInt(Convert.toDouble(data.getCuttingTimeLength()) / Convert.toDouble(sum) * 100) + "");
                } else {
                    homeStatic.setStaticNumber("0");
                }
            }
            /*清洗总占比*/
            if (type == HomeLayoutUtils.rinseRatio) {
                if (data.getWashTimeLength() > 0) {
                    homeStatic.setStaticNumber(Convert.toInt(Convert.toDouble(data.getWashTimeLength()) / Convert.toDouble(sum) * 100) + "");
                } else {
                    homeStatic.setStaticNumber("0");
                }
            }

        }
    }

    /*计算出光时长比例*/
    private String getLightTimeRatio(StaticData data) {

        /*上周没有时间 */
        if (null == data.getTopStartTime() || data.getTopStartTime() == 0) {
            if (data.getCurrStartTime() > 0) {
                return "100";
            }
            return "0";
        }
        /*否则判断比例*/
        else {
            Long top = data.getCurrStartTime() - data.getTopStartTime(); //上周时间 = 当前周开始时间 - 上周开始时间
            Long number = data.getWeldingTimeLength() + data.getCuttingTimeLength() + data.getWashTimeLength();
            Long curr = number - data.getCurrStartTime(); //本周时间
            //上周没开机，本周已启用， 100%
            if (top == 0 && curr > 0) {
                return "100";
            }
            /* 上周等于本周， 0%*/
            if (top == curr) {
                return "0";
            }
            //计算上周大于本周的 负数
            if (top > curr) {
                Integer val = Math.toIntExact((top / curr - 1) * 100);
                return "-" + val;
            }
            //计算本周大于上周的 正数
            if (curr > top) {
                Integer val = Math.toIntExact((curr / top - 1) * 100);
                return val + "";
            }
        }
        return "0%";
    }

    /*判空，如果是空则赋值0*/
    private Long isNullOr0(Long number) {
        if (null == number) {
            return 0L;
        }
        return number;
    }

    /*换算常用耗材枚举*/
    private String getCommonUse(Integer commonUse) {
        return EngineerWashConvert.convertCleaningMaterialsText(commonUse);
    }
}
