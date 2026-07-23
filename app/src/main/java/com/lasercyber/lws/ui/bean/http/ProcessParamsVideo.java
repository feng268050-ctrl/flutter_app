package com.lasercyber.lws.ui.bean.http;

import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;

import java.io.Serializable;

import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.experimental.Accessors;

/**
 * 工艺库和视频信息
 */
@Data
@Accessors(chain = true)
@NoArgsConstructor
public class ProcessParamsVideo implements Serializable {
    /**
     * 工艺库
     */
    private ProcessParametersData processParametersData;
    /**
     * 视频信息
     */
    private ProcessVideo processVideo;
    /**
     * 视频标题
     */
    private String videoTitle;

    public ProcessParamsVideo(ProcessParametersData processParametersData, ProcessVideo processVideo) {
        if (processParametersData != null) {
            ProcessParametersData clone = processParametersData.clone();
            clone.setId(null);
            this.processParametersData = clone;
        }
        this.processVideo = processVideo;
    }
}
