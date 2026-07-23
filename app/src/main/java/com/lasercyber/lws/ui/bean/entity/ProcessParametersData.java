package com.lasercyber.lws.ui.bean.entity;

import androidx.room.Entity;
import androidx.room.PrimaryKey;

import com.lasercyber.lws.ui.bean.push.ServerPushPayload;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.constant.ProcessDataType;

import lombok.Data;

@Data
@Entity(tableName = "t_process_parameters_data")
public class ProcessParametersData implements Cloneable, ServerPushPayload {
    @PrimaryKey(autoGenerate = true)
    private Long id;
    /**
     * 参数名称
     */
    private String name;
    /**
     * 材料类型代码
     */
    private Integer materialType;
    /**
     * 材质名称，用于自定义材质
     */
    private String materialName;

    // 尺寸/厚度相关字段
    /**
     * 厚度
     */
    private Double thickness;

    // 激光功率相关字段
    private Integer laserPower;        // 激光功率（0~100%）
    /**
     * 穿孔功率 0~100%
     */
    @Deprecated
    private Integer perforationPower;

    // 频率相关字段
    private Integer swingFrequency;    // 摆动频率（清洗：20~200Hz；焊接：0~220Hz）
    @Deprecated
    private Integer laserFrequency;    // 激光频率（1~5000Hz）
    @Deprecated
    private Integer perforationFrequency; // 穿孔频率（0~2000Hz）

    // 宽度相关字段
    private Double swingWidth;        // 摆动宽度（0~6mm）

    // 延时相关字段
    private Integer blowDelay;         // 吹气延时（0~10000ms）
    private Integer closeAirDelay;     // 关气延时（0~10000ms）
    private Integer closeLightDelay;   // 关光延时（0~1000ms）
    private Integer fillDelay;         // 补丝时延（0~1000ms）
    @Deprecated
    private Integer wireFeedingDelay;       // 送丝时延（0~2000ms）

    // 时长相关字段
    @Deprecated
    private Double perforationDuration; // 穿孔时长(0.1~2.0s)
    private Integer pointWeldingInterval; // 点焊间隔（0~10000ms）
    private Integer pointWeldingDuration; // 点焊持续（0~10000ms）

    // 功率缓升缓降相关字段
    private Integer powerRampUp;       // 功率缓升（0~1000ms）
    private Integer powerRampDown;     // 功率缓降（0~1000ms）

    // 送丝/回抽相关字段
    private Double wireFeedSpeed;     // 送丝速度（0~50mm/s）
    private Double retractLength;     // 回抽长度（0~35mm）
    private Double retractSpeed;      // 回抽速度（3~100mm/s）
    private Double fillLength;        // 补丝长度（0~35mm）

    // 激光占空比字段 单位（0.01%）
    @Deprecated
    private Integer laserDutyCycle;    // 激光占空比（0~100%）
    /**
     * 穿孔占空比 0~100%
     */
    @Deprecated
    private Integer perforationDutyCycle;

    /**
     * 工艺类型
     * {@link ModelConstant}
     */
    private Integer processType;
    /**
     * 数据类型：0 快速模式参数；1 工程师模式内置参数；2 工程师模式自定义参数；3 视频工艺参数（废弃）。
     * {@link ProcessDataType}
     */
    private Integer dataType;
    /**
     * 数据源Id
     */
    private Long originId;
    /**
     * 档位
     */
    private Integer gear;

    @Override
    public ProcessParametersData clone() {
        try {
            ProcessParametersData clone = (ProcessParametersData) super.clone();
            return clone;
        } catch (CloneNotSupportedException e) {
            throw new AssertionError();
        }
    }
}
