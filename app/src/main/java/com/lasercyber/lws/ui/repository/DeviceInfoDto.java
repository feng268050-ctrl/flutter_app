package com.lasercyber.lws.ui.repository;

import androidx.lifecycle.LiveData;
import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.Query;
import androidx.room.Update;

import com.lasercyber.lws.ui.bean.entity.DeviceInfo;

/**
 * 设备信息
 */
@Dao
public interface DeviceInfoDto {
    @Insert
    long insert(DeviceInfo deviceInfo);
    @Update
    int update(DeviceInfo deviceInfo);

    /**
     * 查询最后一条
     * @return
     */
    @Query("SELECT * FROM t_device_info order by id desc limit 1")
    LiveData<DeviceInfo> queryLast();

    @Query("SELECT * FROM t_device_info order by id desc limit 1")
    DeviceInfo getOneData();
    @Query("SELECT * FROM t_device_info WHERE processLibVersion != '' AND processLibVersion != '--' "
            + "AND processLibVersion != '-' order by id desc limit 1")
    DeviceInfo getLastWithLibraryVersions();
    @Query("delete from t_device_info where id != :keepId")
    int deleteOthers(int keepId);
    @Query("delete from t_device_info")
    int deleteAll();
}
