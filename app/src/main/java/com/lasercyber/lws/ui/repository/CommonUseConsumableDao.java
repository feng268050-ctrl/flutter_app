package com.lasercyber.lws.ui.repository;

import androidx.lifecycle.LiveData;
import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.Query;

import com.lasercyber.lws.ui.bean.entity.CommonUseConsumable;

/*耗材使用记录Dao*/
@Dao
public interface CommonUseConsumableDao {

    /*1、创建一个型号,同时更新model*/
    @Insert
    long insert( CommonUseConsumable staticData );

    /*2、update 增加一条使用记录。
    * commonUseConsumable 常用耗材 (枚举， 用下标对应) 主键 */
    @Query("update common_use_consumable set useNumber = useNumber+1 where commonUse = :commonUseConsumable")
    int updateCommonUseConsumable( Integer commonUseConsumable );

    /*3、删除全部*/
    @Query("DELETE FROM common_use_consumable ")
    int deleteAll();

    //4、根据耗材枚举获取耗材
    @Query("SELECT useNumber FROM common_use_consumable where commonUse = :commonUseConsumable")
    Integer getDataByCommonUseConsumable( Integer commonUseConsumable );

    /*5、查询最大耗材*/
    @Query("SELECT * FROM common_use_consumable order by useNumber DESC limit 1")
    CommonUseConsumable getDataBySum();
}
