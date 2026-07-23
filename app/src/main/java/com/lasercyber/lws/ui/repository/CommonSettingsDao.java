package com.lasercyber.lws.ui.repository;

import androidx.lifecycle.LiveData;
import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.Query;
import androidx.room.Update;

import com.lasercyber.lws.ui.bean.entity.CommonSettings;

@Dao
public interface CommonSettingsDao {
    @Query("SELECT * FROM t_common_settings ORDER BY id DESC LIMIT 1")
    CommonSettings selectOne();

    @Query("SELECT soundEffect FROM t_common_settings ORDER BY id DESC LIMIT 1")
    Integer selectSoundEffect();

    @Query("SELECT * FROM t_common_settings ORDER BY id DESC LIMIT 1")
    LiveData<CommonSettings> selectOneLiveData();

    @Update
    int update(CommonSettings settings);

    @Insert
    long insert(CommonSettings settings);
}
