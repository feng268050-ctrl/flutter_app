package com.lasercyber.lws.ui.common.utils;

import java.util.ArrayList;
import java.util.List;

public class PickerDataUtils {
    /**
     * 创建功率缓升数据列表
     * @param unit 单位
     * @return 功率缓升选项列表
     */
    public static List<String> createPowerRampUpList(String unit){
        return List.of(
                "10000 "+unit,
                "7500 "+unit,
                "5000 "+unit,
                "2500 "+unit,
                "0 "+unit
        );
    }

    /**
     * 创建焊接功率数据列表
     * @param unit 单位
     * @return 焊接功率选项列表
     */
    public static List<String> createWeldingPowerList(String unit) {
        return List.of(
                "100 "+unit,
                "75 "+unit,
                "50 "+unit,
                "25 "+unit,
                "0 "+unit
        );
    }

    /**
     * 创建功率下降数据列表
     * @param unit 单位
     * @return 功率下降选项列表
     */
    public static List<String> createPowerDescentList(String unit) {
        return List.of(
                "10000 "+unit,
                "7500 "+unit,
                "5000 "+unit,
                "2500 "+unit,
                "0 "+unit
        );
    }

    /**
     * 创建气关闭延迟数据列表
     * @param unit 单位
     * @return 气关闭延迟选项列表
     */
    public static List<String> createAirOffDelayList(String unit) {
        return List.of(
                "10000 "+unit,
                "7500 "+unit,
                "5000 "+unit,
                "2500 "+unit,
                "0 "+unit
        );
    }

    /**
     * 创建摆动频率数据列表
     * @param unit 单位
     * @return 摆动频率选项列表
     */
    public static List<String> createOscillationFrequencyList(String unit) {
        return List.of(
                "200 "+unit,
                "150 "+unit,
                "100 "+unit,
                "50 "+unit,
                "0 "+unit
        );
    }

    /**
     * 创建焊接宽度数据列表
     * @param unit 单位
     * @return 焊接宽度选项列表
     */
    public static List<String> createWeldWidthList(String unit,Boolean useMMUnit) {
        double[] arr={6,5,4,3,2,1};
        ArrayList<String> list = new ArrayList<>();
        for (double d : arr) {
            list.add((useMMUnit ? d : InchMillimeterUtils.mmToInStr(d)) + " " + unit);
        }
        return list;
    }

    /**
     * 创建送丝速度数据列表
     * @param unit 单位
     * @return 送丝速度选项列表
     */
    public static List<String> createWireFeedSpeedList(String unit,Boolean useMMUnit) {
        double[] arr={50,40,30,20,10,0};
        ArrayList<String> list = new ArrayList<>();
        for (double d : arr) {
            list.add((useMMUnit ? d : InchMillimeterUtils.mmToInStr(d)) + " " + unit);
        }
        return list;
    }

    /**
     * 创建关光延时数据列表
     * @param unit 单位
     * @return 停机延迟选项列表
     */
    public static List<String> createShutdownDelayList(String unit) {
        return List.of(
                "10000 "+unit,
                "7500 "+unit,
                "5000 "+unit,
                "2500 "+unit,
                "0 "+unit
        );
    }

    /**
     * 创建回抽长度数据列表
     * @param unit 单位
     * @return 回抽长度选项列表
     */
    public static List<String> createPullbackLengthList(String unit,Boolean useMMUnit) {
        double[] arr={20,15,10,5,0};
        ArrayList<String> list = new ArrayList<>();
        for (double d : arr) {
            list.add((useMMUnit ? d : InchMillimeterUtils.mmToInStr(d)) + " " + unit);
        }
        return list;
    }

    /**
     * 创建回抽速度数据列表
     * @param unit 单位
     * @return 回抽速度选项列表
     */
    public static List<String> createPullbackSpeedList(String unit,Boolean useMMUnit) {
        double[] arr={300,200,150,100,50,0};
        ArrayList<String> list = new ArrayList<>();
        for (double d : arr) {
            list.add((useMMUnit ? d : InchMillimeterUtils.mmToInStr(d)) + " " + unit);
        }
        return list;
    }

    /**
     * 创建修复丝长度数据列表
     * @param unit 单位
     * @return 修复丝长度选项列表
     */
    public static List<String> createRepairWireLengthList(String unit,Boolean useMMUnit) {
        double[] arr={15,10,5,0};
        ArrayList<String> list = new ArrayList<>();
        for (double d : arr) {
            list.add((useMMUnit ? d : InchMillimeterUtils.mmToInStr(d)) + " " + unit);
        }
        return list;
    }

    /**
     * 创建修复丝延迟数据列表
     * @param unit 单位
     * @return 修复丝延迟选项列表
     */
    public static List<String> createRepairWireDelayList(String unit) {
        return List.of(
                "10000 "+unit,
                "7500 "+unit,
                "5000 "+unit,
                "2500 "+unit,
                "0 "+unit
        );
    }

    /**
     * 创建点焊间隔
     * @param unit
     * @return
     */
    public static List<String> createWeldingIntervalList(String unit) {
        return List.of(
                "10000 "+unit,
                "7500 "+unit,
                "5000 "+unit,
                "2500 "+unit,
                "0 "+unit
        );
    }

    /**
     * 创建点焊持续
     * @param unit
     * @return
     */
    public static List<String> createWeldingDurationList(String unit) {
        return List.of(
                "10000 "+unit,
                "7500 "+unit,
                "5000 "+unit,
                "2500 "+unit,
                "0 "+unit
        );
    }

    /**
     * 激光占空比
     * @param unit
     * @return
     */
    public static List<String> createLaserDutyCycleList(String unit) {
        return List.of(
                "100 "+unit,
                "75 "+unit,
                "50 "+unit,
                "25 "+unit,
                "0 "+unit
        );
    }

    /**
     * 吹气延时
     * @param unit
     * @return
     */
    public static List<String> createBlowDelayList(String unit) {
        return List.of(
                "10000 "+unit,
                "7500 "+unit,
                "5000 "+unit,
                "2500 "+unit,
                "0 "+unit
        );
    }

    /**
     * 关气延时
     * @param unit
     * @return
     */
    public static List<String> createCloseAirDelayList(String unit) {
        return List.of(
                "10000 "+unit,
                "7500 "+unit,
                "5000 "+unit,
                "2500 "+unit,
                "0 "+unit
        );
    }

    /**
     * 穿孔频率
     * @param unit
     * @return
     */
    public static List<String> createPerforationFrequencyList(String unit) {
        return List.of(
                "2000 "+unit,
                "1500 "+unit,
                "1000 "+unit,
                "500 "+unit,
                "0 "+unit
        );
    }

    /**
     * 穿孔时长
     * @param unit
     * @return
     */
    public static List<String> createPerforationDurationList(String unit) {
        return List.of(
                "2.0 "+unit,
                "1.5 "+unit,
                "1.0 "+unit,
                "0.1 "+unit,
                "0 "+unit
        );
    }
}