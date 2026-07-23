package com.lasercyber.lws.ui.activitys.engineer.mode.model;

import android.content.Context;
import android.util.Log;

import androidx.lifecycle.LiveData;

import com.lasercyber.lws.ui.activitys.BaseViewModel;
import com.lasercyber.lws.ui.bean.entity.StaticData;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.constant.StaticConstant;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.repository.CommonUseConsumableDao;
import com.lasercyber.lws.ui.repository.CustomLayoutDao;
import com.lasercyber.lws.ui.repository.StaticDataDao;
import com.lasercyber.lws.ui.repository.WarnTableDao;

import java.util.Date;
import java.util.Objects;

import cn.hutool.core.date.DateTime;
import cn.hutool.core.date.DateUtil;
import cn.hutool.core.util.ObjUtil;


public class StaticDataViewModel extends BaseViewModel<StaticData> {

    public LiveData<StaticData> staticLiveData;

    private CommonUseConsumableViewModel comModel = new CommonUseConsumableViewModel();


    /*初始化, 查询数据放入model中，如果没有则创建一条。同时查询*/
    public void init( Context context ){
        AppDatabase appDataBase = AppDatabase.getInstance(context);
        StaticDataDao staticDataDao = appDataBase.staticDataDao();
        staticLiveData = staticDataDao.selectOne();

        ThreadPoolManager.getExecutor().execute(()->{

            Boolean Insert = false;
            StaticData data = staticDataDao.getOneData();
            //没有则创建一个
            if( ObjUtil.isNull( data ) ){
                data = newData();
                Insert = true;
                staticDataDao.insert( data );
            }
            //更新周期任务
            if( !Insert ){
                initWeek( data, staticDataDao );
            }
            Log.d(TAG, "init: 获取数据成功:"+data);
        });
    }


    /*初始化, 查询数据放入model中，如果没有则创建一条。同时查询*/
    public void initMutableLiveData( Context context ){

        ThreadPoolManager.getExecutor().execute(()->{
            AppDatabase appDataBase = AppDatabase.getInstance(context);
            StaticDataDao staticDataDao = appDataBase.staticDataDao();
            StaticData oneData = staticDataDao.getOneData();

            super.postLiveData(oneData);
            Log.d(TAG, "init: 获取数据成功:"+oneData);
        });
    }
    public void weldStopProxy( Integer model , Integer addNumber, Long wireFeed ,Context context ){
        int updateType=1;
        if (Objects.equals(model, ModelConstant.CNC_CUT)|| Objects.equals(model, ModelConstant.HAND_CUT)){
            updateType= StaticConstant.cutting;
        }
        if (Objects.equals(model, ModelConstant.CONTINUOUS_WELDING)||Objects.equals(model, ModelConstant.POINT_WELDING)) {
            updateType=StaticConstant.weld;
        }
        if (Objects.equals(model, ModelConstant.WIDTH_CLEAN)||Objects.equals(model, ModelConstant.WELD_CLEAN)){
            updateType=StaticConstant.wash;
        }
        weldStop(updateType,addNumber,wireFeed,context,null);
    }

    public void upCommonUse(Context context ,Integer commonUse){
        AppDatabase appDataBase = AppDatabase.getInstance(context);
        StaticDataDao staticDataDao = appDataBase.staticDataDao();
        ThreadPoolManager.getExecutor().execute(()-> {
            staticDataDao.updateCommonUse(commonUse);
        });
    }

    /* 。
    焊接停止后，启用计时累加
    @updateType 修改的类型 1、焊接 2、切割 3、清洗  4.工作时长 StaticConstant.weld
     * @addNumber 增加时长（秒），指 在原有基础上累计数值  如 1  = 工作时长 + 1
     @wireFeed 送丝速度 如40mm
    1、运行模式  1焊接、2切割、3清洗
    2、时间长度  秒
    3、送丝速度 mm /秒
    4、常用材料的枚举： com/lasercyber/lws/ui/common/enums/MaterialTypeEnum.java:9
    * */
    public void weldStop( Integer updateType , Integer addNumber, Long wireFeed ,Context context ,Integer commonUse){
        AppDatabase appDataBase = AppDatabase.getInstance(context);
        StaticDataDao staticDataDao = appDataBase.staticDataDao();

        ThreadPoolManager.getExecutor().execute(()-> {
            switch (updateType) {
                case 1: //1、焊接，记录焊接时长、耗材总计
                    staticDataDao.updateWeldingTimeLength(addNumber);
                    //累计耗材总计
                    Long length = addNumber * wireFeed;
                    staticDataDao.updateConsumableTimeLength(length);
                    break;
                case 2: //2、切割 记录切割时长
                    staticDataDao.updateCuttingTimeLength(addNumber);
                    break;
                case 3: //3、清洗 记录清洗时长
                    staticDataDao.updateWashTimeLength(addNumber);
                    break;
                case 4: //4、工作 工作时长
                    staticDataDao.updateJobTimeLength(addNumber);
                    break;
            }
            //增加使用记录
            if(null != commonUse){
                comModel.addUpdateCommonUseConsumableNumer(commonUse,context);
            }
        });
    }

    /* 在开机后第一次使用电焊机时，将上次工作时长归零*/
    public void clearJobTimeLength( Context context ){
        AppDatabase appDataBase = AppDatabase.getInstance(context);
        StaticDataDao staticDataDao = appDataBase.staticDataDao();
        ThreadPoolManager.getExecutor().execute(()-> {
            staticDataDao.clearJobTimeLength();
         });
    }

    /*出厂设置清空 .【出厂设置使用】*/
    public void deleteAll( Context context ){
        // 1、清空，
        AppDatabase appDataBase = AppDatabase.getInstance(context);
        StaticDataDao staticDataDao = appDataBase.staticDataDao();
        ThreadPoolManager.getExecutor().execute(()-> {
            staticDataDao.deleteAll();

            // 2、重新初始化
            init(context);

            // 3、同时删除耗材记录
            CommonUseConsumableDao commonUseConsumableDao = appDataBase.commonUseConsumableDao();
            commonUseConsumableDao.deleteAll();

            /* 4、删除告警记录*/
            WarnTableDao warnTableDao = appDataBase.warnTableDao();
            warnTableDao.deleteAll();

            CustomLayoutDao customLayoutDao = appDataBase.customLayoutDao();
            customLayoutDao.deleteAll();
        });
    }




    /*初始化周期数据*/
    private void initWeek( StaticData data,StaticDataDao staticDataDao ){
        //1、判断周期是否有变化，如果有变化，则重计周数据
        Date monday = DateUtil.beginOfWeek(new Date());
        String currTime = DateUtil.format(monday, "yyyy-MM-dd");

        if( !ObjUtil.equals( currTime,data.getCurrDay() ) ){

            //2、处理上周数据，判断是要清空还是将当前上移
            DateTime dateTime = DateUtil.offsetDay(monday, -7);
            String topTime = DateUtil.format(dateTime, "yyyy-MM-dd");
            if( ObjUtil.equals(topTime,data.getCurrDay()) ){
                //上移
                data.setTopDay( data.getCurrDay() );
                data.setTopStartTime( data.getCurrStartTime() );
                staticDataDao.updateTopWeek( data.getCurrStartTime(),data.getCurrDay() );

            }else{
                //否则清空上周的
                data.setTopStartTime(0L);
                data.setTopDay(null);
                staticDataDao.updateTopWeek( 0L,null );
            }
            //更新本周数据
            Long currTimeLength = data.getWeldingTimeLength() + data.getCuttingTimeLength()+ data.getWashTimeLength();
            data.setCurrDay(currTime);
            data.setCurrStartTime(currTimeLength);
            staticDataDao.updateCurrWeek( currTimeLength,currTime);
        }
    }
    private StaticData newData(){
        StaticData data = new StaticData();
        data.setWeldingTimeLength(0L);
        data.setCuttingTimeLength(0L);
        data.setWashTimeLength(0L);
        data.setJobTimeLength(0L);
        data.setTopStartTime(0L);
        data.setCurrStartTime(0L);
        data.setConsumableTimeLength(0L);
        data.setId(1);

        Date monday = DateUtil.beginOfWeek(new Date());
        String mondayStr = DateUtil.format(monday, "yyyy-MM-dd");
        data.setCurrDay(mondayStr);

        return data;
    }

}
