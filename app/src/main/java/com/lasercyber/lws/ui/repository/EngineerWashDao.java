package com.lasercyber.lws.ui.repository;

import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.Query;
import androidx.room.Update;

import com.lasercyber.lws.ui.bean.entity.EngineerWash;

@Dao
public interface EngineerWashDao {
    /**
     * 根据类型查询一条
     * @param type
     * @return
     */
    @Query("select * from t_engineer_wash where type=:type order by id Desc limit 1")
    EngineerWash selectLastOneByType(Integer type);
    /**
     * 插入一条数据
     * @param engineerWash
     * @return
     */
    @Insert
    long insert(EngineerWash engineerWash);
    /**
     * 删除一条数据
     * @param type
     * @return
     */
    @Query("delete from t_engineer_wash where type=:type")
    int deleteByType(Integer type);
    /**
     * 更新一条数据
     * @param engineerWash
     * @return
     */
    @Update
    int update(EngineerWash engineerWash);
}
