package com.lasercyber.lws.ui.common.upgrade;

import android.util.Log;

import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.bean.entity.DeviceInfo;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.ProcessDataType;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.version.SemanticVersionHelper;
import com.lasercyber.lws.ui.repository.ProcessParametersDataDao;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

import cn.hutool.core.util.ObjectUtil;

/**
 * Shared process-library xlsx import used by OTA {@code UpgradeActivity} and bundled-assets bootstrap.
 */
public final class ProcessLibraryImporter {

    private static final String TAG = LogTAGConstant.UpgradeActivity;

    private ProcessLibraryImporter() {
    }

    /**
     * Replaces only {@link ProcessDataType#QUICK_MODE_DATA} rows; engineer-mode and other data types are untouched.
     */
    public static void resetQuickModeProcessData(List<ProcessParametersData> quickModeRows) {
        Log.d(TAG, "====================开始升级快速模式工艺库====================");
        ProcessParametersDataDao processParametersDataDao = AppDatabase.getInstance(Utils.getApp()).processParametersDataDao();
        int deleteCount = processParametersDataDao.deleteAllByDataType(ProcessDataType.QUICK_MODE_DATA);
        Log.d(TAG, "删除快速模式" + deleteCount + "条数据");
        List<ProcessParametersData> orderedRows = orderQuickModeRowsForPersist(quickModeRows);
        List<Long> batchedInsert = processParametersDataDao.batchInsert(orderedRows);
        Log.d(TAG, "插入快速模式" + batchedInsert.size() + "条数据");
        Log.d(TAG, "====================快速模式工艺库升级完成====================");
    }

    /**
     * Parses xlsx and updates DB + in-memory {@link DeviceInfo} process version string.
     * Only rows with {@link ProcessDataType#QUICK_MODE_DATA} are imported; all other rows in the file are ignored.
     */
    public static void importFromXlsx(File file, String version, DeviceInfo deviceInfo) {
        List<ProcessParametersData> parsed = EasyExcelUtil.proFileConvert(file);
        List<ProcessParametersData> quickModeRows = filterQuickModeRows(parsed);
        if (quickModeRows.isEmpty()) {
            Log.w(TAG, "process-library import: no quick-mode rows found, skipping import");
            return;
        }
        resetQuickModeProcessData(quickModeRows);
        ensureEngineerModeDefaults(quickModeRows);
        String coreVersion = SemanticVersionHelper.toCoreVersion(version);
        deviceInfo.setProcessLibVersion(coreVersion == null ? version : coreVersion);
    }

    /**
     * For each non-custom material under each {@code processType} with quick-mode rows but no matching
     * engineer-mode preset in DB, synthesize one {@link ProcessDataType#ENGINEER_MODE_DATA} row from
     * median gear + thickness/swing width.
     */
    public static void ensureEngineerModeDefaults(List<ProcessParametersData> quickModeRows) {
        if (quickModeRows == null || quickModeRows.isEmpty()) {
            return;
        }
        ProcessParametersDataDao dao = AppDatabase.getInstance(Utils.getApp()).processParametersDataDao();
        Map<Integer, Set<Integer>> existingMaterialsByProcessType = new HashMap<>();
        for (Integer processType : distinctQuickModeProcessTypes(quickModeRows)) {
            if (processType == null) {
                continue;
            }
            List<ProcessParametersData> existing = dao.selectEngineerAllSync(processType);
            if (existing == null || existing.isEmpty()) {
                continue;
            }
            Set<Integer> materialTypes = existing.stream()
                    .map(ProcessParametersData::getMaterialType)
                    .filter(EngineerCommonParamsBootstrap::isNonCustomMaterial)
                    .collect(Collectors.toCollection(HashSet::new));
            if (!materialTypes.isEmpty()) {
                existingMaterialsByProcessType.put(processType, materialTypes);
            }
        }
        List<ProcessParametersData> toInsert = buildMissingEngineerPresets(
                quickModeRows,
                existingMaterialsByProcessType
        );
        if (toInsert.isEmpty()) {
            return;
        }
        Log.d(TAG, "====================开始导入工程师模式常用参数====================");
        List<Long> inserted = dao.batchInsert(toInsert);
        Log.d(TAG, "插入工程师模式常用参数" + inserted.size() + "条数据");
        Log.d(TAG, "====================工程师模式常用参数导入完成====================");
    }

    static List<ProcessParametersData> buildMissingEngineerPresets(
            List<ProcessParametersData> quickModeRows,
            Map<Integer, Set<Integer>> existingMaterialsByProcessType
    ) {
        if (quickModeRows == null || quickModeRows.isEmpty()) {
            return List.of();
        }
        Map<Integer, Set<Integer>> existing = existingMaterialsByProcessType == null
                ? Map.of()
                : existingMaterialsByProcessType;
        List<ProcessParametersData> toInsert = new ArrayList<>();
        for (Integer processType : distinctQuickModeProcessTypes(quickModeRows)) {
            if (processType == null) {
                continue;
            }
            Set<Integer> existingMaterials = existing.getOrDefault(processType, Set.of());
            toInsert.addAll(EngineerCommonParamsBootstrap.buildMedianEngineerPresetsForProcessType(
                    quickModeRows,
                    processType,
                    existingMaterials
            ));
        }
        return toInsert;
    }

    private static List<Integer> distinctQuickModeProcessTypes(List<ProcessParametersData> quickModeRows) {
        return quickModeRows.stream()
                .filter(row -> row != null && row.getProcessType() != null)
                .map(ProcessParametersData::getProcessType)
                .distinct()
                .sorted()
                .collect(Collectors.toList());
    }

    static List<ProcessParametersData> orderQuickModeRowsForPersist(List<ProcessParametersData> quickModeRows) {
        if (quickModeRows == null || quickModeRows.isEmpty()) {
            return quickModeRows == null ? List.of() : List.copyOf(quickModeRows);
        }
        List<ProcessParametersData> ordered = new ArrayList<>(quickModeRows);
        QuickModeProcessRowSort.sortForImport(ordered);
        return ordered;
    }

    static List<ProcessParametersData> filterQuickModeRows(List<ProcessParametersData> source) {
        if (source == null || source.isEmpty()) {
            return List.of();
        }
        List<ProcessParametersData> quickModeRows = new ArrayList<>();
        int ignored = 0;
        for (ProcessParametersData row : source) {
            if (row == null) {
                ignored++;
                continue;
            }
            if (Objects.equals(row.getDataType(), ProcessDataType.QUICK_MODE_DATA)) {
                quickModeRows.add(row);
            } else {
                ignored++;
            }
        }
        if (ignored > 0) {
            Log.i(TAG, "process-library import: ignored " + ignored + " non-quick-mode row(s)");
        }
        return quickModeRows;
    }

    /** Legacy string equality check used where semver ordering is not required (OTA file list). */
    public static boolean shouldUpgradeByStringUnequal(String currentVersion, String fileVersion) {
        return !ObjectUtil.equals(currentVersion, fileVersion);
    }
}
