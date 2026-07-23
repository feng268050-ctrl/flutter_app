package com.lasercyber.lws.ui.common.utils.convert;

import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;

public class ProcessParametersDataConvert {
    /**
     * 将origin中的所有数据合并到target中
     * @param origin 源数据对象
     * @param target 目标数据对象
     */
    public static void mergeData(ProcessParametersData origin, ProcessParametersData target) {
        if (origin == null || target == null) {
            return;
        }

        // 基本属性
//        if (origin.getId() != null) {
//            target.setId(origin.getId());
//        }
        if (origin.getName() != null) {
            target.setName(origin.getName());
        }
        if (origin.getMaterialType() != null) {
            target.setMaterialType(origin.getMaterialType());
        }
        if (origin.getMaterialName() != null) {
            target.setMaterialName(origin.getMaterialName());
        }

        // 尺寸/厚度相关
        if (origin.getThickness() != null) {
            target.setThickness(origin.getThickness());
        }

        // 激光功率相关
        if (origin.getLaserPower() != null) {
            target.setLaserPower(origin.getLaserPower());
        }
        if (origin.getPerforationPower() != null) {
            target.setPerforationPower(origin.getPerforationPower());
        }

        // 频率相关
        if (origin.getSwingFrequency() != null) {
            target.setSwingFrequency(origin.getSwingFrequency());
        }
        if (origin.getLaserFrequency() != null) {
            target.setLaserFrequency(origin.getLaserFrequency());
        }
        if (origin.getPerforationFrequency() != null) {
            target.setPerforationFrequency(origin.getPerforationFrequency());
        }

        // 宽度相关
        if (origin.getSwingWidth() != null) {
            target.setSwingWidth(origin.getSwingWidth());
        }

        // 延时相关
        if (origin.getBlowDelay() != null) {
            target.setBlowDelay(origin.getBlowDelay());
        }
        if (origin.getCloseAirDelay() != null) {
            target.setCloseAirDelay(origin.getCloseAirDelay());
        }
        if (origin.getCloseLightDelay() != null) {
            target.setCloseLightDelay(origin.getCloseLightDelay());
        }
        if (origin.getFillDelay() != null) {
            target.setFillDelay(origin.getFillDelay());
        }
        if (origin.getWireFeedingDelay() != null) {
            target.setWireFeedingDelay(origin.getWireFeedingDelay());
        }

        // 时长相关
        if (origin.getPerforationDuration() != null) {
            target.setPerforationDuration(origin.getPerforationDuration());
        }
        if (origin.getPointWeldingInterval() != null) {
            target.setPointWeldingInterval(origin.getPointWeldingInterval());
        }
        if (origin.getPointWeldingDuration() != null) {
            target.setPointWeldingDuration(origin.getPointWeldingDuration());
        }

        // 功率缓升缓降相关
        if (origin.getPowerRampUp() != null) {
            target.setPowerRampUp(origin.getPowerRampUp());
        }
        if (origin.getPowerRampDown() != null) {
            target.setPowerRampDown(origin.getPowerRampDown());
        }

        // 送丝/回抽相关
        if (origin.getWireFeedSpeed() != null) {
            target.setWireFeedSpeed(origin.getWireFeedSpeed());
        }
        if (origin.getRetractLength() != null) {
            target.setRetractLength(origin.getRetractLength());
        }
        if (origin.getRetractSpeed() != null) {
            target.setRetractSpeed(origin.getRetractSpeed());
        }
        if (origin.getFillLength() != null) {
            target.setFillLength(origin.getFillLength());
        }

        // 激光占空比字段
        if (origin.getLaserDutyCycle() != null) {
            target.setLaserDutyCycle(origin.getLaserDutyCycle());
        }
        if (origin.getPerforationDutyCycle() != null) {
            target.setPerforationDutyCycle(origin.getPerforationDutyCycle());
        }

        // 工艺类型相关
        if (origin.getProcessType() != null) {
            target.setProcessType(origin.getProcessType());
        }
        if (origin.getDataType() != null) {
            target.setDataType(origin.getDataType());
        }
        if (origin.getOriginId() != null) {
            target.setOriginId(origin.getOriginId());
        }
        if (origin.getGear() != null) {
            target.setGear(origin.getGear());
        }
    }
}