package com.lasercyber.lws.ui.component.adapter;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.recyclerview.widget.RecyclerView;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.vo.ProcessParamsVideoVo;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.VideoUploadStatus;
import com.lasercyber.lws.ui.component.holder.ProcessVideoViewHolder;

import java.util.ArrayList;
import java.util.List;
import java.util.function.Consumer;

import lombok.Setter;

/**
 * 工艺视频适配器
 */
public class ProcessVideoListAdapter extends RecyclerView.Adapter<ProcessVideoViewHolder> {
    private static final String TAG = LogTAGConstant.ProcessVideoListAdapter;
    private final Context context;
    private final boolean aiVisionChooseMode;
    private final List<ProcessParamsVideoVo> processParamsVideoList = new ArrayList<>();
    private final Handler handler = new Handler(Looper.getMainLooper());
    @Setter
    private DataEventListener dataEventListener;
    @Setter
    @Nullable
    private AiVisionUploadStateResolver aiVisionUploadStateResolver;

    public ProcessVideoListAdapter(Context context) {
        this(context, false);
    }

    public ProcessVideoListAdapter(Context context, boolean aiVisionChooseMode) {
        this.context = context;
        this.aiVisionChooseMode = aiVisionChooseMode;
    }

    /**
     * 重置数据
     *
     * @param newData
     * @return {@code true} when the adapter notified RecyclerView of a change
     */
    public boolean resetData(List<ProcessParamsVideoVo> newData) {
        if (isSameVideoList(processParamsVideoList, newData)) {
            return false;
        }

        int oldSize = processParamsVideoList.size();
        synchronized (processParamsVideoList) {
            processParamsVideoList.clear();
            if (newData != null && !newData.isEmpty()) {
                processParamsVideoList.addAll(newData);
            }
        }

        int newSize = processParamsVideoList.size();
        if (oldSize == newSize) {
            if (newSize > 0) {
                notifyItemRangeChanged(0, newSize);
            } else {
                notifyDataSetChanged();
            }
        } else if (oldSize == 0) {
            if (newSize > 0) {
                notifyItemRangeInserted(0, newSize);
            } else {
                notifyDataSetChanged();
            }
        } else if (newSize == 0) {
            notifyItemRangeRemoved(0, oldSize);
        } else {
            notifyItemRangeRemoved(0, oldSize);
            notifyItemRangeInserted(0, newSize);
        }
        return true;
    }

    private static boolean isSameVideoList(List<ProcessParamsVideoVo> current, List<ProcessParamsVideoVo> incoming) {
        if (incoming == null || incoming.isEmpty()) {
            return current.isEmpty();
        }
        if (current.size() != incoming.size()) {
            return false;
        }
        for (int i = 0; i < current.size(); i++) {
            if (current.get(i).getId() != incoming.get(i).getId()) {
                return false;
            }
        }
        return true;
    }

    /**
     * 添加数据（上拉加载更多）
     * 在列表尾部追加数据，仅刷新新增的条目
     *
     * @param newData 新增数据列表（null/空集合时不执行任何操作）
     */
    /**
     * After cloud video upload completes (DB already updated), sync in-memory row and refresh that item.
     * Call from the main thread.
     */
    public void markRowVideoCloudUploaded(long rowId, @Nullable String videoPublicUrl) {
        int index = RecyclerView.NO_POSITION;
        synchronized (processParamsVideoList) {
            for (int i = 0; i < processParamsVideoList.size(); i++) {
                ProcessParamsVideoVo vo = processParamsVideoList.get(i);
                if (vo.getId() == rowId) {
                    vo.setUploadStatus(VideoUploadStatus.VIDEO_UPLOADED);
                    vo.setUploadProgress(100);
                    if (videoPublicUrl != null && !videoPublicUrl.isEmpty()) {
                        vo.setVideoUrl(videoPublicUrl);
                    }
                    index = i;
                    break;
                }
            }
        }
        if (index >= 0) {
            notifyItemChanged(index);
        }
    }

    public void pushData(List<ProcessParamsVideoVo> newData) {
        // 1. 前置校验：空数据直接返回，避免无效操作
        if (newData == null || newData.isEmpty()) {
            return;
        }

        // 2. 记录新增数据前的列表大小（作为插入起始位置）
        int startPosition;
        synchronized (processParamsVideoList) {
            startPosition = processParamsVideoList.size();
            // 3. 批量添加新数据（避免多次add导致频繁刷新）
            processParamsVideoList.addAll(newData);
        }

        // 4. 仅刷新新增的条目（UI操作必须在主线程）
        int addCount = newData.size();
        if (addCount > 0) {
            notifyItemRangeInserted(startPosition, addCount);
        }
    }

    public int getDataCount() {
        return processParamsVideoList.size();
    }

    @NonNull
    @Override
    public ProcessVideoViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(context).inflate(R.layout.process_video_list_data_item, parent, false);
        return new ProcessVideoViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull ProcessVideoViewHolder holder, int position) {
        if (processParamsVideoList.isEmpty()) {
            return;
        }
        ProcessParamsVideoVo processParamsVideo = processParamsVideoList.get(position);
        holder.fileData(processParamsVideo);
        boolean cloudUploadComplete = processParamsVideo.getUploadStatus() == VideoUploadStatus.VIDEO_UPLOADED;
        boolean aiVisionInferenceUploaded = aiVisionChooseMode
                && aiVisionUploadStateResolver != null
                && aiVisionUploadStateResolver.isAiVisionInferenceUploaded(processParamsVideo);
        holder.getDeleteButton().setVisibility(aiVisionChooseMode ? View.GONE : View.VISIBLE);
        holder.getUploadButton().setVisibility(aiVisionChooseMode
                ? (aiVisionInferenceUploaded ? View.VISIBLE : View.GONE)
                : View.VISIBLE);
        holder.getDetailsButton().setSingleLine(true);
        holder.getDetailsButton().setAllCaps(false);
        holder.getDetailsButton().setText(aiVisionChooseMode
                ? context.getString(R.string.ai_vision_select_btn)
                : context.getString(R.string.details_text));
        boolean uploadCompleteForCurrentMode = aiVisionChooseMode
                ? aiVisionInferenceUploaded
                : cloudUploadComplete;
        holder.getUploadButton().setEnabled(!uploadCompleteForCurrentMode);
        holder.getUploadButton().setText(uploadCompleteForCurrentMode
                ? context.getString(R.string.upload_button_uploaded)
                : context.getString(R.string.upload_text));
        if (dataEventListener != null) {
            int currentPosition = holder.getAbsoluteAdapterPosition();
            // 安全校验：避免位置无效（比如条目已被删除）
            if (currentPosition == RecyclerView.NO_POSITION) {
                return;
            }
            if (aiVisionChooseMode) {
                holder.getDeleteButton().setOnClickListener(null);
                holder.getUploadButton().setOnClickListener(null);
            } else {
                holder.getDeleteButton().setOnClickListener(v -> dataEventListener.deleteData(processParamsVideo, currentPosition, new Consumer<Integer>() {
                    @Override
                    public void accept(Integer integer) {
                        // 刷新UI
                        handler.post(() -> {
                            deleteItem(currentPosition);
                        });
                    }
                }));
                if (cloudUploadComplete) {
                    holder.getUploadButton().setOnClickListener(null);
                } else {
                    holder.getUploadButton().setOnClickListener(
                            v -> dataEventListener.uploadData(processParamsVideo, currentPosition));
                }
            }
            holder.getDetailsButton().setOnClickListener(v -> dataEventListener.detailsData(processParamsVideo, currentPosition));
        }
    }

    /**
     * 删除指定位置的条目并刷新界面
     *
     * @param position 要删除的条目位置
     */
    public void deleteItem(int position) {
        Log.d(TAG, "deleteItem: 删除后，刷新界面:" + position);
        // 1. 边界校验：避免越界
        if (processParamsVideoList.isEmpty()
                || position < 0 || position >= processParamsVideoList.size()) {
            return;
        }

        // 2. 移除数据（线程安全）
        synchronized (processParamsVideoList) {
            processParamsVideoList.remove(position);
        }

        // 3. 局部刷新：仅删除对应位置的条目，性能最优
        notifyItemRemoved(position);
        // 4. 通知后续条目位置更新（避免动画错位）
        notifyItemRangeChanged(position, processParamsVideoList.size() - position);
    }

    @Override
    public int getItemCount() {
        return processParamsVideoList.size();
    }

    /**
     * 数据事件监听
     */
    public interface DataEventListener {
        /**
         * 删除数据
         *
         * @param processParamsVideo
         */
        void deleteData(ProcessParamsVideoVo processParamsVideo, int position, Consumer<Integer> callBack);

        /**
         * 上传数据
         *
         * @param processParamsVideo
         */
        void uploadData(ProcessParamsVideoVo processParamsVideo, int position);

        /**
         * 详情数据
         *
         * @param processParamsVideo
         */
        void detailsData(ProcessParamsVideoVo processParamsVideo, int position);
    }

    public interface AiVisionUploadStateResolver {
        boolean isAiVisionInferenceUploaded(ProcessParamsVideoVo processParamsVideo);
    }
}
