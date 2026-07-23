package com.lasercyber.lws.ui.network.http.local;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.bean.entity.ProcessParamsVideo;
import com.lasercyber.lws.ui.bean.entity.vo.ProcessParamsVideoVo;
import com.lasercyber.lws.ui.network.ws.DeviceWsVideoListPayload;
import com.lasercyber.lws.ui.repository.ProcessProcessVideoDao;

import java.io.File;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Shared read/list/delete-query helpers for local HTTP and WebSocket video APIs.
 */
public final class ProcessVideoQueryService {

    public static final class PagedVideos {
        public final List<Map<String, Object>> list;
        public final long total;

        public PagedVideos(List<Map<String, Object>> list, long total) {
            this.list = list;
            this.total = total;
        }
    }

    private ProcessVideoQueryService() {
    }

    @NonNull
    public static PagedVideos list(@NonNull ProcessProcessVideoDao dao,
                                   int page,
                                   int pageSize,
                                   @Nullable DeviceWsVideoListPayload.ListFilters filters) {
        Integer uploadStatus = filters != null ? filters.uploadStatus : null;
        Integer processType = filters != null ? filters.processType : null;
        Integer materialType = filters != null ? filters.materialType : null;
        Long startDate = filters != null ? filters.startDate : null;
        Long endDate = filters != null ? filters.endDate : null;
        long total = dao.countWhereUploadStatusNonZeroFiltered(
                uploadStatus, processType, materialType, startDate, endDate);
        boolean ascending = filters != null && filters.createTimeAscending;
        List<ProcessParamsVideoVo> vos = ascending
                ? dao.selectPageWhereUploadStatusNonZeroFilteredAsc(
                page, pageSize, uploadStatus, processType, materialType, startDate, endDate)
                : dao.selectPageWhereUploadStatusNonZeroFiltered(
                page, pageSize, uploadStatus, processType, materialType, startDate, endDate);
        return new PagedVideos(DeviceWsVideoListPayload.rowsFromVos(vos), total);
    }

    @Nullable
    public static Map<String, Object> rowByVideoId(@NonNull ProcessProcessVideoDao dao, @NonNull String videoId) {
        ProcessParamsVideo row = dao.selectByVideoId(videoId);
        if (row == null) {
            return null;
        }
        return DeviceWsVideoListPayload.voToRow(toVo(row));
    }

    @Nullable
    public static File videoFileForStream(@NonNull ProcessProcessVideoDao dao, @NonNull String videoId) {
        ProcessParamsVideo row = dao.selectByVideoId(videoId);
        if (row == null || row.getVideoPath() == null) {
            return null;
        }
        File file = new File(row.getVideoPath());
        return file.isFile() ? file : null;
    }

    @Nullable
    public static ProcessParamsVideoVo videoVoByVideoId(@NonNull ProcessProcessVideoDao dao,
                                                        @NonNull String videoId) {
        ProcessParamsVideo row = dao.selectByVideoId(videoId);
        return row == null ? null : toVo(row);
    }

    @NonNull
    public static ProcessParamsVideoVo toVo(@NonNull ProcessParamsVideo row) {
        ProcessParamsVideoVo vo = new ProcessParamsVideoVo();
        vo.setId(row.getId());
        vo.setVideoPath(row.getVideoPath());
        vo.setProcessType(row.getProcessType());
        vo.setMaterialType(row.getMaterialType());
        vo.setProcessParametersJson(row.getProcessParametersJson());
        vo.setFileSize(row.getFileSize());
        vo.setDuration(row.getDuration());
        vo.setCreateTime(row.getCreateTime());
        vo.setVideoId(row.getVideoId());
        vo.setResolution(row.getResolution());
        vo.setUploadStatus(row.getUploadStatus());
        vo.setUploadProgress(row.getUploadProgress());
        vo.setCoverUrl(row.getCoverUrl());
        vo.setVideoUrl(row.getVideoUrl());
        return vo;
    }

    @NonNull
    public static Map<String, Object> listDataMap(@NonNull PagedVideos page) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("list", page.list);
        data.put("total", page.total);
        return data;
    }
}
