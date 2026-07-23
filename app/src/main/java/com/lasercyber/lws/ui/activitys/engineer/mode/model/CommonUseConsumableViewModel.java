package com.lasercyber.lws.ui.activitys.engineer.mode.model;

import android.content.Context;
import android.util.Log;

import com.lasercyber.lws.ui.activitys.BaseViewModel;
import com.lasercyber.lws.ui.bean.entity.CommonUseConsumable;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.repository.CommonUseConsumableDao;

import cn.hutool.core.util.ObjectUtil;

public class CommonUseConsumableViewModel extends BaseViewModel<CommonUseConsumable> {

    /*初始化, 查询最大使用次数的数据放入model中，*/
    public void init( Context context ){
        AppDatabase appDataBase = AppDatabase.getInstance(context);
        CommonUseConsumableDao commonUseConsumableDao = appDataBase.commonUseConsumableDao();

        ThreadPoolManager.getExecutor().execute(()->{
            CommonUseConsumable dataBySum = commonUseConsumableDao.getDataBySum();
            if(ObjectUtil.isNull(dataBySum)){
                dataBySum = new CommonUseConsumable();
                dataBySum.setCommonUse(1);
                dataBySum.setUseNumber(0L);
            }
            super.postLiveData(dataBySum);
            Log.d(TAG, "CommonUseConsumableViewModelInit: 最大使用次数:"+ dataBySum);
        });
    }

    /* update 增加一次使用记录。（没有对应耗材则创建）
    commonUse 常用耗材的枚举
    * */
    public void addUpdateCommonUseConsumableNumer( Integer commonUse ,Context context ){
        AppDatabase appDataBase = AppDatabase.getInstance(context);
        CommonUseConsumableDao commonUseConsumableDao = appDataBase.commonUseConsumableDao();
        ThreadPoolManager.getExecutor().execute(()-> {
            selectAndInsertOrUpdateData(commonUse,commonUseConsumableDao);
            Log.d(TAG, "addUpdateCommonUseConsumableNumer: 增加使用次数:"+ commonUse);
        });
    }

    /*查询后，添加或新增耗材设备 不对外调用*/
    private void selectAndInsertOrUpdateData(Integer commonUse ,CommonUseConsumableDao dao){
        Integer number = dao.updateCommonUseConsumable(commonUse);
        if(null == number || number == 0){
            insertAdd(commonUse,dao);
            Log.d(TAG, "insertAdd: 增加常用耗材:"+ commonUse);
        }
    }

    /* commonUse 常用耗材的枚举 不对外调用* */
    private void insertAdd( Integer commonUse ,CommonUseConsumableDao dao){
            CommonUseConsumable commonUseConsumable = new CommonUseConsumable();
            commonUseConsumable.setCommonUse(commonUse);
            commonUseConsumable.setUseNumber(1L);

        long insert = dao.insert(commonUseConsumable);
        Log.d(TAG, "insertAdd: 增加常用耗材:"+ insert);
    }
}
