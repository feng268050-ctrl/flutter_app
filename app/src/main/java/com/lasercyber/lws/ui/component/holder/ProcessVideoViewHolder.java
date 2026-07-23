package com.lasercyber.lws.ui.component.holder;

import android.view.View;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.frostui.button.interop.FrostButtonView;
import com.lasercyber.lws.ui.bean.entity.vo.ProcessParamsVideoVo;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.utils.convert.EngineerWashConvert;

import org.apache.commons.lang3.time.DurationFormatUtils;

import java.util.Date;

import cn.hutool.core.date.DateUtil;
import lombok.Getter;

/**
 * 工艺视频
 */
public class ProcessVideoViewHolder extends RecyclerView.ViewHolder {
    private final TextView recordingTimeText;
    private final TextView workModelText;
    private final TextView workMaterialText;
    private final TextView durationText;
    @Getter
    private final FrostButtonView deleteButton;
    @Getter
    private final FrostButtonView uploadButton;
    @Getter
    private final FrostButtonView detailsButton;

    public ProcessVideoViewHolder(@NonNull View itemView) {
        super(itemView);
        recordingTimeText = itemView.findViewById(R.id.video_process_data_recording_time);
        workModelText = itemView.findViewById(R.id.video_process_data_work_model);
        workMaterialText = itemView.findViewById(R.id.video_process_data_work_material);
        durationText = itemView.findViewById(R.id.video_process_data_duration);
        deleteButton = itemView.findViewById(R.id.process_video_delete);
        uploadButton = itemView.findViewById(R.id.process_video_upload);
        detailsButton = itemView.findViewById(R.id.process_video_details);
    }

    /**
     * 填充数据
     *
     * @param processParamsVideo
     */
    public void fileData(ProcessParamsVideoVo processParamsVideo) {
        if (processParamsVideo == null) {
            return;
        }
        if (processParamsVideo.getCreateTime() != null) {
            recordingTimeText.setText(DateUtil.format(new Date(processParamsVideo.getCreateTime()), "yyyy-MM-dd HH:mm"));
        }
        workModelText.setText(ModelConstant.convertToText(processParamsVideo.getProcessType()));
        String materialLabel =
                EngineerWashConvert.convertCleaningMaterialsText(processParamsVideo.getMaterialType());
        workMaterialText.setText(materialLabel != null ? materialLabel : "");
        String duration = DurationFormatUtils.formatDuration(processParamsVideo.getDuration(), "mm:ss");
        durationText.setText(duration);
    }
}
