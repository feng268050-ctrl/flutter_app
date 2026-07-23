package com.lasercyber.lws.ui.repository;

import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.Query;
import androidx.room.Update;

import com.lasercyber.lws.ui.bean.entity.EngineerCutting;

@Dao
public interface EngineerCuttingDto {
    /**
     * 获取最后一条数据
     * @return
     */
    @Query("SELECT * FROM t_engineer_cutting order by id Desc LIMIT 1")
    EngineerCutting selectLastOne();
    @Insert
    long insert(EngineerCutting engineerCutting);
    @Update
    int update(EngineerCutting engineerCutting);
    @Query("DELETE FROM t_engineer_cutting ")
    int deleteAll();
}
