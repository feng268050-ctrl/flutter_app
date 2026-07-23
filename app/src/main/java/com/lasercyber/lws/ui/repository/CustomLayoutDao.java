package com.lasercyber.lws.ui.repository;

import androidx.lifecycle.LiveData;
import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.Query;

import com.lasercyber.lws.ui.bean.entity.CustomLayout;

import java.util.List;

@Dao
public interface CustomLayoutDao {

    /**
     * 获取全部自定义布局列表
     * @return
     */
    @Query("SELECT * FROM custom_layout order by laoutIndex ASC")
    LiveData<List<CustomLayout>> selectAll();

    @Query("SELECT count(*) from custom_layout")
    Integer selectCount();

    /**
     * 批量保存
     * @param saveList
     * @return
     */
    @Insert
    List<Long> batchInsert(List<CustomLayout> saveList);

    /*2、出厂设置时清空数据*/
    @Query("DELETE FROM custom_layout ")
    int deleteAll();
    @Query("SELECT * FROM custom_layout order by laoutIndex ASC")
    List<CustomLayout> getInitGetData();
}
