package com.lasercyber.lws.ui.bean.entity;

import com.lasercyber.lws.ui.bean.push.ServerPushPayload;

import java.util.List;

import lombok.Data;
import lombok.experimental.Accessors;

/**
 * 云端下发的整包工艺库（版本元数据 + 工艺参数列表）。
 */
@Data
@Accessors(chain = true)
public class ProcessLibrary implements ServerPushPayload {
    /**
     * 版本号
     */
    private Integer versionCode;
    /**
     * 版本状态（字典process_version_status）
     */
    private Integer versionStatus;
    /**
     * 工艺库信息
     */
    private List<ProcessParametersData> dataList;
}
