package com.lasercyber.lws.ui.common.constant;

/**
 * 工艺参数数据类型（{@code ProcessParametersData.dataType} / 工艺库 Excel「数据类型」列）。
 *
 * <table>
 *   <tr><th>值</th><th>常量</th><th>含义</th></tr>
 *   <tr><td>0</td><td>{@link #QUICK_MODE_DATA}</td><td>快速模式参数</td></tr>
 *   <tr><td>1</td><td>{@link #ENGINEER_MODE_DATA}</td><td>工程师模式常用参数</td></tr>
 *   <tr><td>2</td><td>{@link #ENGINEER_MODE_CUSTOM_DATA}</td><td>工程师模式自定义参数（废弃）</td></tr>
 *   <tr><td>3</td><td>{@link #VIDEO_PROCESS_DATA}</td><td>视频工艺参数（废弃）</td></tr>
 * </table>
 */
public class ProcessDataType {
    /** 快速模式参数（0） */
    public static final int QUICK_MODE_DATA = 0;
    /** 工程师模式常用参数（1） */
    public static final int ENGINEER_MODE_DATA = 1;
    /**
     * @deprecated 使用 {@link #ENGINEER_MODE_DATA}
     */
    @Deprecated
    public static final int ENGINEER_MODE_DEFAULT_DATA = ENGINEER_MODE_DATA;
    /**
     * 工程师模式自定义参数（2，废弃）
     *
     * @deprecated 新数据统一写入 {@link #ENGINEER_MODE_DATA}；历史行由 migration 归并为 1。
     */
    @Deprecated
    public static final int ENGINEER_MODE_CUSTOM_DATA = 2;
    /**
     * 视频工艺参数（3，废弃）
     *
     * @deprecated 历史视频关联工艺行；新功能勿写入此类型。
     */
    @Deprecated
    public static final int VIDEO_PROCESS_DATA = 3;

    private ProcessDataType() {
    }

    public static boolean isEngineerModeDataType(Integer dataType) {
        return dataType != null
                && (dataType == ENGINEER_MODE_DATA || dataType == ENGINEER_MODE_CUSTOM_DATA);
    }
}
