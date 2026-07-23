package com.lasercyber.lws.ui.repository;

import androidx.lifecycle.LiveData;
import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.Query;
import androidx.room.Update;

import com.lasercyber.lws.ui.bean.entity.EngineerWelding;
@Dao
public interface EngineerWeldingDao {
    /**
     * 根据类型查询一条
     * @param type
     * @return
     */
    @Query("select * from t_engineer_welding where type=:type order by id Desc limit 1")
    EngineerWelding selectLastOneByType(Integer type);
    /**
     * 插入一条数据
     * @param engineerWelding
     * @return
     */
    @Insert
    long insert(EngineerWelding engineerWelding);
    /**
     * 更新一条数据
     * @param engineerWelding
     * @return
     */
    @Update
    int update(EngineerWelding engineerWelding);
    /**
     * 根据类型删除一条数据
     * @param type
     * @return
     */
    @Query("delete from t_engineer_welding where type=:type")
    int deleteByType(Integer type);
}
