package com.lasercyber.lws.ui.repository;

import androidx.lifecycle.LiveData;
import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.Query;
import androidx.room.Update;

import com.lasercyber.lws.ui.bean.entity.AdvancedSettings;

@Dao
public interface AdvancedSettingsDao {
    @Query("SELECT * FROM t_advanced_settings ORDER BY id DESC LIMIT 1")
    AdvancedSettings selectOne();

    @Query("SELECT * FROM t_advanced_settings ORDER BY id DESC LIMIT 1")
    LiveData<AdvancedSettings> selectOneLiveData();

    @Update
    int update(AdvancedSettings settings);

    @Insert
    long insert(AdvancedSettings settings);
}
