package com.lasercyber.lws.ui.activitys.engineer.mode.model;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.lifecycle.LifecycleOwner;
import androidx.lifecycle.LiveData;
import androidx.lifecycle.MutableLiveData;

import com.blankj.utilcode.util.StringUtils;
import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.AdvancedSettings;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersNameData;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.constant.ProcessDataType;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.enums.MaterialTypeEnum;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusManagerRtu;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusFiledBuilder;
import com.lasercyber.lws.ui.common.state.ProcessParametersSnapshotStore;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.DefaultValueUtils;
import com.lasercyber.lws.ui.common.utils.InchMillimeterUtils;
import com.lasercyber.lws.ui.common.utils.convert.EngineerWashConvert;
import com.lasercyber.lws.ui.common.utils.convert.ProcessDataExcelConvert;
import com.lasercyber.lws.ui.common.utils.convert.ProcessParametersDataConvert;
import com.lasercyber.lws.ui.repository.AdvancedSettingsDao;
import com.lasercyber.lws.ui.repository.CommonSettingsDao;
import com.lasercyber.lws.ui.repository.ProcessParametersDataDao;

import java.util.List;
import java.util.Objects;
import java.util.function.Consumer;

import cn.hutool.core.convert.Convert;
import lombok.Getter;
import lombok.Setter;

/**
 * 工艺参数数据模型
 */
public class ProcessParametersDataViewModel extends BaseProcessParametersDataViewModel {
    private static final double LASER_END_POWER_RATIO = 0.97;

    protected static final String TAG = LogTAGConstant.BaseViewModel;
    private ProcessParametersDataDao processParametersDataDao;
    private Context context;
    /** 当前编辑会话的内存工艺参数，不自动落库。 */
    private final MutableLiveData<ProcessParametersData> sessionLiveData = new MutableLiveData<>();
    private final Handler handler = new Handler(Looper.getMainLooper());
    private Runnable task = null;
    // 高级设置
    private AdvancedSettingsDao advancedSettingsDao;
    @Getter
    private LiveData<List<ProcessParametersNameData>> listLiveData;
    // 用于临时存储
    ProcessParametersData dataTemp;
    /** 当前编辑会话的初始参数快照，供「重置为默认」恢复。 */
    private ProcessParametersData sessionBaseline;
    /**
     * 工艺参数数据模型
     */
    @Getter
    private Integer type;

    @Getter
    private boolean isInit = false;
    @Setter
    private boolean debug = false;

    public void startInit() {
        isInit = true;
    }

    /**
     * 初始化完成
     */
    public void endInit() {
        if (debug) Log.d(TAG, "endInit: 结束初始化");
        isInit = false;
    }

    /**
     * 初始化
     *
     * @param context
     * @param type    工艺类型
     */
    public void init(Context context, Integer type) {
        init(context, type, false);
    }

    /**
     * @param skipInitialProcessLoad 为 true 时跳过默认工艺加载（快速模式携带参数进入时使用）
     */
    public void init(Context context, Integer type, boolean skipInitialProcessLoad) {
//        if(debug) Log.d(TAG, "init: 正在初始化工艺参数的viewModel:"+type);
        this.context = context;
        this.type = type;
        // 初始化数据库实例
        AppDatabase appDataBase = AppDatabase.getInstance(context);
        processParametersDataDao = appDataBase.processParametersDataDao();
        advancedSettingsDao = appDataBase.advancedSettingsDao();
        parameterSettingsLiveData = advancedSettingsDao.selectOneLiveData();
        CommonSettingsDao commonSettingsDao = appDataBase.commonSettingsDao();
        commonSettingsLiveData = commonSettingsDao.selectOneLiveData();
        initUseMMUnitLiveData();
        if (!skipInitialProcessLoad) {
            loadInitialSessionIfNeeded();
        }
//        advancedSettingLiveData.observeForever(advancedSetting -> {
//            if(debug) Log.d(TAG, "init: 监听到高级设置数据："+ advancedSetting);
//        });
        listLiveData = processParametersDataDao.selectEngineerAllName(this.type);
//        listLiveData.observeForever(list -> {
//            if(debug) Log.d(TAG, "init: 加载到数据："+ list);
//        });
    }

    /**
     * 销毁所有的监听
     *
     * @param lifecycleOwner
     */
    public void destroyAllLiveData(LifecycleOwner lifecycleOwner) {
        if (this.getAdvancedSettingLiveData() != null) {
            this.getAdvancedSettingLiveData().removeObservers(lifecycleOwner);
        }
        if (this.getListLiveData() != null) {
            this.getListLiveData().removeObservers(lifecycleOwner);
            if (this.getListLiveData().hasActiveObservers()) {
                Log.w(TAG, "destroyAllLiveData: 还有hasActiveObservers");
            }
            if (this.getListLiveData().hasObservers()) {
                Log.w(TAG, "destroyAllLiveData: 还有hasObservers");
            }
        }
        if (this.getLiveData() != null) {
            this.getLiveData().removeObservers(lifecycleOwner);
        }
        if (debug) Log.d(TAG, "destroyAllLiveData: 正在销毁所有的监听：" + this.type);
    }
    /**
     * 在 Fragment 注册 sessionLiveData 监听后再调用，避免 ViewPager 懒加载页丢事件。
     */
    public void loadInitialSessionIfNeeded() {
        if (type == null || sessionLiveData.getValue() != null) {
            return;
        }
        initProcessData(type);
    }

    /**
     * 初始化单条工艺参数
     * @param type
     */
    private void initProcessData(Integer type) {
        ThreadPoolManager.getExecutor().execute(() -> {
            String engineerCacheKey = CacheKey.ENGINEER_DATA_CACHE_KEY + type;
            ProcessParametersData session = resolveInitialSession(type, engineerCacheKey);
            if (session == null) {
                return;
            }
            if (sessionBaseline == null) {
                captureSessionBaseline(session);
            }
            ProcessParametersData loaded = session.clone();
            handler.post(() -> publishSession(loaded));
        });
    }

    @Nullable
    private ProcessParametersData resolveInitialSession(Integer type, String cacheKey) {
        ProcessParametersData cacheData = MemoryCacheManager.getInstance().getSerializable(cacheKey);
        if (cacheData != null && cacheData.getId() != null) {
            ProcessParametersData dbData = processParametersDataDao.selectByIdSync(cacheData.getId());
            if (dbData != null) {
                ProcessParametersData merged = dbData.clone();
                ProcessParametersDataConvert.mergeData(cacheData, merged);
                return merged;
            }
        }
        if (cacheData != null) {
            return cacheData.clone();
        }
        List<ProcessParametersData> rows = processParametersDataDao.selectEngineerAllSync(type);
        if (rows != null && !rows.isEmpty()) {
            return rows.get(0).clone();
        }
        return DefaultValueUtils.createDefaultProcessParametersData();
    }

    private void publishSession(ProcessParametersData data) {
        if (data == null || type == null) {
            return;
        }
        sessionLiveData.setValue(data);
        MemoryCacheManager.getInstance().putSerializable(CacheKey.ENGINEER_DATA_CACHE_KEY + type, data);
        publishProcessParametersSnapshot(data);
    }

    public LiveData<ProcessParametersData> getLiveData() {
        return sessionLiveData;
    }

    public ProcessParametersData getData() {
        return sessionLiveData.getValue();
    }

    /**
     * 添加数据
     *
     * @param data
     */
    public void updateLiveData(ProcessParametersData data) {
        if (debug) Log.d(TAG, "更新数据:" + data);
//        if (true){
//            if(debug) Log.d(TAG, "updateLiveData: 暂时先不保存");
//            return;
//        }
        if (this.task != null) {
            handler.removeCallbacks(this.task);
        }
        this.task = () -> {
            publishSession(data);
            this.task = null;
        };
        handler.postDelayed(this.task, 500);
    }

    /**
     * 仅更新内存会话与快照，不写入工艺参数表。
     */
    public void updateDataToDb(ProcessParametersData data) {
        if (debug) Log.d(TAG, "updateDataToDb: 当前的初始化状态:" + isInit);
        if (data == null) {
            if (debug) Log.d(TAG, "当前没有数据");
            return;
        }
        publishSession(data);
    }

    // 点焊间隔
    public void setPointWeldingInterval(String pointWeldingInterval) {
        ProcessParametersData value = getDataProxy();
        if (StringUtils.isEmpty(pointWeldingInterval)) {
//            value.setPointWeldingInterval(0);
            return;
        } else {
            value.setPointWeldingInterval(Convert.toInt(pointWeldingInterval));
        }

        // this.updateLiveData(value);
    }

    // 点焊持续
    public void setPointWeldingDuration(String pointWeldingDuration) {
        ProcessParametersData value = getDataProxy();
        if (StringUtils.isEmpty(pointWeldingDuration)) {
//            value.setPointWeldingDuration(0);
            return;
        } else {
            value.setPointWeldingDuration(Convert.toInt(pointWeldingDuration));
        }
        // this.updateLiveData(value);
    }


    // 摆动频率
    public void setSwingFrequency(String swingFrequency) {
        ProcessParametersData value = getDataProxy();
        if (StringUtils.isEmpty(swingFrequency)) {
//            value.setSwingFrequency(0);
            return;
        } else {
            value.setSwingFrequency(Convert.toInt(swingFrequency));
        }
//        value.setSwingFrequency(swingFrequency);
        // this.updateLiveData(value);
    }


    // 关光延时
    public void setCloseLightDelay(String closeLightDelay) {
        ProcessParametersData value = getDataProxy();
        if (StringUtils.isEmpty(closeLightDelay)) {
//            value.setCloseLightDelay(0);
            return;
        } else {
            value.setCloseLightDelay(Convert.toInt(closeLightDelay));
        }
//        value.setCloseLightDelay(closeLightDelay);
        // this.updateLiveData(value);
    }

    // 吹气延时
    public void setBlowDelay(String blowDelay) {
        ProcessParametersData value = getDataProxy();
        if (StringUtils.isEmpty(blowDelay)) {
//            value.setBlowDelay(0);
            return;
        } else {
            value.setBlowDelay(Convert.toInt(blowDelay));
        }
//        value.setBlowDelay(blowDelay);
        // this.updateLiveData(value);
    }

    // 关气延时
    public void setCloseAirDelay(String closeAirDelay) {
        ProcessParametersData value = getDataProxy();
        if (StringUtils.isEmpty(closeAirDelay)) {
//            value.setCloseAirDelay(0);
//            value.setCloseAirDelay(null);
            return;
        } else {
            value.setCloseAirDelay(Convert.toInt(closeAirDelay));
        }
//        value.setCloseAirDelay(closeAirDelay);
        // this.updateLiveData(value);
    }

    /**
     * 根据展示文案更新材料类型与自定义名称
     */
    public void setMaterialTypeFromLabel(String materialLabel) {
        ProcessParametersData data = getDataProxy();
        Integer materialTypeValue = EngineerWashConvert.reverseConvertCleaningMaterials(materialLabel);
        if (debug) Log.d(TAG, "更新材质，材质类型：" + materialTypeValue + ",材质名称:" + materialLabel);
        data.setMaterialType(materialTypeValue);
        if (Objects.equals(data.getMaterialType(), MaterialTypeEnum.CUSTOMIZE.getType())) {
            data.setMaterialName(materialLabel);
        }
//        this.updateLiveData(data);
    }

    /**
     * 摆动宽度
     *
     * @param swingWidth
     */
    public void setSwingWidth(String swingWidth) {
        ProcessParametersData value = getDataProxy();
        if (StringUtils.isEmpty(swingWidth)) {
//            value.setSwingWidth(0);
            return;
        } else {
            double data = Double.parseDouble(swingWidth);
            if (!useMMUnit()){
                data= InchMillimeterUtils.inToMm(data);
            }
            value.setSwingWidth(data);
        }
//        value.setSwingWidth(swingWidth);
        // this.updateLiveData(value);
    }

    /**
     * 激光功率
     *
     * @param laserPower
     */
    public void setLaserPower(String laserPower) {
        ProcessParametersData value = getDataProxy();
        if (StringUtils.isEmpty(laserPower)) {
//            value.setLaserPower(0);
            return;
        } else {
            value.setLaserPower(Convert.toInt(laserPower));
        }
        // this.updateLiveData(value);
    }

    /**
     * 更新厚度
     */
    public void setThickness(String thickness) {
        ProcessParametersData value = getDataProxy();
        if (StringUtils.isEmpty(thickness)) {
            return;
        } else {
            double data = Double.parseDouble(thickness);
            if (!useMMUnit()) {
                data = InchMillimeterUtils.inToMm(data);
            }
            value.setThickness(data);
        }
        // this.updateLiveData(value);
    }

    /**
     * laserFrequency 激光频率
     */
    public void setLaserFrequency(String laserFrequency) {
        ProcessParametersData value = getDataProxy();
        if (StringUtils.isEmpty(laserFrequency)) {
//            value.setLaserFrequency(0);
            return;
        } else {
            value.setLaserFrequency(Convert.toInt(laserFrequency));
        }
        // this.updateLiveData(value);
    }

    /**
     * laserDutyCycle 激光占空比
     */
    public void setLaserDutyCycle(String laserDutyCycle) {
        ProcessParametersData value = getDataProxy();
        if (StringUtils.isEmpty(laserDutyCycle)) {
//            value.setLaserDutyCycle(0);
            return;
        } else {
            value.setLaserDutyCycle(Convert.toInt(laserDutyCycle));
        }
        // this.updateLiveData(value);
    }

    /**
     * perforationFrequency  穿孔频率
     */
    public void setPerforationFrequency(String perforationFrequency) {
        ProcessParametersData value = getDataProxy();
        if (StringUtils.isEmpty(perforationFrequency)) {
//            value.setPerforationFrequency(0);
            return;
        } else {
            value.setPerforationFrequency(Convert.toInt(perforationFrequency));
        }
        // this.updateLiveData(value);
    }

    /**
     * perforationDuration  穿孔时长
     */
    public void setPerforationDuration(String perforationDuration) {
        ProcessParametersData value = getDataProxy();
        if (StringUtils.isEmpty(perforationDuration)) {
//            value.setPerforationDuration(0);
            return;
        } else {
            value.setPerforationDuration(Double.parseDouble(perforationDuration));
        }
        // this.updateLiveData(value);
    }

    /**
     * retractLength 退拉长度
     */
    public void setRetractLength(String retractLength) {
        ProcessParametersData value = getDataProxy();
        if (StringUtils.isEmpty(retractLength)) {
//            value.setRetractLength(0);
            return;
        } else {
            double data = Double.parseDouble(retractLength);
            if (!useMMUnit()){
                data=InchMillimeterUtils.inToMm(data);
            }
            value.setRetractLength(data);
        }
        // this.updateLiveData(value);
    }

    /**
     * retractSpeed 退拉速度
     */
    public void setRetractSpeed(String retractSpeed) {
        ProcessParametersData value = getDataProxy();

        if (StringUtils.isEmpty(retractSpeed)) {
//            value.setRetractSpeed(0);
            return;
        } else {
            double data = Double.parseDouble(retractSpeed);
            if (!useMMUnit()) {
                data = InchMillimeterUtils.inToMmPerSecond(data);
            }
            value.setRetractSpeed(data);
        }
        // this.updateLiveData(value);
    }

    /**
     * fillLength 补丝长度
     */
    public void setFillLength(String fillLength) {
        ProcessParametersData value = getDataProxy();
        if (StringUtils.isEmpty(fillLength)) {
//            value.setFillLength(0);
            return;
        } else {
            double data = Double.parseDouble(fillLength);
            if (!useMMUnit()){
                data=InchMillimeterUtils.inToMm(data);
            }
            value.setFillLength(data);
        }
        // this.updateLiveData(value);
    }

    /**
     * fillDelay 补丝时延
     */
    public void setFillDelay(String fillDelay) {
        ProcessParametersData value = getDataProxy();
        if (StringUtils.isEmpty(fillDelay)) {
//            value.setFillDelay(0);
            return;
        } else {
            value.setFillDelay(Convert.toInt(fillDelay));
        }
        // this.updateLiveData(value);
    }

    /**
     * powerRampUp  功率缓升
     *
     * @return
     */
    public void setPowerRampUp(String powerRampUp) {
        ProcessParametersData value = getDataProxy();
        if (StringUtils.isEmpty(powerRampUp)) {
//            value.setPowerRampUp(0);
            return;
        } else {
            value.setPowerRampUp(Convert.toInt(powerRampUp));
        }
        // this.updateLiveData(value);
    }

    /**
     * powerRampDown  功率缓降
     *
     * @return
     */
    public void setPowerRampDown(String powerRampDown) {
        ProcessParametersData value = getDataProxy();
        if (StringUtils.isEmpty(powerRampDown)) {
//            value.setPowerRampDown(0);
            return;
        } else {
            value.setPowerRampDown(Convert.toInt(powerRampDown));
        }
        // this.updateLiveData(value);
    }

    /**
     * wireFeedSpeed  送丝速度
     *
     * @return
     */
    public void setWireFeedSpeed(String wireFeedSpeed) {
        ProcessParametersData value = getDataProxy();
        if (StringUtils.isEmpty(wireFeedSpeed)) {
//            value.setWireFeedSpeed(0);
            return;
        } else {
            double data = Double.parseDouble(wireFeedSpeed);
            if (!useMMUnit()) {
                data = InchMillimeterUtils.inToMmPerSecond(data);
            }
            value.setWireFeedSpeed(data);
        }
        // this.updateLiveData(value);
    }

    public ProcessParametersData getDataProxy() {
        ProcessParametersData data = this.getData();
        if (data == null) {
            if (dataTemp==null){
                dataTemp=DefaultValueUtils.createDefaultProcessParametersData();
            }
            data = dataTemp;
        }
        return data;
    }

    public void publishCurrentProcessParametersSnapshot() {
        publishProcessParametersSnapshot(getDataProxy());
    }

    private void publishProcessParametersSnapshot(ProcessParametersData data) {
        ProcessParametersSnapshotStore.update(data);
    }

    /**
     * 送丝时延
     */
    public void setWireFeedingDelay(String wireFeedingDelay) {
        ProcessParametersData value = getDataProxy();
        if (StringUtils.isEmpty(wireFeedingDelay)) {
//            value.setWireFeedingDelay(0);
            return;
        } else {
            value.setWireFeedingDelay(Convert.toInt(wireFeedingDelay));
        }
        // this.updateLiveData(value);
    }

    /**
     * perforationPower 穿孔功率
     */
    public void setPerforationPower(String perforationPower) {
        ProcessParametersData value = getDataProxy();
        if (StringUtils.isEmpty(perforationPower)) {
//            value.setPerforationPower(0);
            return;
        } else {
            value.setPerforationPower(Convert.toInt(perforationPower));
        }
        // this.updateLiveData(value);
    }

    /**
     * 穿孔占空比
     */
    public void setPerforationDutyCycle(String perforationDutyCycle) {
        ProcessParametersData value = getDataProxy();
        if (StringUtils.isEmpty(perforationDutyCycle)) {
//            value.setPerforationDutyCycle(0);
            return;
        } else {
            value.setPerforationDutyCycle(Convert.toInt(perforationDutyCycle));
        }
        // this.updateLiveData(value);
    }


    /**
     * 是否使用毫米单位
     *
     * @return
     */
    @Override
    public Boolean useMMUnit() {
        return super.useMMUnit();
    }

    /**
     * 获取起始功率
     * @return
     */
    public Double getStartPower(){
        AdvancedSettings value = parameterSettingsLiveData.getValue();
        if (value==null||value.getLaserStartPower()==null){
            return 0d;
        }
        return value.getLaserStartPower();
    }
    /**
     * 获取终止
     */
    public Double getEndPower(){
        AdvancedSettings value = parameterSettingsLiveData.getValue();
        if (value==null||value.getLaserEndPower()==null){
            return 0d;
        }
        return value.getLaserEndPower();
    }
    /**
     * 重置默认数据：恢复到当前会话初始快照。
     */
    public void resetDefaultData(Consumer<LiveData<ProcessParametersData>> callBack) {
        if (sessionBaseline == null) {
            ToastUtils.showShort(R.string.parameter_exception);
            return;
        }
        ProcessParametersData restored = sessionBaseline.clone();
        restored.setProcessType(type);
        restored.setDataType(ProcessDataType.ENGINEER_MODE_DATA);
        restored.setOriginId(null);
        publishSession(restored);
        ToastUtils.showShort(R.string.reset_data_successfully);
        if (callBack != null) {
            callBack.accept(sessionLiveData);
        }
    }

    private void captureSessionBaseline(ProcessParametersData data) {
        if (data == null) {
            return;
        }
        sessionBaseline = data.clone();
        sessionBaseline.setDataType(ProcessDataType.ENGINEER_MODE_DATA);
    }

    /**
     * 从快速模式携带的参数进入工程师模式编辑。
     */
    public void applyQuickModeEntry(
            ProcessParametersData quickSnapshot,
            Consumer<LiveData<ProcessParametersData>> callBack
    ) {
        if (quickSnapshot == null || type == null) {
            ToastUtils.showShort(R.string.parameter_exception);
            return;
        }
        ThreadPoolManager.getExecutor().execute(() -> {
            ProcessParametersData working = resolveFullQuickModeRow(quickSnapshot);
            if (working == null) {
                handler.post(() -> ToastUtils.showShort(R.string.parameter_exception));
                return;
            }
            working.setProcessType(type);
            working.setDataType(ProcessDataType.ENGINEER_MODE_DATA);
            working.setOriginId(null);
            working.setId(null);
            if (working.getName() == null || working.getName().isBlank()) {
                working.setName(ProcessDataExcelConvert.toEnglishMaterialName(
                        working.getMaterialType(),
                        working.getMaterialName()
                ));
            }
            captureSessionBaseline(working.clone());
            syncAndSendLaserTerminationPower(working.getLaserPower());
            handler.post(() -> {
                publishSession(working);
                if (callBack != null) {
                    callBack.accept(sessionLiveData);
                }
            });
        });
    }

    /**
     * 按数据库主键加载完整快速模式工艺行，避免仅携带界面可见字段。
     */
    @Nullable
    private ProcessParametersData resolveFullQuickModeRow(ProcessParametersData quickSnapshot) {
        if (quickSnapshot == null) {
            return null;
        }
        Long id = quickSnapshot.getId();
        if (id != null) {
            ProcessParametersData fromDb = processParametersDataDao.selectByIdSync(id);
            if (fromDb != null) {
                return fromDb.clone();
            }
        }
        return quickSnapshot.clone();
    }

    /**
     * 切换工艺
     *
     * @param id
     * @param callBack
     */
    public void switchProcessParametersData(long id, Consumer<LiveData<ProcessParametersData>> callBack) {
        ThreadPoolManager.getExecutor().execute(
                () -> {
                    ProcessParametersData row = processParametersDataDao.selectByIdSync(id);
                    if (row == null) {
                        handler.post(() -> callBack.accept(sessionLiveData));
                        return;
                    }
                    ProcessParametersData session = row.clone();
                    captureSessionBaseline(session);
                    handler.post(() -> {
                        publishSession(session);
                        callBack.accept(sessionLiveData);
                    });
                }
        );
    }

    /**
     * 另存为常用参数：同一 processType 下按名称唯一，已存在则更新，否则插入。
     */
    public void saveCommonlyUsedParameter(Consumer<LiveData<ProcessParametersData>> callBack) {
        ProcessParametersData value = sessionLiveData.getValue();
        if (value == null) {
            ToastUtils.showShort(R.string.parameter_exception);
            return;
        }
        ThreadPoolManager.getExecutor().execute(() -> {
            ProcessParametersData toSave = value.clone();
            toSave.setDataType(ProcessDataType.ENGINEER_MODE_DATA);
            toSave.setProcessType(type);
            toSave.setOriginId(null);
            long savedId;
            String name = toSave.getName();
            ProcessParametersData existing = StringUtils.isEmpty(name)
                    ? null
                    : processParametersDataDao.selectEngineerByProcessTypeAndNameSync(type, name);
            if (existing != null) {
                toSave.setId(existing.getId());
                int update = processParametersDataDao.update(toSave);
                savedId = existing.getId();
                if (debug) Log.d(TAG, "保存工艺参数:update:" + update);
            } else {
                toSave.setId(null);
                savedId = processParametersDataDao.insert(toSave);
                if (debug) Log.d(TAG, "保存工艺参数:add:" + savedId);
            }
            ProcessParametersData saved = processParametersDataDao.selectByIdSync(savedId);
            if (saved != null) {
                captureSessionBaseline(saved.clone());
                ProcessParametersData session = saved.clone();
                handler.post(() -> {
                    publishSession(session);
                    ToastUtils.showShort(R.string.saved_successfully);
                    callBack.accept(sessionLiveData);
                });
            } else {
                handler.post(() -> ToastUtils.showShort(R.string.parameter_exception));
            }
        });

    }

    public List<ProcessParametersNameData> getAllDataByType() {
        if(getListLiveData()==null){
            return null;
        }
        if (debug) Log.d(TAG, "getAllDataByType: " + getListLiveData().getValue());
        return getListLiveData().getValue();
    }
    public AdvancedSettings getParameterSettings(){
        if (parameterSettingsLiveData==null){
            return null;
        }
        return parameterSettingsLiveData.getValue();
    }

    public AdvancedSettings getAdvancedSetting(){
        return getParameterSettings();
    }

    /**
     * 按焊接功率 × 0.97 更新终止功率，落库并立即下发 Modbus（后台线程访问 Room）。
     */
    public void syncAndSendLaserTerminationPower(@Nullable Integer laserPower) {
        ThreadPoolManager.getExecutor().execute(
                () -> syncAndSendLaserTerminationPowerBlocking(laserPower));
    }

    private void syncAndSendLaserTerminationPowerBlocking(@Nullable Integer laserPower) {
        AdvancedSettings parameterSettings = resolveAdvancedSettingsBlocking();
        if (laserPower != null) {
            parameterSettings.setLaserEndPower(laserPower * LASER_END_POWER_RATIO);
            persistAdvancedSettings(parameterSettings);
        }
        ModbusManagerRtu.get().writeRegisters(
                ModbusFiledBuilder.doCreateWriteDeviceSetting(parameterSettings));
    }

    private AdvancedSettings resolveAdvancedSettingsBlocking() {
        AdvancedSettings cached = getParameterSettings();
        if (cached != null) {
            return cached;
        }
        AdvancedSettings fromDb = advancedSettingsDao.selectOne();
        if (fromDb != null) {
            return fromDb;
        }
        return DefaultValueUtils.createDefaultAdvancedSettings();
    }

    private void persistAdvancedSettings(AdvancedSettings parameterSettings) {
        if (parameterSettings.getId() != null) {
            int update = advancedSettingsDao.update(parameterSettings);
            if (debug) Log.d(TAG, "persistAdvancedSettings: 更新设置" + update);
        } else {
            long insert = advancedSettingsDao.insert(parameterSettings);
            if (debug) Log.d(TAG, "persistAdvancedSettings: 插入设置" + insert);
        }
    }
}
