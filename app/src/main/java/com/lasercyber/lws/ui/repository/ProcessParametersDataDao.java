package com.lasercyber.lws.ui.repository;

import androidx.lifecycle.LiveData;
import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.Query;
import androidx.room.Update;

import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersNameData;
import com.lasercyber.lws.ui.common.constant.ProcessDataType;

import java.util.List;

/**
 * 工艺参数保存
 */
@Dao
public interface ProcessParametersDataDao {
    @Query("SELECT * FROM t_process_parameters_data where processType=:type limit 1")
    LiveData<ProcessParametersData> selectOne(Integer type);

    /**
     * 加载工程师模式的一条数据
     *
     * @param type
     * @return
     */
    @Query("SELECT * FROM t_process_parameters_data where processType=:type and dataType in (" + ProcessDataType.ENGINEER_MODE_DATA + "," + ProcessDataType.ENGINEER_MODE_CUSTOM_DATA + ") order by id asc limit 1")
    LiveData<ProcessParametersData> selectEngineerOneData(Integer type);

    /**
     * 加载工程师模式的所有数据名称
     *
     * @param type
     * @return
     */
    @Query("SELECT id,name,dataType,processType,materialType,materialName FROM t_process_parameters_data where processType=:type and dataType in (" + ProcessDataType.ENGINEER_MODE_DATA + "," + ProcessDataType.ENGINEER_MODE_CUSTOM_DATA + ") order by id asc")
    LiveData<List<ProcessParametersNameData>> selectEngineerAllName(Integer type);

    @Query("SELECT id,name,dataType,processType,materialType,materialName FROM t_process_parameters_data where processType=:type and dataType in (" + ProcessDataType.ENGINEER_MODE_DATA + "," + ProcessDataType.ENGINEER_MODE_CUSTOM_DATA + ") order by id asc")
    List<ProcessParametersNameData> selectEngineerAllNameSync(Integer type);

    @Query("SELECT * FROM t_process_parameters_data where processType=:type and dataType in (" + ProcessDataType.ENGINEER_MODE_DATA + "," + ProcessDataType.ENGINEER_MODE_CUSTOM_DATA + ") order by id asc")
    List<ProcessParametersData> selectEngineerAllSync(Integer type);

    @Query("SELECT * FROM t_process_parameters_data WHERE processType=:processType AND name=:name AND dataType IN ("
            + ProcessDataType.ENGINEER_MODE_DATA + "," + ProcessDataType.ENGINEER_MODE_CUSTOM_DATA + ") LIMIT 1")
    ProcessParametersData selectEngineerByProcessTypeAndNameSync(Integer processType, String name);

    @Query("SELECT * FROM t_process_parameters_data where id=:id")
    ProcessParametersData selectByIdSync(long id);

    @Insert
    long insert(ProcessParametersData processParametersData);

    @Update
    int update(ProcessParametersData processParametersData);

    @Query("DELETE FROM t_process_parameters_data")
    int deleteAll();

    /**
     * 根据Id加载工艺
     *
     * @param id
     * @return
     */
    @Query("SELECT * FROM t_process_parameters_data where id=:id")
    LiveData<ProcessParametersData> selectEngineerById(long id);

    /**
     * 根据Id删除
     *
     * @param id
     * @return
     */
    @Query("DELETE FROM t_process_parameters_data where id=:id")
    int deleteById(long id);

    /**
     * 加载所有的类型
     *
     * @param type
     * @param dataType
     * @return
     */
    @Query("SELECT * FROM t_process_parameters_data where processType=:type and dataType=:dataType and materialType=:materialType")
    LiveData<List<ProcessParametersData>> selectAllByType(Integer type, Integer dataType, Integer materialType);

    /**
     * 删除所有数据类型为dataType的数据
     */
    @Query("DELETE FROM t_process_parameters_data where dataType=:dataType")
    int deleteAllByDataType(Integer dataType);
    /**
     * 列出所有材质
     */
    @Query("SELECT * FROM t_process_parameters_data where processType=:type and dataType=:dataType")
    LiveData<List<ProcessParametersData>> listAllMaterials(Integer type,Integer dataType);

    @Insert
    List<Long> batchInsert(List<ProcessParametersData> processParametersData);

    /**
     * 批量删除数据
     */
    @Query("DELETE from t_process_parameters_data  where dataType in (:dataTypes)")
    int deleteByDataTypes(List<Integer> dataTypes);
}
