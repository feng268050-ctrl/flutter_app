package com.lasercyber.lws.ui.network.channel;

import android.util.Log;

import com.blankj.utilcode.util.GsonUtils;
import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.bean.entity.DeviceInfo;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.entity.ProcessLibrary;
import com.lasercyber.lws.ui.bean.push.ProcessParametersPushEnvelope;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.ProcessDataType;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.repository.DeviceInfoDto;
import com.lasercyber.lws.ui.repository.ProcessParametersDataDao;

import java.util.ArrayList;
import java.util.List;

/**
 * 处理服务端推送的业务数据落库，与传输层（WebSocket 等）解耦。
 */
public final class ServerPushMessageHandler {
    private static final String TAG = LogTAGConstant.SERVER_PUSH;

    private ServerPushMessageHandler() {
    }

    /**
     * 保存单条工艺参数（云端推送）。
     */
    public static void saveProcessData(ProcessParametersPushEnvelope processParametersData) {
        ProcessParametersData data = processParametersData.getData();
        data.setDataType(ProcessDataType.ENGINEER_MODE_DATA);
        Log.d(TAG, "保存工艺数据:" + processParametersData);
        ProcessParametersDataDao processParametersDataDao = AppDatabase.getInstance(Utils.getApp()).processParametersDataDao();
        if (data.getId() != null) {
            processParametersDataDao.deleteById(data.getId());
        }
        processParametersDataDao.insert(data);
    }

    /**
     * 更新工艺库数据（云端经 WebSocket 等通道推送的 {@link ProcessLibrary} 聚合）。
     */
    public static void saveProcessLibrary(ProcessLibrary data) {
        if (data == null) {
            Log.w(TAG, "saveProcessLibrary: skipped null ProcessLibrary");
            return;
        }
        if (data.getDataList() == null) {
            Log.w(TAG, "saveProcessLibrary: skipped null dataList");
            return;
        }
        Log.d(TAG, "保存工艺库数据:" + data);
        ProcessParametersDataDao processParametersDataDao = AppDatabase.getInstance(Utils.getApp()).processParametersDataDao();
        List<Integer> dataTypes = List.of(ProcessDataType.ENGINEER_MODE_DATA, ProcessDataType.QUICK_MODE_DATA);
        int deleteCount = processParametersDataDao.deleteByDataTypes(dataTypes);
        Log.d(TAG, "删除默认" + deleteCount + "条数据");
        ArrayList<ProcessParametersData> list = new ArrayList<>();
        for (Integer dataType : dataTypes) {
            for (ProcessParametersData processParametersData : data.getDataList()) {
                ProcessParametersData clone = processParametersData.clone();
                clone.setId(null);
                clone.setDataType(dataType);
                list.add(clone);
            }
        }
        Log.d(TAG, "批量添加默认数据:" + GsonUtils.toJson(list));
        processParametersDataDao.batchInsert(list);
        DeviceInfoDto deviceInfoDto = AppDatabase.getInstance(Utils.getApp()).deviceInfoDto();
        Log.d(TAG, "开始保存工艺库的信息");
        DeviceInfo oneData = deviceInfoDto.getOneData();
        if (oneData == null) {
            oneData = new DeviceInfo();
        }
        oneData.setProcessLibVersion(String.valueOf(data.getVersionCode()));
        if (oneData.getId() == null) {
            long insert = deviceInfoDto.insert(oneData);
            Log.d(TAG, "保存工艺库:" + insert);
        } else {
            int update = deviceInfoDto.update(oneData);
            Log.d(TAG, "更新工艺库:" + update);
        }
    }
}
