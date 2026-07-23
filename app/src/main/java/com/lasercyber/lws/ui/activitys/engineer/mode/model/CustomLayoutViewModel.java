package com.lasercyber.lws.ui.activitys.engineer.mode.model;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;

import androidx.lifecycle.LiveData;

import com.lasercyber.lws.ui.activitys.BaseViewModel;
import com.lasercyber.lws.ui.activitys.device.monitor.fragment.DashboardFragment;
import com.lasercyber.lws.ui.bean.entity.CustomLayout;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.web.HomeLayoutUtils;
import com.lasercyber.lws.ui.repository.CustomLayoutDao;

import java.util.ArrayList;
import java.util.List;

public class CustomLayoutViewModel extends BaseViewModel<CustomLayout> {

    public LiveData<List<CustomLayout>> customLiveData;

    /*1、初始化, 查询数据放入model中，如果没有则创建一条。同时查询*/
    public void init(Context context) {
        if (null != customLiveData) {
            return;
        }
        AppDatabase appDataBase = AppDatabase.getInstance(context);
        CustomLayoutDao customLayoutDao = appDataBase.customLayoutDao();

        customLiveData = customLayoutDao.selectAll();
        ThreadPoolManager.getExecutor().execute(() -> {

            Integer cout = customLayoutDao.selectCount();
            //没有则创建一套初始化的
            if (cout == 0) {
                List<CustomLayout> customLayouts = this.newCustomLists();
                addCustomLayout(context, customLayouts);
            }
        });
    }

    /*2、获取初始化的数据，供自定义布局页面使用*/
    public void initGetData(Context context, DashboardFragment.CallbackDashboard callbackDashboard) {
        if (null != customLiveData && customLiveData.getValue().size() > 0) { //如果管理器中有则直接取管理器中的数据
            List<CustomLayout> list = customLiveData.getValue();
            callbackDashboard.callback(list);
        }

        AppDatabase appDataBase = AppDatabase.getInstance(context);
        CustomLayoutDao customLayoutDao = appDataBase.customLayoutDao();

        ThreadPoolManager.getExecutor().execute(() -> {

            List<CustomLayout> initGetData = customLayoutDao.getInitGetData();
            //切换主线程
            new Handler(Looper.getMainLooper()).post(() -> {
                callbackDashboard.callback(initGetData);
            });
            //没有则创建一套初始化的
        });
    }

    /*3.批量创建初始化*/
    public List<CustomLayout> newCustomLists(){
        List<CustomLayout> list = new ArrayList<>();
        /*从枚举类中获取对应参数描述*/
            list.add( new CustomLayout(HomeLayoutUtils.materialsLength, HomeLayoutUtils.materialsLength) );
            list.add( new CustomLayout(HomeLayoutUtils.lightLength,HomeLayoutUtils.lightLength) );
            list.add( new CustomLayout(HomeLayoutUtils.jobLength,HomeLayoutUtils.jobLength) );
            list.add( new CustomLayout(HomeLayoutUtils.weldingRatio,HomeLayoutUtils.weldingRatio) );
            list.add( new CustomLayout(HomeLayoutUtils.cuttingRatio,HomeLayoutUtils.cuttingRatio) );
            list.add( new CustomLayout(HomeLayoutUtils.rinseRatio,HomeLayoutUtils.rinseRatio) );
            list.add( new CustomLayout(HomeLayoutUtils.comparedToLastWeek,HomeLayoutUtils.comparedToLastWeek) );
            list.add( new CustomLayout(HomeLayoutUtils.commonMaterials,HomeLayoutUtils.commonMaterials) );
        return list;
    }
    /*3、排序保存*/
    public void addCustomLayout( Context context ,List<CustomLayout> list ){
        // 先全部清空，再全部添加，留给设备设置中使用
        AppDatabase appDataBase = AppDatabase.getInstance(context);
        CustomLayoutDao customLayoutDao = appDataBase.customLayoutDao();
        ThreadPoolManager.getExecutor().execute(()-> {
            customLayoutDao.deleteAll();
            customLayoutDao.batchInsert( list );
        });
    }

}
