package com.lasercyber.lws.ui.repository;

import androidx.lifecycle.LiveData;
import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.Query;

import com.lasercyber.lws.ui.bean.entity.StaticData;

/*统计数据表*/
@Dao
public interface StaticDataDao {
    /*1.1、更新累计修改字段 焊接总时长 */
    @Query("update static_data set weldingTimeLength = weldingTimeLength+:number where id = 1")
    int updateWeldingTimeLength(Integer number);

    /*1.2、更新累计修改字段 切割总时长 */
    @Query("update static_data set cuttingTimeLength = cuttingTimeLength+:number where id = 1")
    int updateCuttingTimeLength(Integer number);

    /*1.3、更新累计修改字段 清洗总时长 */
    @Query("update static_data set washTimeLength = washTimeLength+:number where id = 1")
    int updateWashTimeLength(Integer number);

    /*1.4、上次工作时长 (秒) */
    @Query("update static_data set jobTimeLength = jobTimeLength + :number where id = 1")
    int updateJobTimeLength(Integer number);

    /*1.45、更新累计修改字段 焊接耗材总计 mm(毫米) */
    @Query("update static_data set consumableTimeLength = consumableTimeLength+:number where id = 1")
    int updateConsumableTimeLength(Long number);
    /*1.46、更新常用材料，传输前端使用  */
    @Query("update static_data set commonUse = :commonUse where id = 1")
    int updateCommonUse(Integer commonUse);

    /*1.5、更新累计修改字段 上周开始计时时间  上周一的日期 yyyy-mm-dd 的字符串格式*/
    @Query("update static_data set topStartTime=:topStartTime AND topDay=:day where id = 1")
    int updateTopWeek(Long topStartTime ,String day);

    /*1.6、更新累计修改字段 当前周开始计时时间  本周一的日期 yyyy-mm-dd*/
    @Query("update static_data set currStartTime=:currStartTime AND currDay=:day where id = 1")
    int updateCurrWeek(Long currStartTime ,String day);

    /*2、新增一条数据*/
    @Insert
    long insert(StaticData staticData);

    /*3、出厂设置时清空数据*/
    @Query("DELETE FROM static_data ")
    int deleteAll();

    /*4、查询单条数据【监听】*/
    @Query("SELECT * FROM static_data where id = 1")
    LiveData<StaticData> selectOne();

    /*查询单条数据*/
    @Query("SELECT * FROM static_data where id = 1")
    StaticData getOneData();

    /*清空工作时长*/
    @Query("update static_data set jobTimeLength = 0 where id = 1")
    int clearJobTimeLength();
}
