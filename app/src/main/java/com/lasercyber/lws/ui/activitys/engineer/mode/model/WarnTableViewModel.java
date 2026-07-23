package com.lasercyber.lws.ui.activitys.engineer.mode.model;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import com.lasercyber.lws.ui.activitys.BaseViewModel;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.bean.entity.WarnTable;
import com.lasercyber.lws.ui.bean.event.WarnLogChangedEvent;
import com.lasercyber.lws.ui.bean.entity.vo.WarnTableVo;
import com.lasercyber.lws.ui.common.constant.AlarmCodeConstants;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.WarnTableCallBack;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.handler.WarnListLoader;
import com.lasercyber.lws.ui.common.handler.WarnLogEpisodeTracker;
import com.lasercyber.lws.ui.common.utils.WarnLook;
import com.lasercyber.lws.ui.common.utils.convert.DeviceStatusConvert;
import com.lasercyber.lws.ui.repository.WarnTableDao;

import org.greenrobot.eventbus.EventBus;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Date;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

import cn.hutool.core.collection.CollUtil;
import cn.hutool.core.date.DateTime;
import cn.hutool.core.date.DateUtil;
import cn.hutool.core.util.ObjUtil;

/*告警列表页*/
public class WarnTableViewModel extends BaseViewModel<WarnTableVo> {
    private static final boolean debugLog = false;

    private WarnLook look = new WarnLook();

    /*1、初始化告警列表，查询告警列表第一页*/
    public void init(Context context) {
        //查询第一页的列表 缓存入viewModel
        AppDatabase appDataBase = AppDatabase.getInstance(context);
        WarnTableDao warnTableDao = appDataBase.warnTableDao();

        ThreadPoolManager.getExecutor().execute(() -> {

            Integer page = 1;
            Integer pageNumber = (page - 1) * 10;
            List<WarnTable> listWarnTable = warnTableDao.getListWarnTable(pageNumber, 10);
            WarnTableVo vo = new WarnTableVo();
            vo.setPage(1);
            vo.setNumber(10);
            if (CollUtil.isEmpty(listWarnTable)) {
                vo.setListData(new ArrayList<>());
            } else {
                vo.setListData(listWarnTable);
            }
            super.postLiveData(vo);
        });
    }

    public List<WarnTable> getWarnList(Context context) {
        AppDatabase appDataBase = AppDatabase.getInstance(context);
        WarnTableDao warnTableDao = appDataBase.warnTableDao();

        Integer page = 1;
        Integer pageNumber = (page - 1) * 10;
        List<WarnTable> listWarnTable = warnTableDao.getListWarnTable(pageNumber, 10);
        return listWarnTable;
    }

    /*获取分页数据*/
    public void getPageContent(int page, Context context, WarnTableCallBack callBack) {

        AppDatabase appDataBase = AppDatabase.getInstance(context);
        WarnTableDao warnTableDao = appDataBase.warnTableDao();
        ThreadPoolManager.getExecutor().execute(() -> {

            List<WarnTable> listWarnTable = warnTableDao.getListWarnTable(page, 10);
            new Handler(Looper.getMainLooper()).post(() -> {
                callBack.getTableList(listWarnTable);
            });

        });
    }

    /* 2、清空告警列表*/
    public void deleteAll(Context context) {
        WarnListLoader.clearAllWarns(context);
    }

    /*开机清除三个月前的告警记录*/
    public void deleteTimeHalfYear(Context context) {
        AppDatabase appDataBase = AppDatabase.getInstance(context);
        WarnTableDao warnTableDao = appDataBase.warnTableDao();

        ThreadPoolManager.getExecutor().execute(() -> {
            DateTime dateTime = DateUtil.offsetDay(new Date(), -90);
            long time = dateTime.getTime();
            warnTableDao.deleteTimeHalfYear(time);
        });
    }

    /**
     * 保存告警日志
     *
     * @param deviceStatus
     * @param context
     */
    public void saveWarnLog(DeviceStatus deviceStatus, Context context) {
        List<WarnTable> list = DeviceStatusConvert.convertToWarnTables(deviceStatus);
        saveWarnTables(context, list);
    }

    public void saveWarnTables(Context context, List<WarnTable> list) {
        if (list == null || list.isEmpty()) {
            return;
        }
        Context app = context.getApplicationContext();
        List<WarnTable> copy = new ArrayList<>(list);
        if (Looper.myLooper() == Looper.getMainLooper()) {
            ThreadPoolManager.getExecutor().execute(() -> performSaveWarnTables(app, copy));
        } else {
            performSaveWarnTables(app, copy);
        }
    }

    private void performSaveWarnTables(@NonNull Context context, @NonNull List<WarnTable> list) {
        list = look.removeDuplicates(list);
        if (!look.warnTime()) {
            return;
        }
        for (WarnTable row : list) {
            WarnListLoader.applyLocalizedContent(context, row);
        }

        /*用线程安全的公共参数，判定是否与上次告警一致则丢弃。*/
        AppDatabase appDataBase = AppDatabase.getInstance(context);
        WarnTableDao warnTableDao = appDataBase.warnTableDao();
        List<String> codeList = list.stream().map(WarnTable::getCode).collect(Collectors.toList());

        // 加载告警记录
        List<WarnTable> loadList = warnTableDao.selectListByCodeAndTime(codeList, new Date().getTime());
        if (loadList == null) {
            loadList = Collections.emptyList();
        }
        boolean updatedExisting = false;
        if (!loadList.isEmpty()) {
            int batchedUpdateNewTime = warnTableDao.batchUpdateNewTime(
                    loadList.stream().map(WarnTable::getId).collect(Collectors.toList()),
                    list.get(0).getNewTime());
            updatedExisting = batchedUpdateNewTime > 0;
            if (debugLog) Log.d(TAG, "批量更新告警时间的数量:" + batchedUpdateNewTime);
        }
        Set<String> dbCodes = loadList.stream().map(WarnTable::getCode).collect(Collectors.toSet());
        Set<String> insertCodes = WarnLogEpisodeTracker.resolveInsertCodes(codeList, dbCodes);
        List<WarnTable> saveList = filterInsertCandidates(list, loadList, insertCodes);
        if (!saveList.isEmpty()) {
            List<Long> batchedInsert = warnTableDao.batchInsert(saveList);
            if (debugLog) Log.d(TAG, "批量保存告警:" + batchedInsert);
            WarnListLoader.applyInsertIds(saveList, batchedInsert);
            WarnListLoader.postInserted(context, saveList);
        } else if (updatedExisting) {
            EventBus.getDefault().post(WarnLogChangedEvent.refresh());
        }
    }

    /**
     * Only brand-new fault episodes are inserted; ongoing faults update an existing row or are skipped.
     */
    @NonNull
    static List<WarnTable> filterInsertCandidates(@NonNull List<WarnTable> activeRows,
                                                  @NonNull List<WarnTable> existingRows,
                                                  @NonNull Set<String> insertCodes) {
        if (insertCodes.isEmpty()) {
            return Collections.emptyList();
        }
        return activeRows.stream()
                .filter(row -> {
                    for (WarnTable existing : existingRows) {
                        if (Objects.equals(row.getCode(), existing.getCode())) {
                            return false;
                        }
                    }
                    return insertCodes.contains(row.getCode());
                })
                .collect(Collectors.toList());
    }

    /* 3、添加告警记录 ,判定是 添加 / 修改告警记录 */
    public void creationAddOrUpdate(String code, Context context) {
        AppDatabase appDataBase = AppDatabase.getInstance(context);
        WarnTableDao warnTableDao = appDataBase.warnTableDao();

        ThreadPoolManager.getExecutor().execute(() -> {

            long timestamp = System.currentTimeMillis();
            Long id = warnTableDao.selectOne(code, timestamp);
            //添加一条新的
            if (ObjUtil.isNull(id)) {
                WarnTable warnTable = newWarnTable(code, context);
                long rowId = warnTableDao.insert(warnTable);
                if (rowId > 0L) {
                    warnTable.setId(rowId);
                    WarnLogEpisodeTracker.markOngoingEpisode(code);
                    WarnListLoader.postInserted(context, Collections.singletonList(warnTable));
                }
            } else {
                warnTableDao.updateNewTime(timestamp, id);
                WarnLogEpisodeTracker.markOngoingEpisode(code);
            }

        });
    }

    public void saveZeroPointOffsetWarnLog(Context context, String content) {
        AppDatabase appDataBase = AppDatabase.getInstance(context);
        WarnTableDao warnTableDao = appDataBase.warnTableDao();

        ThreadPoolManager.getExecutor().execute(() -> {
            long timestamp = System.currentTimeMillis();
            Long id = warnTableDao.selectOne(AlarmCodeConstants.ALARM_H034, timestamp);
            if (ObjUtil.isNull(id)) {
                WarnTable warnTable = DeviceStatusConvert.createSeriousWarnTable(AlarmCodeConstants.ALARM_H034);
                warnTable.setContent(content);
                long rowId = warnTableDao.insert(warnTable);
                if (rowId > 0L) {
                    warnTable.setId(rowId);
                    WarnLogEpisodeTracker.markOngoingEpisode(AlarmCodeConstants.ALARM_H034);
                    WarnListLoader.postInserted(context, Collections.singletonList(warnTable));
                }
            } else {
                warnTableDao.updateNewTimeAndContent(timestamp, content, id);
                WarnLogEpisodeTracker.markOngoingEpisode(AlarmCodeConstants.ALARM_H034);
            }
            new Handler(Looper.getMainLooper()).post(() ->
                    EventBus.getDefault().post(WarnLogChangedEvent.refresh())
            );
        });
    }

    public void saveLensHeavyContaminationWarnLog(Context context, String content) {
        AppDatabase appDataBase = AppDatabase.getInstance(context);
        WarnTableDao warnTableDao = appDataBase.warnTableDao();

        ThreadPoolManager.getExecutor().execute(() -> {
            long timestamp = System.currentTimeMillis();
            Long id = warnTableDao.selectOne(AlarmCodeConstants.ALARM_L001, timestamp);
            if (ObjUtil.isNull(id)) {
                WarnTable warnTable = DeviceStatusConvert.createSeriousWarnTable(AlarmCodeConstants.ALARM_L001);
                warnTable.setContent(content);
                long rowId = warnTableDao.insert(warnTable);
                if (rowId > 0L) {
                    warnTable.setId(rowId);
                    WarnLogEpisodeTracker.markOngoingEpisode(AlarmCodeConstants.ALARM_L001);
                    WarnListLoader.postInserted(context, Collections.singletonList(warnTable));
                }
            } else {
                warnTableDao.updateNewTimeAndContent(timestamp, content, id);
                WarnLogEpisodeTracker.markOngoingEpisode(AlarmCodeConstants.ALARM_L001);
            }
            new Handler(Looper.getMainLooper()).post(() ->
                    EventBus.getDefault().post(WarnLogChangedEvent.refresh())
            );
        });
    }

    /*创建一个新的告警数据*/
    private WarnTable newWarnTable(String code, Context context) {
        long timestamp = System.currentTimeMillis();
        WarnTable table = new WarnTable();

        Date date = new Date();
        String day = DateUtil.format(date, "yyyy-MM-dd");
        String hour = DateUtil.format(date, "HH:mm:ss");

        table.setYmdDate(day);
        table.setHmDate(hour);
        table.setCode(code);
        table.setTime(timestamp);
        table.setNewTime(timestamp);

        return table;
    }

}
