package com.lasercyber.lws.ui.repository;

import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.Query;
import androidx.room.RoomWarnings;
import androidx.room.Update;

import com.lasercyber.lws.ui.bean.entity.WarnTable;

import java.util.List;

@Dao
public interface WarnTableDao {

    /*1、 新增一条告警记录 */
    @Insert
    long insert(WarnTable warnTable);

    /*2、出厂设置时清空数据*/
    @Query("DELETE FROM warn_table ")
    int deleteAll();

    /*3、根据code + 最新时间戳范围查询 10分钟内的告警记录*/
    @Query("SELECT id FROM warn_table where code = :code AND newTime + 600000 > :time")
    Long selectOne(String code, Long time);

    /*4、更新最新时间戳*/
    @Query("update warn_table set newTime=:time where id=:id")
    int updateNewTime(Long time ,Long id);

    @Query("update warn_table set newTime=:time, content=:content where id=:id")
    int updateNewTimeAndContent(Long time, String content, Long id);

    /*分页查询 page页码、number 每页数量*/
    @Query("SELECT * FROM warn_table ORDER BY newTime DESC limit :page,:number")
    List<WarnTable> getListWarnTable(Integer page,Integer number);

    /*每次开机清除三个月前的告警记录*/
    @Query("DELETE FROM warn_table WHERE newTime < :time")
    int deleteTimeHalfYear( Long time );

    @Query("SELECT * FROM warn_table limit 1")
    WarnTable getOne();

    /**
     * 加载告警列表
     * @param codeList
     * @param time
     * @return
     */
    @SuppressWarnings(RoomWarnings.CURSOR_MISMATCH)
    @Query("select id,code from warn_table where code in (:codeList) and newTime + 600000 > :time")
    List<WarnTable> selectListByCodeAndTime(List<String> codeList, Long time);

    /**
     * 批量更新最新时间戳
     * @param ids
     * @param time
     * @return
     */
    @Query("update warn_table set newTime=:time where id in (:ids)")
    int batchUpdateNewTime(List<Long> ids, Long time);

    /**
     * 批量保存
     * @param saveList
     * @return
     */
    @Insert
    List<Long> batchInsert(List<WarnTable> saveList);
}
