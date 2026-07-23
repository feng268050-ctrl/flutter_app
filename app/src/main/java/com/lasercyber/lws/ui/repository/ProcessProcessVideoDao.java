package com.lasercyber.lws.ui.repository;

import androidx.annotation.Nullable;
import androidx.lifecycle.LiveData;
import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.Query;
import androidx.room.Update;

import com.lasercyber.lws.ui.bean.entity.ProcessParamsVideo;
import com.lasercyber.lws.ui.bean.entity.vo.ProcessParamsVideoVo;

import java.util.List;

@Dao
public interface ProcessProcessVideoDao {
    /**
     * 插入数据
     *
     * @param processParamsVideo
     * @return
     */
    @Insert
    long insert(ProcessParamsVideo processParamsVideo);

    /**
     * 删除数据
     *
     * @param id
     * @return
     */
    @Query("DELETE FROM t_params_process_video where id=:id")
    int deleteById(long id);

    /**
     * 更新数据
     *
     * @param processParamsVideo
     * @return
     */
    @Update
    int update(ProcessParamsVideo processParamsVideo);

    /**
     * 分页加载数据
     *
     * @return
     */
    @Query("SELECT id, videoPath, processType, materialType, processParametersJson, fileSize, duration, createTime, " +
            "videoId, resolution, uploadStatus, uploadProgress, coverUrl, videoUrl " +
            "FROM t_params_process_video order by createTime DESC " +
            "LIMIT :pageSize OFFSET ((:pageNum - 1) * :pageSize)")
    List<ProcessParamsVideoVo> selectPage(int pageNum, int pageSize);

    /**
     * Count all locally persisted process video rows shown by Monitor -> Videos.
     */
    @Query("SELECT COUNT(*) FROM t_params_process_video")
    long countAllProcessVideos();

    /**
     * Count rows with upload pipeline started or completed ({@code uploadStatus != 0}).
     */
    @Query("SELECT COUNT(*) FROM t_params_process_video WHERE uploadStatus != 0")
    long countWhereUploadStatusNonZero();

    /**
     * Paged list for rows with {@code uploadStatus != 0}, newest {@code createTime} first.
     */
    @Query("SELECT id, videoPath, processType, materialType, processParametersJson, fileSize, duration, createTime, " +
            "videoId, resolution, uploadStatus, uploadProgress, coverUrl, videoUrl " +
            "FROM t_params_process_video WHERE uploadStatus != 0 ORDER BY createTime DESC " +
            "LIMIT :pageSize OFFSET ((:pageNum - 1) * :pageSize)")
    List<ProcessParamsVideoVo> selectPageWhereUploadStatusNonZero(int pageNum, int pageSize);

    /**
     * Count rows matching optional filters. When {@code uploadStatus} is {@code null}, only rows with
     * {@code uploadStatus != 0} are included; when set, rows must equal that status.
     */
    @Query("SELECT COUNT(*) FROM t_params_process_video WHERE "
            + "((:uploadStatus IS NOT NULL AND uploadStatus = :uploadStatus) "
            + "OR (:uploadStatus IS NULL AND uploadStatus != 0)) "
            + "AND (:processType IS NULL OR processType = :processType) "
            + "AND (:materialType IS NULL OR materialType = :materialType) "
            + "AND (:startDate IS NULL OR createTime >= :startDate) "
            + "AND (:endDate IS NULL OR createTime <= :endDate)")
    long countWhereUploadStatusNonZeroFiltered(@Nullable Integer uploadStatus,
                                               @Nullable Integer processType,
                                               @Nullable Integer materialType,
                                               @Nullable Long startDate,
                                               @Nullable Long endDate);

    /**
     * Paged list with optional filters, newest {@code createTime} first. See
     * {@link #countWhereUploadStatusNonZeroFiltered} for {@code uploadStatus} semantics.
     */
    @Query("SELECT id, videoPath, processType, materialType, processParametersJson, fileSize, duration, createTime, "
            + "videoId, resolution, uploadStatus, uploadProgress, coverUrl, videoUrl "
            + "FROM t_params_process_video WHERE "
            + "((:uploadStatus IS NOT NULL AND uploadStatus = :uploadStatus) "
            + "OR (:uploadStatus IS NULL AND uploadStatus != 0)) "
            + "AND (:processType IS NULL OR processType = :processType) "
            + "AND (:materialType IS NULL OR materialType = :materialType) "
            + "AND (:startDate IS NULL OR createTime >= :startDate) "
            + "AND (:endDate IS NULL OR createTime <= :endDate) "
            + "ORDER BY createTime DESC "
            + "LIMIT :pageSize OFFSET ((:pageNum - 1) * :pageSize)")
    List<ProcessParamsVideoVo> selectPageWhereUploadStatusNonZeroFiltered(int pageNum, int pageSize,
                                                                          @Nullable Integer uploadStatus,
                                                                          @Nullable Integer processType,
                                                                          @Nullable Integer materialType,
                                                                          @Nullable Long startDate,
                                                                          @Nullable Long endDate);

    /**
     * Paged list with optional filters, oldest {@code createTime} first. See
     * {@link #countWhereUploadStatusNonZeroFiltered} for {@code uploadStatus} semantics.
     */
    @Query("SELECT id, videoPath, processType, materialType, processParametersJson, fileSize, duration, createTime, "
            + "videoId, resolution, uploadStatus, uploadProgress, coverUrl, videoUrl "
            + "FROM t_params_process_video WHERE "
            + "((:uploadStatus IS NOT NULL AND uploadStatus = :uploadStatus) "
            + "OR (:uploadStatus IS NULL AND uploadStatus != 0)) "
            + "AND (:processType IS NULL OR processType = :processType) "
            + "AND (:materialType IS NULL OR materialType = :materialType) "
            + "AND (:startDate IS NULL OR createTime >= :startDate) "
            + "AND (:endDate IS NULL OR createTime <= :endDate) "
            + "ORDER BY createTime ASC "
            + "LIMIT :pageSize OFFSET ((:pageNum - 1) * :pageSize)")
    List<ProcessParamsVideoVo> selectPageWhereUploadStatusNonZeroFilteredAsc(int pageNum, int pageSize,
                                                                             @Nullable Integer uploadStatus,
                                                                             @Nullable Integer processType,
                                                                             @Nullable Integer materialType,
                                                                             @Nullable Long startDate,
                                                                             @Nullable Long endDate);

    /**
     * Rows eligible for automatic cover upload ({@code uploadStatus == 0} with {@code videoId}).
     */
    @Query("SELECT id FROM t_params_process_video WHERE uploadStatus = 0 AND videoId IS NOT NULL "
            + "ORDER BY createTime ASC LIMIT :limit")
    List<Long> selectPendingCoverUploadRowIds(int limit);

    @Query("UPDATE t_params_process_video SET uploadStatus = :uploadStatus, coverUrl = :coverUrl WHERE id = :id")
    int updateCoverUploaded(long id, int uploadStatus, String coverUrl);

    @Query("UPDATE t_params_process_video SET uploadStatus = :uploadStatus, uploadProgress = :uploadProgress WHERE id = :id")
    int updateUploadStatusAndProgressById(long id, int uploadStatus, int uploadProgress);

    @Query("UPDATE t_params_process_video SET uploadStatus = :uploadStatus, uploadProgress = :uploadProgress, videoUrl = :videoUrl WHERE id = :id")
    int updateVideoCloudStateById(long id, int uploadStatus, int uploadProgress, String videoUrl);

    /**
     * 删除所有
     */
    @Query("DELETE FROM t_params_process_video")
    int deleteAll();

    /**
     * 根据id查询数据
     *
     * @param id
     * @return
     */
    @Query("select* from t_params_process_video where id=:id")
    ProcessParamsVideo selectById(long id);

    /**
     * Lookup by business {@link ProcessParamsVideo#getVideoId()} (UUID string).
     */
    @Query("SELECT * FROM t_params_process_video WHERE videoId = :videoId LIMIT 1")
    @Nullable
    ProcessParamsVideo selectByVideoId(String videoId);

    /**
     * 根据id查询数据
     *
     * @param processVideoId
     * @return
     */
    @Query("select* from t_params_process_video where id=:processVideoId")
    LiveData<ProcessParamsVideo> selectLiveDataById(long processVideoId);

}
